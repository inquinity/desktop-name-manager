#!/usr/bin/env bash
#
# Live checks for spec 001's --desktop and prune (quickstart scenarios 21, 22 and 23) against the REAL
# wallpaper.
#
# This switches Desktops and changes their wallpapers. Run it only while you are idle, with at least three
# Desktops on the main display (and on the second display, if there is one), all with normal image
# wallpapers and "Show on all Spaces" off. The app you run it from needs the Accessibility permission
# (`dnm check` says whether it has it), and the "Move left/right a space" shortcuts must be on.
# It backs up the wallpaper store first, uses a private store directory, and removes its labels when it
# finishes. Scenario 22 asks you to create a Desktop in Mission Control, and to delete it at the end.
#
# Usage: Tests/live/live-desktops.sh [--dnm PATH] [--second-display NAME] [--dry-run] [--help]

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
# In a copied test kit the binary sits next to the Tests folder.
if [[ -x "${repository_root}/dnm" ]]; then
    dnm_binary="${repository_root}/dnm"
fi
wallpaper_store_plist="${HOME}/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
# The budget for one --desktop command (SC-008).
command_budget_milliseconds=8000
second_display=""
dry_run=false
work_directory=""
failures=0
# What the cleanup must undo if the script stops early.
set_labels_applied=false
first_desktop_labeled=false
new_desktop_number=""

usage() {
    print_colored "$COLOR_YELLOW" "Usage: Tests/live/live-desktops.sh [--dnm PATH] [--second-display NAME] [--dry-run] [--help]"
    print_colored "$COLOR_YELLOW" "  --dnm PATH              the dnm binary to test (default: build.noindex/release/dnm; build it first)"
    print_colored "$COLOR_YELLOW" "  --second-display NAME   the other display for scenario 21 (default: the first one that is not main)"
    print_colored "$COLOR_YELLOW" "  --dry-run, -n           print the steps without switching Desktops or touching the wallpaper"
    print_colored "$COLOR_YELLOW" "Switches Desktops and changes real wallpapers. Run only while idle, and don't type while it runs."
}

# Run a command, or only print it in dry-run mode.
run_step() {
    if "$dry_run"; then
        print_colored "$COLOR_CYAN" "[dry run] $*"
    else
        "$@"
    fi
}

