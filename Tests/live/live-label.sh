#!/usr/bin/env bash
#
# Live checks for spec 001 (quickstart scenarios 1-3, 5-11, 16, 19) against the REAL wallpaper.
#
# This changes the wallpaper of the Desktop you are on. Run it only while you are idle, on a Desktop
# whose wallpaper is a normal image file, with "Show on all Spaces" turned off. It backs up the
# wallpaper store first, uses a private store directory, and removes its labels when it finishes.
#
# Usage: Tests/live/live-label.sh [--dnm PATH] [--with-cooldown] [--dry-run] [--help]

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
with_cooldown=false
dry_run=false
work_directory=""
failures=0
labels_applied=false

usage() {
    print_colored "$COLOR_YELLOW" "Usage: Tests/live/live-label.sh [--dnm PATH] [--with-cooldown] [--dry-run] [--help]"
    print_colored "$COLOR_YELLOW" "  --dnm PATH        the dnm binary to test (default: build.noindex/release/dnm; build it first)"
    print_colored "$COLOR_YELLOW" "  --with-cooldown   also run scenario 16: wait 31 minutes and check the cleanup"
    print_colored "$COLOR_YELLOW" "  --dry-run, -n     print the steps without touching the wallpaper"
    print_colored "$COLOR_YELLOW" "Changes the real wallpaper of the Desktop you are on. Run only while idle."
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

cleanup() {
    local exit_status=$?
    if "$dry_run"; then
        return
    fi
    if "$labels_applied"; then
        print_colored "$COLOR_YELLOW" "Cleaning up: removing any label left on this Desktop..."
        "$dnm_binary" remove >/dev/null 2>&1 || true
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

while (($# > 0)); do
    case "$1" in
        --dnm) dnm_binary="${2:?--dnm needs a path}"; shift 2 ;;
        --with-cooldown) with_cooldown=true; shift ;;
        -n|--dry-run) dry_run=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print_colored "$COLOR_RED" "Unknown option: $1"; usage; exit 2 ;;
    esac
done

if ! "$dry_run"; then
    [[ -x "$dnm_binary" ]] || { print_colored "$COLOR_RED" "No executable at ${dnm_binary}. Run: just release"; exit 1; }
    [[ -f "$wallpaper_store_plist" ]] || { print_colored "$COLOR_RED" "Cannot find the wallpaper store: ${wallpaper_store_plist}"; exit 1; }
    work_directory="$(mktemp -d "${TMPDIR:-/tmp}/dnm-live.XXXXXX")"
    cp "$wallpaper_store_plist" "${work_directory}/Index.plist.backup"
    export DNM_STORE_DIR="${work_directory}/store"
    print_colored "$COLOR_BRIGHTYELLOW" "Backed up the wallpaper store to ${work_directory}"
    print_colored "$COLOR_BRIGHTYELLOW" "Using a private store: ${DNM_STORE_DIR}"
    read -r -p "This changes your real wallpaper. Are you idle, on the right Desktop, with 'Show on all Spaces' off? [y/N] " confirm
    [[ "$confirm" == [yY]* ]] || { print_colored "$COLOR_RED" "Cancelled."; exit 1; }
fi
trap cleanup EXIT

print_run_environment() {
    # So a log copied back from another Mac says what it ran on.
    if "$dry_run"; then
        return
    fi
    print_colored "$COLOR_YELLOW" "Run on: macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), $(uname -m), dnm $("$dnm_binary" --version), $(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
print_run_environment

if ! "$dry_run"; then
    main_display_name="$("$dnm_binary" displays | sed -n 's/^\(.*[^ ]\) *(main)$/\1/p')"
    print_colored "$COLOR_BRIGHTYELLOW" "Labels go to the main display: ${main_display_name}. Watch THAT screen; other displays and Desktops are not labeled."
fi

# Small checks as functions, so the binary path is never pasted into a shell string.
list_ends_with_scope_note() {
    local listing
    listing="$("$dnm_binary" list)"
    [[ "$(tail -n 1 <<<"$listing")" == "Only labeled and current Desktops are shown." ]]
}

list_json_carries_scope() {
    local document
    document="$("$dnm_binary" list --json)"
    grep -q '"scope"' <<<"$document"
}

show_flags_missing_stamp() {
    local details
    details="$("$dnm_binary" show)"
    grep -qi 'missing' <<<"$details"
}

manifest_value() {
    # manifest_value <key path>: read one value from the private manifest with plutil.
    plutil -extract "$1" raw -o - "${DNM_STORE_DIR}/manifest.json"
}

# --- Scenario 1: label, timing, other Desktops untouched (looked at by you) -----------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenario 1: label the current Desktop"
labels_applied=true
if ! "$dry_run"; then
    start_seconds=$SECONDS
fi
run_step "$dnm_binary" set "Email"
check "the label is readable, bottom-left, on this Desktop only (visit the others)" ask_to_look "Look at the main display (${main_display_name:-the main display}): is 'Email' readable bottom-left there, and absent on your other Desktops?"

# --- Scenario 2: show matches ----------------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenario 2: show matches what you see"
run_step "$dnm_binary" show
check "show lists the label with its automatic style and color" ask_to_look "Does 'show' describe what you see (look, color, bottom-left)?"

# --- Scenario 3: replace resets options ------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenario 3: a replacement resets omitted options"
run_step "$dnm_binary" set "Mail" --size large
check "the first 'Mail' is large" ask_to_look "Is 'Mail' clearly LARGER than the earlier 'Email' label?"
run_step "$dnm_binary" set "Mail"
check "the second 'Mail' is medium again" ask_to_look "Is the second 'Mail' back to the normal size (not large)?"

# --- Scenario 5: exact restore, original untouched -------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenario 5: remove restores the original exactly"
if ! "$dry_run"; then
    original_path="$(manifest_value stamps.0.original.path)"
    checksum_before="$(shasum -a 256 "$original_path" | awk '{print $1}')"
fi
run_step "$dnm_binary" remove
if ! "$dry_run"; then
    checksum_after="$(shasum -a 256 "$original_path" | awk '{print $1}')"
fi
check "the original image file is byte-identical" test "${checksum_before:-a}" = "${checksum_after:-a}"
check "the original wallpaper and its placement are back" ask_to_look "Is your original wallpaper back, placed as before (check System Settings > Wallpaper)?"

# --- Scenario 6: undo ------------------------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenario 6: undo"
run_step "$dnm_binary" set "Email"
run_step "$dnm_binary" remove
run_step "$dnm_binary" undo
check "'Email' is back after undo" ask_to_look "Is 'Email' showing again?"
if ! "$dry_run"; then
    if "$dnm_binary" undo >/dev/null 2>&1; then
        print_colored "$COLOR_RED" "FAIL  a second undo should have nothing to undo"
        failures=$((failures + 1))
    else
        print_colored "$COLOR_GREEN" "PASS  a second undo has nothing to undo"
    fi
fi

# --- Scenario 7 and 8: limits and emoji ------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenarios 7 and 8: limits and emoji"
if ! "$dry_run"; then
    set +e
    "$dnm_binary" set "$(printf 'a%.0s' {1..31})" >/dev/null 2>&1; status_long=$?
    "$dnm_binary" set "$(printf 'Mail\nBox')" >/dev/null 2>&1; status_break=$?
    set -e
    check "31 characters exits 2" test "$status_long" -eq 2
    check "a line break exits 2" test "$status_break" -eq 2
fi
run_step "$dnm_binary" set "Mail ✉️"
check "the emoji is drawn cleanly" ask_to_look "Is 'Mail ✉️' drawn cleanly, not clipped?"

# --- Scenarios 9 and 10: displays ------------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenarios 9 and 10: displays"
run_step "$dnm_binary" displays
run_step "$dnm_binary" set "Test" --display main
if ! "$dry_run"; then
    set +e
    "$dnm_binary" set "Test" --display "no-such-display-anywhere" >/dev/null 2>&1; status_unknown=$?
    set -e
    check "an unknown display exits 2 and changes nothing" test "$status_unknown" -eq 2
fi

# --- Scenario 11: list ---------------------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenario 11: list"
run_step "$dnm_binary" list
if ! "$dry_run"; then
    check "list ends with the scope note" list_ends_with_scope_note
    check "list --json carries the scope" list_json_carries_scope
fi

# --- Scenario 19: missing stamp --------------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenario 19: a deleted stamp file"
if ! "$dry_run"; then
    stamp_file="${DNM_STORE_DIR}/$(manifest_value "stamps.$(( $(plutil -extract stamps raw -o - "${DNM_STORE_DIR}/manifest.json") - 1 )).fileName")"
    # Only ever delete a stamp inside the private store this script created.
    case "$stamp_file" in
        "${DNM_STORE_DIR}"/*.dnm.*) rm -f "$stamp_file" ;;
        *) print_colored "$COLOR_RED" "Refusing to delete ${stamp_file}: it is not inside the private store."; exit 1 ;;
    esac
    check "show flags the missing stamp" show_flags_missing_stamp
fi
run_step "$dnm_binary" set "Rebuilt"
check "set rebuilds the stamp and the label shows" ask_to_look "Is 'Rebuilt' showing?"
run_step "$dnm_binary" remove

# --- Scenario 16: cool-down cleanup (optional, 31 minutes) -----------------------------------------
if "$with_cooldown"; then
    print_colored "$COLOR_BRIGHTYELLOW" "Scenario 16: waiting 31 minutes for the cool-down (do not touch the wallpaper)"
    run_step sleep 1860
    run_step "$dnm_binary" list
    if ! "$dry_run"; then
        remaining="$(find "$DNM_STORE_DIR" -maxdepth 1 -name '*.dnm.*' | wc -l | tr -d ' ')"
        check "no stamp files remain after the cool-down (none are active)" test "$remaining" -eq 0
    fi
else
    print_colored "$COLOR_YELLOW" "Skipping scenario 16 (needs 31 minutes); run again with --with-cooldown."
fi

labels_applied=false
if ! "$dry_run"; then
    print_colored "$COLOR_YELLOW" "Scenario 4 (restart, reorder, Show Desktop) is manual: it needs a log out."
    print_colored "$COLOR_YELLOW" "Elapsed: $((SECONDS - start_seconds)) s. Time scenario 1 yourself for the one-second budget."
fi
