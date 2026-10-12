#!/usr/bin/env bash
#
# Live checks of label reuse and `dnm cleanup` (spec 009, task T016) against the REAL wallpaper.
#
# On every connected display it labels, removes and relabels the same thing and checks that no second image is made;
# that a different label does make one; that relabeling an earlier label reuses it; and that `cleanup` describes
# without deleting, and with --yes never deletes the image on screen or one an undo needs. It never switches
# Desktops: it acts on the Desktop showing on each display.
#
# This changes the wallpaper of the Desktop you are on, on every display. Run it only while you are idle, on
# Desktops whose wallpapers are normal image files, with "Show on all Spaces" turned off. It backs up the wallpaper
# store, uses a private store directory, and finishes by removing its labels, which restores the original
# wallpapers (it restores Index.plist only if you ask: see the message at the end).
#
# Usage: Tests/live/live-reuse.sh [--dnm PATH] [--yes] [--dry-run] [--help]

set -euo pipefail

# Define color codes for terminal output
COLOR_GREEN="\e[32m"         # Used for success messages and instructions
COLOR_RED="\e[31m"           # Used for error messages and warnings
COLOR_YELLOW="\e[33m"        # Used for help text, lists, and informational content
COLOR_MAGENTA="\e[35m"       # Available for general use
COLOR_CYAN="\e[36m"          # Available for general use
COLOR_BLUE="\e[34m"          # Available for general use; does not show on screen well
COLOR_BRIGHTYELLOW="\e[93m"  # Used for highlighting important actions and status
COLOR_RESET="\e[0m"          # Used to reset color formatting

# Function to print colored output
print_colored() {
    local color=$1
    local message=$2
    printf "%b%s%b\n" "$color" "$message" "$COLOR_RESET"
}

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dnm_binary="${repository_root}/build.noindex/release/dnm"
if [[ -x "${repository_root}/dnm" ]]; then
    dnm_binary="${repository_root}/dnm"
fi
wallpaper_store_plist="${HOME}/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
assume_yes=false
dry_run=false
work_directory=""
failures=0
labels_applied=false
display_names=()

usage() {
    print_colored "$COLOR_YELLOW" "Usage: Tests/live/live-reuse.sh [--dnm PATH] [--yes] [--dry-run] [--help]"
    print_colored "$COLOR_YELLOW" "  --dnm PATH     the dnm binary to test (default: build.noindex/release/dnm; build it first)"
    print_colored "$COLOR_YELLOW" "  --yes          do not ask before changing the wallpaper"
    print_colored "$COLOR_YELLOW" "  --dry-run, -n  print the steps without touching the wallpaper"
    print_colored "$COLOR_YELLOW" "Changes the real wallpaper of the Desktop showing on every display. Run only while idle."
}

# Run a check, or only print it in dry-run mode: check "description" <command...>
check() {
    local description=$1
    shift
    if "$dry_run"; then
        print_colored "$COLOR_CYAN" "[dry run] check: ${description}"
    elif "$@"; then
        print_colored "$COLOR_GREEN" "PASS  ${description}"
    else
        print_colored "$COLOR_RED" "FAIL  ${description}"
        failures=$((failures + 1))
    fi
}

# Run dnm quietly; in dry-run mode only print it.
dnm() {
    if "$dry_run"; then
        print_colored "$COLOR_CYAN" "[dry run] dnm $*"
    else
        "$dnm_binary" "$@" >/dev/null 2>&1 || true
    fi
}

# The number of labeled images in the private store.
image_count() {
    [[ -d "$DNM_STORE_DIR" ]] || { echo 0; return; }
    find "$DNM_STORE_DIR" -maxdepth 1 -name '*.dnm.*' | wc -l | tr -d ' '
}

# has_images <count>
has_images() { [[ "$(image_count)" -eq "$1" ]]; }

# shows_label <display word> <label>: `dnm show` for that display names the label (captured first: `grep -q` closing
# a pipe would kill dnm with SIGPIPE under pipefail).
shows_label() {
    local output
    output="$("$dnm_binary" show "$1" 2>/dev/null)" || return 1
    grep -qF "\"$2\"" <<<"$output"
}

shows_no_label() {
    local output
    output="$("$dnm_binary" show "$1" 2>/dev/null)" || return 1
    grep -qF "No label" <<<"$output"
}

# cleanup_says <needle> <dnm cleanup arguments...>: with standard input closed, cleanup only describes; its output has the text.
cleanup_says() {
    local needle=$1 output
    shift
    output="$("$dnm_binary" cleanup "$@" </dev/null 2>&1)" || return 1
    grep -qF "$needle" <<<"$output"
}

cleanup() {
    local exit_status=$?
    if "$dry_run"; then
        return
    fi
    if "$labels_applied"; then
        print_colored "$COLOR_YELLOW" "Cleaning up: removing any label this run left..."
        local name
        for name in "${display_names[@]}"; do
            "$dnm_binary" remove --display "$name" >/dev/null 2>&1 || true
        done
    fi
    if [[ -n "$work_directory" && -f "${work_directory}/Index.plist.backup" ]]; then
        if cmp -s "${work_directory}/Index.plist.backup" "$wallpaper_store_plist"; then
            print_colored "$COLOR_GREEN" "The wallpaper store is identical to the backup."
        else
            print_colored "$COLOR_YELLOW" "The wallpaper store differs from the backup (macOS rewrites it as Desktops change); the labels were removed, which restores the original wallpapers."
            print_colored "$COLOR_YELLOW" "Only if a wallpaper looks wrong: cp '${work_directory}/Index.plist.backup' '${wallpaper_store_plist}', then log out and in."
        fi
    fi
    if ((failures > 0)); then
        print_colored "$COLOR_RED" "${failures} check(s) failed."
        exit_status=1
    fi
    exit "$exit_status"
}