check() {
    # check "description" <command...>: record a pass or a failure.
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

ask_to_look() {
    # Pause so the person can look at the screen.
    local question=$1
    if "$dry_run"; then
        print_colored "$COLOR_CYAN" "[dry run] look: ${question}"
        return 0
    fi
    local answer
    read -r -p "$(printf "${COLOR_BRIGHTYELLOW}LOOK: %s [y/N] ${COLOR_RESET}" "$question")" answer
    [[ "$answer" == [yY]* ]]
}

wait_for_person() {
    # Pause until the person has done something by hand.
    local instruction=$1
    if "$dry_run"; then
        print_colored "$COLOR_CYAN" "[dry run] by hand: ${instruction}"
        return 0
    fi
    read -r -p "$(printf "${COLOR_BRIGHTYELLOW}DO: %s Then press Return. ${COLOR_RESET}" "$instruction")" _
}

now_milliseconds() {
    # macOS's bash 3.2 has no EPOCHREALTIME; perl ships with macOS.
    perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'
}

# Every display the scenarios label: main, plus the second display when there is one.
target_displays() {
    printf "%s\n" "main"
    if [[ -n "$second_display" ]]; then
        printf "%s\n" "$second_display"
    fi
}

remove_set_labels() {
    # Take the scenario 21 labels off again (Desktops 2 and 3 of each display).
    local display_name desktop_number
    while IFS= read -r display_name; do
        for desktop_number in 2 3; do
            "$dnm_binary" remove --display "$display_name" --desktop "$desktop_number" >/dev/null 2>&1 || true
        done
    done < <(target_displays)
}

cleanup() {
    local exit_status=$?
    if "$dry_run"; then
        return
    fi
    if "$set_labels_applied"; then
        print_colored "$COLOR_YELLOW" "Cleaning up: removing the labels from Desktops 2 and 3..."
        remove_set_labels
    fi
    if "$first_desktop_labeled"; then
        print_colored "$COLOR_YELLOW" "Cleaning up: removing the label from Desktop 1 of the main display..."
        "$dnm_binary" remove --display main --desktop 1 >/dev/null 2>&1 || true
    fi
    if [[ -n "$new_desktop_number" ]]; then
        print_colored "$COLOR_RED" "Delete the Desktop you created (Desktop ${new_desktop_number} of the main display) in Mission Control if it is still there."
    fi
    if [[ -n "$work_directory" && -f "${work_directory}/Index.plist.backup" ]]; then
        if ! cmp -s "${work_directory}/Index.plist.backup" "$wallpaper_store_plist"; then
            print_colored "$COLOR_YELLOW" "The wallpaper store differs from the backup (macOS rewrites it as Desktops change)."
            print_colored "$COLOR_YELLOW" "If the wallpaper looks wrong, restore it, then log out and in:"
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

# Small checks as functions, so the binary path is never pasted into a shell string.
shows_label() {
    # shows_label <label> <display> <desktop>: dnm show reports that label on that Desktop.
    local details
    details="$("$dnm_binary" show --display "$2" --desktop "$3")"
    grep -qF "\"$1\"" <<<"$details"
}

shows_no_missing_image() {
    # The current Desktop of the main display still has its labeled image file.
    local details
    details="$("$dnm_binary" show --display main)"
    ! grep -qi 'missing' <<<"$details"
}

lacks_label() {
    # lacks_label <label> <text>: the text does not mention that label.
    ! grep -qF "\"$1\"" <<<"$2"
}

store_file_count() {
    find "$DNM_STORE_DIR" -maxdepth 1 -name '*.dnm.*' | wc -l | tr -d ' '
}

accessibility_granted() {
    # Capture first: with pipefail, `dnm check | grep -q` fails when grep exits early and dnm gets SIGPIPE.
    local report
    report="$("$dnm_binary" check)"
    grep -q '^ok  Accessibility' <<<"$report"
}

timed_set() {
    # timed_set <label> <display> <desktop>: label that Desktop and check the time budget.
    local label=$1 display_name=$2 desktop_number=$3
    local start_milliseconds elapsed_milliseconds
    if "$dry_run"; then
        run_step "$dnm_binary" set "$label" --display "$display_name" --desktop "$desktop_number"
        return
    fi
    start_milliseconds="$(now_milliseconds)"
    "$dnm_binary" set "$label" --display "$display_name" --desktop "$desktop_number"
    elapsed_milliseconds=$(($(now_milliseconds) - start_milliseconds))
    print_colored "$COLOR_YELLOW" "  took ${elapsed_milliseconds} ms"
    check "set --display ${display_name} --desktop ${desktop_number} took under ${command_budget_milliseconds} ms" \
        test "$elapsed_milliseconds" -lt "$command_budget_milliseconds"
}

while (($# > 0)); do
    case "$1" in
        --dnm) dnm_binary="${2:?--dnm needs a path}"; shift 2 ;;
        --second-display) second_display="${2:?--second-display needs a name}"; shift 2 ;;
        -n|--dry-run) dry_run=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print_colored "$COLOR_RED" "Unknown option: $1"; usage; exit 2 ;;
    esac
done

if ! "$dry_run"; then
    [[ -x "$dnm_binary" ]] || { print_colored "$COLOR_RED" "No executable at ${dnm_binary}. Run: just release"; exit 1; }
    [[ -f "$wallpaper_store_plist" ]] || { print_colored "$COLOR_RED" "Cannot find the wallpaper store: ${wallpaper_store_plist}"; exit 1; }
    command -v perl >/dev/null || { print_colored "$COLOR_RED" "perl is needed to time the commands."; exit 1; }
    if ! accessibility_granted; then
        print_colored "$COLOR_RED" "The app running this script does not have the Accessibility permission, which --desktop needs."
        print_colored "$COLOR_RED" "Grant it in System Settings > Privacy & Security > Accessibility (macOS 26) or Device Control and Data Access (macOS 27), then run this again. Nothing was changed."
        exit 1
    fi
    if [[ -z "$second_display" ]]; then
        # dnm displays pads names; the main one ends in "(main)".
        second_display="$("$dnm_binary" displays | grep -v '(main)$' | sed 's/ *$//' | head -n 1 || true)"
    fi
    work_directory="$(mktemp -d "${TMPDIR:-/tmp}/dnm-live.XXXXXX")"
    cp "$wallpaper_store_plist" "${work_directory}/Index.plist.backup"
    export DNM_STORE_DIR="${work_directory}/store"
    print_colored "$COLOR_BRIGHTYELLOW" "Backed up the wallpaper store to ${work_directory}"
    print_colored "$COLOR_BRIGHTYELLOW" "Using a private store: ${DNM_STORE_DIR}"
    read -r -p "This switches Desktops and changes real wallpapers. Are you idle, with at least 3 Desktops on each display, normal image wallpapers and 'Show on all Spaces' off? [y/N] " confirm
    [[ "$confirm" == [yY]* ]] || { print_colored "$COLOR_RED" "Cancelled."; exit 1; }
fi
trap cleanup EXIT

if ! "$dry_run"; then
    # So a log copied back from another Mac says what it ran on.
    print_colored "$COLOR_YELLOW" "Run on: macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), $(uname -m), dnm $("$dnm_binary" --version), $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [[ -n "$second_display" ]]; then
        print_colored "$COLOR_BRIGHTYELLOW" "Displays: main and ${second_display}."
    else
        print_colored "$COLOR_YELLOW" "Only one display: scenario 21 runs on the main display alone."
    fi
fi

# --- Scenario 21: sets across displays (User Story 6) ----------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenario 21: label Desktops 2 and 3 on every display"
wait_for_person "Note which Desktop each display is showing now. Don't type or switch while the Desktops slide."
set_labels_applied=true
while IFS= read -r display_name; do
    timed_set "LABEL1" "$display_name" 2
    timed_set "LABEL2" "$display_name" 3
done < <(target_displays)
if ! "$dry_run"; then
    while IFS= read -r display_name; do
        check "show finds LABEL1 on ${display_name}, Desktop 2" shows_label "LABEL1" "$display_name" 2
        check "show finds LABEL2 on ${display_name}, Desktop 3" shows_label "LABEL2" "$display_name" 3
    done < <(target_displays)
fi
check "each display is back on the Desktop it started on" ask_to_look "Is every display showing the Desktop it showed before?"
check "Desktops 2 and 3 show LABEL1 and LABEL2" ask_to_look "Open Mission Control: do Desktops 2 and 3 of each display show LABEL1 and LABEL2 (and no other Desktop)?"
print_colored "$COLOR_YELLOW" "Removing the scenario 21 labels..."
run_step remove_set_labels
set_labels_applied=false

# --- Scenario 22: a label shared with a new Desktop (KI-1) -----------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenario 22: a label on Desktop 1 is shared with a new Desktop"
first_desktop_labeled=true
if "$dry_run"; then
    run_step "$dnm_binary" set "First" --display main --desktop 1
else
    note_output="$("$dnm_binary" set "First" --display main --desktop 1 2>&1)"
    printf "%s\n" "$note_output"
    check "labeling Desktop 1 prints the new-Desktop note" grep -q "copy of Desktop 1's wallpaper" <<<"$note_output"
fi
wait_for_person "Open Mission Control, click + on the main display to add a Desktop, then close Mission Control (stay on your Desktop)."
if "$dry_run"; then
    new_desktop_number=4
else
    read -r -p "$(printf "%bWhich number is the new Desktop (it is the last one)? %b" "$COLOR_BRIGHTYELLOW" "$COLOR_RESET")" new_desktop_number
    [[ "$new_desktop_number" =~ ^[0-9]+$ ]] || { print_colored "$COLOR_RED" "Not a number: ${new_desktop_number}"; exit 1; }
fi
check "the new Desktop shares the label (macOS copied Desktop 1)" shows_label "First" main "$new_desktop_number"
run_step "$dnm_binary" remove --display main --desktop "$new_desktop_number"
check "the new Desktop shows the original wallpaper" ask_to_look "Open Mission Control: is Desktop ${new_desktop_number} back to the normal wallpaper, with Desktop 1 still labeled 'First'?"
check "show --desktop 1 still recognizes the label" shows_label "First" main 1

# --- Scenario 23: prune ----------------------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenario 23: prune lists, and deletes only images no current Desktop shows"
# Make an image that is retired yet still on screen: put 'First' back on the new Desktop, then remove it
# from Desktop 1, and show the new Desktop.
run_step "$dnm_binary" undo --display main --desktop "$new_desktop_number"
check "undo --desktop brought 'First' back on the new Desktop" shows_label "First" main "$new_desktop_number"
run_step "$dnm_binary" remove --display main --desktop 1
first_desktop_labeled=false
wait_for_person "Switch the main display to Desktop ${new_desktop_number} (the new one, showing 'First')."
if "$dry_run"; then
    run_step "$dnm_binary" prune
else
    files_before="$(store_file_count)"
    prune_listing="$("$dnm_binary" prune 2>&1)"
    printf "%s\n" "$prune_listing"
    check "the listing deletes nothing" test "$(store_file_count)" -eq "$files_before"
    check "the listing names the scenario 21 labels" grep -q '"LABEL1"' <<<"$prune_listing"
    check "the listing leaves out 'First', which is on screen" lacks_label "First" "$prune_listing"
fi
run_step "$dnm_binary" prune --yes
check "the image on screen survived prune --yes" shows_no_missing_image
check "the label on screen is intact" ask_to_look "Is 'First' still showing on this Desktop?"
run_step "$dnm_binary" remove --display main
wait_for_person "Delete the Desktop you created (Desktop ${new_desktop_number}) in Mission Control, and go back to the Desktop you were on."
new_desktop_number=""
