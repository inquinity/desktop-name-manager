#!/usr/bin/env bash
#
# Live check of `dnm cleanup --scan` (spec 012, quickstart Live 1 and 2) against the REAL Desktops and wallpaper.
#
# It labels Desktops 1 to 3 of every connected display with --desktop (so it switches Desktops), asks you to delete
# Desktop 2 of one display in Mission Control, then runs `dnm cleanup --scan --yes --json` and checks that exactly
# that Desktop's label was deleted, that every display is back on the Desktop it was on, and how long the scan took
# (spec SC-001, SC-004). At the end it removes every label it made with `dnm remove`.
#
# Needs: the Accessibility permission for the app you run it from, the "Move left a space" and "Move right a space"
# shortcuts on, at least 3 Desktops on every display, Desktops whose wallpapers are normal image files, and
# "Show on all Spaces" off. It backs up the wallpaper store first and uses a private store directory. Do not type
# while it switches.
#
# Usage: Tests/live/live-scan.sh [--dnm PATH] [--delete-on DISPLAY] [--yes] [--dry-run] [--help]

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
wallpaper_store_plist="${HOME}/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
assume_yes=false
dry_run=false
delete_on=""
work_directory=""
failures=0
labels_applied=false
display_names=()
before_scan=()

usage() {
    print_colored "$COLOR_YELLOW" "Usage: Tests/live/live-scan.sh [--dnm PATH] [--delete-on DISPLAY] [--yes] [--dry-run] [--help]"
    print_colored "$COLOR_YELLOW" "  --dnm PATH           the dnm binary to test (default: build.noindex/release/dnm; build it first)"
    print_colored "$COLOR_YELLOW" "  --delete-on DISPLAY  the display whose Desktop 2 you will delete (default: the last display)"
    print_colored "$COLOR_YELLOW" "  --yes                do not ask before starting (the Mission Control step still waits for Enter)"
    print_colored "$COLOR_YELLOW" "  --dry-run, -n        print the steps without touching anything"
    print_colored "$COLOR_YELLOW" "Switches Desktops and changes the real wallpaper of Desktops 1 to 3 on every display."
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

# label_text <display index> <desktop>: the label this run puts on that Desktop.
label_text() {
    printf 'Scan %s-%s' "$1" "$2"
}

# current_label <display>: what `dnm show` says about the display's current Desktop.
current_label() {
    "$dnm_binary" show "$1" 2>&1 || true
}

# json_value <file> <key path>: one value from the scan's JSON document (plutil reads JSON; an array gives its count).
json_value() {
    plutil -extract "$2" raw -o - "$1" 2>/dev/null || printf 'missing'
}

cleanup() {
    local exit_status=$?
    if "$dry_run"; then
        return
    fi
    if "$labels_applied"; then
        print_colored "$COLOR_YELLOW" "Cleaning up: removing the labels this run made (this switches Desktops)..."
        local name desktop
        for name in "${display_names[@]}"; do
            # On the display that lost Desktop 2, Desktop 3 is now a Desktop this run did not label: `remove` finds
            # nothing there (or no Desktop 3) and changes nothing.
            for desktop in 1 2 3; do
                if ! "$dnm_binary" remove "$name" --desktop "$desktop" >/dev/null 2>"${work_directory}/remove.err"; then
                    print_colored "$COLOR_YELLOW" "remove on ${name}, Desktop ${desktop}: $(cat "${work_directory}/remove.err")"
                fi
            done
        done
        print_colored "$COLOR_YELLOW" "If a label is left on screen: DNM_STORE_DIR='${DNM_STORE_DIR:-}' dnm remove <display> --desktop N"
    fi
    if [[ -n "$work_directory" && -f "${work_directory}/Index.plist.backup" ]]; then
        if ! cmp -s "${work_directory}/Index.plist.backup" "$wallpaper_store_plist"; then
            print_colored "$COLOR_YELLOW" "The wallpaper store differs from the backup (macOS rewrites it as Desktops change, and you deleted one)."
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
        --delete-on) delete_on="${2:?--delete-on needs a display name}"; shift 2 ;;
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
    command -v plutil >/dev/null || { print_colored "$COLOR_RED" "plutil is needed to read the JSON report."; exit 1; }
    # The private store first: even `dnm displays` runs housekeeping on the store it is pointed at.
    work_directory="$(mktemp -d "${TMPDIR:-/tmp}/dnm-live-scan.XXXXXX")"
    trap cleanup EXIT   # from here on, every exit reports where the backup is
    cp "$wallpaper_store_plist" "${work_directory}/Index.plist.backup"
    export DNM_STORE_DIR="${work_directory}/store"
    # Display names through plutil, so a name with a quote or a backslash arrives intact.
    "$dnm_binary" displays --json >"${work_directory}/displays.json"
    display_count="$(plutil -extract displays raw -o - "${work_directory}/displays.json")"
    for ((display_index = 0; display_index < display_count; display_index++)); do
        display_names+=("$(plutil -extract "displays.${display_index}.name" raw -o - "${work_directory}/displays.json")")
    done
    ((${#display_names[@]} > 0)) || { print_colored "$COLOR_RED" "dnm reports no displays."; exit 1; }
    print_colored "$COLOR_BRIGHTYELLOW" "Backed up the wallpaper store to ${work_directory}"
    print_colored "$COLOR_BRIGHTYELLOW" "Using a private store: ${DNM_STORE_DIR}"
    print_colored "$COLOR_YELLOW" "Displays: ${display_names[*]}"
    if ! "$assume_yes"; then
        read -r -p "This switches Desktops and changes wallpapers on every display. Ready, with 3 or more Desktops on each? [y/N] " confirm
        [[ "$confirm" == [yY]* ]] || { print_colored "$COLOR_RED" "Cancelled."; exit 1; }
    fi
    print_colored "$COLOR_YELLOW" "Run on: macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), $(uname -m), dnm $("$dnm_binary" --version), $(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi

# The display whose Desktop 2 is deleted: the one named, or the last.
target_index=${#display_names[@]}
if [[ -n "$delete_on" ]]; then
    target_index=0
    for index in "${!display_names[@]}"; do
        [[ "${display_names[$index]}" == "$delete_on" ]] && target_index=$((index + 1))
    done
    ((target_index > 0)) || { print_colored "$COLOR_RED" "No connected display is named ${delete_on}."; exit 2; }
fi
target_name="${display_names[$((target_index - 1))]}"
deleted_label="$(label_text "$target_index" 2)"

# --- Label Desktops 1 to 3 of every display ---------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Labeling Desktops 1 to 3 of every display (the Desktops switch; do not type)..."
for index in "${!display_names[@]}"; do
    name="${display_names[$index]}"
    for desktop in 1 2 3; do
        text="$(label_text $((index + 1)) "$desktop")"
        if "$dry_run"; then
            print_colored "$COLOR_CYAN" "[dry run] dnm set '${name}' '${text}' --desktop ${desktop}"
            continue
        fi
        labels_applied=true
        if ! "$dnm_binary" set "$name" "$text" --desktop "$desktop" >/dev/null 2>"${work_directory}/set.err"; then
            print_colored "$COLOR_RED" "Could not label Desktop ${desktop} of ${name}: $(cat "${work_directory}/set.err")"
            print_colored "$COLOR_RED" "Every display needs at least 3 Desktops, Accessibility, and the switching shortcuts on."
            failures=$((failures + 1))
            exit 1
        fi
    done
done

# --- The person deletes one labeled Desktop ---------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Now, in Mission Control, delete Desktop 2 of ${target_name} (its wallpaper says \"${deleted_label}\")."
print_colored "$COLOR_BRIGHTYELLOW" "Then, on each display, go to a Desktop this run labeled (\"Scan ...\") and press Enter here."
if ! "$dry_run"; then
    read -r -p "Press Enter when Desktop 2 of ${target_name} is deleted... " _
    for name in "${display_names[@]}"; do
        label_now="$(current_label "$name")"
        before_scan+=("$label_now")
        [[ "$label_now" == *'"Scan '* ]] \
            || print_colored "$COLOR_YELLOW" "${name} is on a Desktop this run did not label; the return check there proves little."
    done
fi

# --- The scan ---------------------------------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scanning (the Desktops slide by; do not type)..."
scan_status=0
if "$dry_run"; then
    print_colored "$COLOR_CYAN" "[dry run] dnm cleanup --scan --yes --json"
else
    started=$(date +%s)
    "$dnm_binary" cleanup --scan --yes --json >"${work_directory}/scan.json" 2>"${work_directory}/scan.err" || scan_status=$?
    elapsed=$(($(date +%s) - started))
    print_colored "$COLOR_YELLOW" "The scan took ${elapsed} s for ${#display_names[@]} display(s) (SC-004: under 20 s for 3 Desktops on each of 2)."
    [[ -s "${work_directory}/scan.err" ]] && print_colored "$COLOR_YELLOW" "Standard error: $(cat "${work_directory}/scan.err")"
fi

scan_json="${work_directory}/scan.json"
check "the scan succeeds (exit ${scan_status})" test "$scan_status" -eq 0
check "it reports exactly one label no Desktop shows" test "$(json_value "$scan_json" candidates)" = 1
check "that label is \"${deleted_label}\", from the deleted Desktop" test "$(json_value "$scan_json" candidates.0.label)" = "$deleted_label"
check "it was deleted" test "$(json_value "$scan_json" deleted)" = true
check "every connected display was scanned" test "$(json_value "$scan_json" scanned)" = "${#display_names[@]}"
if ! "$dry_run"; then
    for index in "${!display_names[@]}"; do
        name="${display_names[$index]}"
        check "${name} is back on the Desktop it was on" test "$(current_label "$name")" = "${before_scan[$index]}"
    done
fi