while (($# > 0)); do
    case "$1" in
        --dnm) dnm_binary="${2:?--dnm needs a path}"; shift 2 ;;
        --yes) assume_yes=true; shift ;;
        -n|--dry-run) dry_run=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print_colored "$COLOR_RED" "Unknown option: $1"; usage; exit 2 ;;
    esac
done

if "$dry_run"; then
    display_names=("Display A" "Display B")
    DNM_STORE_DIR="/dry-run"
else
    [[ -x "$dnm_binary" ]] || { print_colored "$COLOR_RED" "No executable at ${dnm_binary}. Run: just build-release"; exit 1; }
    [[ -f "$wallpaper_store_plist" ]] || { print_colored "$COLOR_RED" "Cannot find the wallpaper store: ${wallpaper_store_plist}"; exit 1; }
    # The private store first: even `dnm displays` runs housekeeping on the store it is pointed at.
    work_directory="$(mktemp -d "${TMPDIR:-/tmp}/dnm-live.XXXXXX")"
    cp "$wallpaper_store_plist" "${work_directory}/Index.plist.backup"
    export DNM_STORE_DIR="${work_directory}/store"
    while IFS= read -r line; do
        display_names+=("$line")
    done < <("$dnm_binary" displays --json | sed -n 's/^ *"name" : "\(.*\)",\{0,1\}$/\1/p')
    ((${#display_names[@]} > 0)) || { print_colored "$COLOR_RED" "dnm reports no displays."; exit 1; }
    print_colored "$COLOR_BRIGHTYELLOW" "Backed up the wallpaper store to ${work_directory}"
    print_colored "$COLOR_BRIGHTYELLOW" "Using a private store: ${DNM_STORE_DIR}"
    print_colored "$COLOR_YELLOW" "Displays: ${display_names[*]}"
    if ! "$assume_yes"; then
        read -r -p "This changes your real wallpaper on every display. Are you idle, with 'Show on all Spaces' off? [y/N] " confirm
        [[ "$confirm" == [yY]* ]] || { print_colored "$COLOR_RED" "Cancelled."; exit 1; }
    fi
    print_colored "$COLOR_YELLOW" "Run on: macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), $(uname -m), dnm $("$dnm_binary" --version), $(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi
trap cleanup EXIT

for name in "${display_names[@]}"; do
    print_colored "$COLOR_BRIGHTYELLOW" "Display: ${name}"
    labels_applied=true
    base=0   # images in the store when this display starts
    "$dry_run" || base="$(image_count)"

    dnm set "$name" "Reuse A"
    check "the first label makes one image" has_images $((base + 1))

    dnm remove "$name"
    check "removing it keeps the image (it is only retired)" has_images $((base + 1))
    check "the original wallpaper is back" shows_no_label "$name"

    dnm set "$name" "Reuse A"
    check "the same label again reuses the image: no new file" has_images $((base + 1))
    check "and it is showing" shows_label "$name" "Reuse A"

    dnm set "$name" "Reuse A"
    check "asking for it again on the Desktop that shows it changes nothing" has_images $((base + 1))

    dnm set "$name" "Reuse B"
    check "a different label makes a new image" has_images $((base + 2))

    dnm set "$name" "Reuse A"
    check "going back to the first label reuses its image" has_images $((base + 2))
    check "and shows it" shows_label "$name" "Reuse A"

    # Now A is on screen and the last change can still be undone, which needs B: cleanup must keep both.
    check "cleanup has nothing to offer: A is on screen and B is needed by undo" cleanup_says "Nothing to clean up" --days 0
    dnm cleanup --days 0 --yes
    check "cleanup --yes deleted nothing" has_images $((base + 2))
    check "A is still showing" shows_label "$name" "Reuse A"

    dnm undo "$name"
    check "undo, after a reused set and a cleanup, brings B back" shows_label "$name" "Reuse B"

    # B is on screen and A is retired, with nothing to undo: A is now offered, never B.
    check "cleanup describes the retired image and says another Desktop might show it" cleanup_says "might still show one of these" --days 0
    check "cleanup only describes without a terminal" cleanup_says "Nothing was deleted: add --yes" --days 0
    check "describing deleted nothing" has_images $((base + 2))

    dnm cleanup --days 0 --yes
    check "cleanup --yes deleted the retired image" has_images $((base + 1))
    check "and not the one on screen" shows_label "$name" "Reuse B"

    dnm remove "$name"
    check "remove restores the original" shows_no_label "$name"
done
labels_applied=false

if "$dry_run"; then
    print_colored "$COLOR_CYAN" "[dry run] done; nothing was changed."
elif ((failures == 0)); then
    print_colored "$COLOR_GREEN" "All checks passed."
fi
