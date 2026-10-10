#!/usr/bin/env bash
#
# Live checks of the positional display syntax (spec 008, tasks T011 and T012) against the REAL wallpaper.
#
# On every connected display it labels, shows, replaces, undoes and removes using the display as a word, as
# --display, with --label, through an alias and as "main"; checks that each display gets its own label; and
# checks that the mistakes (a display given twice, a lone word that is a display) are refused and change nothing.
# It never switches Desktops: it acts on the Desktop showing on each display.
#
# This changes the wallpaper of the Desktop you are on, on every display. Run it only while you are idle, on
# Desktops whose wallpapers are normal image files, with "Show on all Spaces" turned off. It backs up the
# wallpaper store first, uses a private store directory, and removes its labels when it finishes.
#
# Usage: Tests/live/live-syntax.sh [--dnm PATH] [--yes] [--dry-run] [--help]

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
alias_name="zzsyntax"
assume_yes=false
dry_run=false
work_directory=""
failures=0
labels_applied=false
display_names=()

usage() {
    print_colored "$COLOR_YELLOW" "Usage: Tests/live/live-syntax.sh [--dnm PATH] [--yes] [--dry-run] [--help]"
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

# shows_label <display word> <label>: `dnm show` for that display names the label.
shows_label() {
    "$dnm_binary" show "$1" 2>/dev/null | grep -qF "\"$2\""
}

# shows_no_label <display word>
shows_no_label() {
    "$dnm_binary" show "$1" 2>/dev/null | grep -qF "No label"
}

# shows_the_same_both_ways <display word>: the word and --display give the same `dnm show`.
shows_the_same_both_ways() {
    [[ "$("$dnm_binary" show "$1" 2>&1)" == "$("$dnm_binary" show --display "$1" 2>&1)" ]]
}

# exits_with <status> <dnm arguments...>: dnm exits with that status and prints nothing on standard output.
exits_with() {
    local expected=$1 output status=0
    shift
    output="$("$dnm_binary" "$@" 2>/dev/null)" || status=$?
    [[ "$status" -eq "$expected" && -z "$output" ]]
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
        if ! cmp -s "${work_directory}/Index.plist.backup" "$wallpaper_store_plist"; then
            print_colored "$COLOR_YELLOW" "The wallpaper store differs from the backup (macOS rewrites it as Desktops change)."
            print_colored "$COLOR_YELLOW" "If a wallpaper looks wrong, restore it, then log out and in:"
            print_colored "$COLOR_YELLOW" "  cp '${work_directory}/Index.plist.backup' '${wallpaper_store_plist}'"
        else
            print_colored "$COLOR_GREEN" "The wallpaper store is identical to the backup."
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
else
    [[ -x "$dnm_binary" ]] || { print_colored "$COLOR_RED" "No executable at ${dnm_binary}. Run: just build-release"; exit 1; }
    [[ -f "$wallpaper_store_plist" ]] || { print_colored "$COLOR_RED" "Cannot find the wallpaper store: ${wallpaper_store_plist}"; exit 1; }
    # One display name per line, from the JSON report (pretty-printed, one key per line).
    while IFS= read -r line; do
        display_names+=("$line")
    done < <("$dnm_binary" displays --json | sed -n 's/^ *"name" : "\(.*\)",\{0,1\}$/\1/p')
    ((${#display_names[@]} > 0)) || { print_colored "$COLOR_RED" "dnm reports no displays."; exit 1; }
    work_directory="$(mktemp -d "${TMPDIR:-/tmp}/dnm-live.XXXXXX")"
    cp "$wallpaper_store_plist" "${work_directory}/Index.plist.backup"
    export DNM_STORE_DIR="${work_directory}/store"
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

# --- Each display, in every form -------------------------------------------------------------------
for name in "${display_names[@]}"; do
    print_colored "$COLOR_BRIGHTYELLOW" "Display: ${name}"
    labels_applied=true

    dnm set "$name" "Word form"
    check "set <display> <label> labels that display" shows_label "$name" "Word form"
    check "show <display> and show --display <display> agree" shows_the_same_both_ways "$name"

    dnm set "Flag form" --display "$name"
    check "set <label> --display <display> replaces it" shows_label "$name" "Flag form"

    dnm set "$name" --label "Named form"
    check "set <display> --label <text> replaces it" shows_label "$name" "Named form"

    dnm set --display "$name" --label "Explicit form"
    check "set --display <display> --label <text> replaces it" shows_label "$name" "Explicit form"

    dnm alias "$alias_name" "$name"
    dnm set "$alias_name" "Alias form"
    check "set <alias> <label> labels the aliased display" shows_label "$name" "Alias form"
    check "show <alias> names the same label" shows_label "$alias_name" "Alias form"

    dnm undo "$name"
    check "undo <display> brings the previous label back" shows_label "$name" "Explicit form"

    check "a lone word that is a display is refused (exit 2, no output)" exits_with 2 set "$name"
    check "a lone alias is refused too" exits_with 2 set "$alias_name"
    check "the refusals changed nothing" shows_label "$name" "Explicit form"
    check "a display given as a word and with --display is refused" exits_with 2 set "$name" "Twice" --display "$name"
    check "--display given twice is refused (the same display)" exits_with 2 set "Twice" --display "$name" --display "$name"
    check "--label given twice is refused" exits_with 2 set "$name" --label "One" --label "Two"
    check "three words are refused" exits_with 2 set "$name" "Too" "many"
    check "these refusals changed nothing either" shows_label "$name" "Explicit form"

    if ((${#name} <= 30)); then
        dnm set --label "$name" --display "$name"
        check "--label names a label that equals the display's name" shows_label "$name" "$name"
    fi

    dnm remove "$name"
    check "remove <display> restores the original" shows_no_label "$name"
    dnm alias --remove "$alias_name"
done

# --- main, said outright ---------------------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "The main display, said outright and left out"
dnm set main "Main word"
check "set main <label> labels the main display" shows_label main "Main word"
dnm set "Main alone"
check "set <label> alone labels the main display" shows_label main "Main alone"
check "set main alone is refused" exits_with 2 set main
dnm remove main
check "remove main restores the original" shows_no_label main

# --- Each display gets its own label --------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Each display gets its own label"
index=0
for name in "${display_names[@]}"; do
    index=$((index + 1))
    dnm set "$name" "Own ${index}"
done
index=0
for name in "${display_names[@]}"; do
    index=$((index + 1))
    check "${name} shows its own label (Own ${index}), not another display's" shows_label "$name" "Own ${index}"
done
for name in "${display_names[@]}"; do
    dnm remove "$name"
    check "${name}: removed" shows_no_label "$name"
done
labels_applied=false

if "$dry_run"; then
    print_colored "$COLOR_CYAN" "[dry run] done; nothing was changed."
elif ((failures == 0)); then
    print_colored "$COLOR_GREEN" "All checks passed."
fi
