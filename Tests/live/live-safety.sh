#!/usr/bin/env bash
#
# Live checks for spec 001, scenarios 12-15 (unsupported wallpaper, unreadable wallpaper, no network,
# originals untouched) against the REAL wallpaper.
#
# This changes the wallpaper of the Desktop you are on. Run it only while you are idle. It backs up
# the wallpaper store first, uses a private store directory, and removes its labels when it finishes.
#
# Usage: Tests/live/live-safety.sh [--dnm PATH] [--dry-run] [--help]

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
dry_run=false
work_directory=""
failures=0
labels_applied=false

usage() {
    print_colored "$COLOR_YELLOW" "Usage: Tests/live/live-safety.sh [--dnm PATH] [--dry-run] [--help]"
    print_colored "$COLOR_YELLOW" "  --dnm PATH     the dnm binary to test (default: build.noindex/release/dnm; build it first)"
    print_colored "$COLOR_YELLOW" "  --dry-run, -n  print the steps without touching the wallpaper"
    print_colored "$COLOR_YELLOW" "Changes the real wallpaper of the Desktop you are on. Run only while idle."
}

record_result() {
    # record_result <passed: true|false> <description>
    if [[ "$1" == true ]]; then
        print_colored "$COLOR_GREEN" "PASS  $2"
    else
        print_colored "$COLOR_RED" "FAIL  $2"
        failures=$((failures + 1))
    fi
}

wait_for_person() {
    # Pause until the person has done a manual step.
    if "$dry_run"; then
        print_colored "$COLOR_CYAN" "[dry run] ask: $1"
        return
    fi
    read -r -p "$(printf "${COLOR_BRIGHTYELLOW}%s Press Return when ready. ${COLOR_RESET}" "$1")" _
}

cleanup() {
    local exit_status=$?
    if "$dry_run"; then
        return
    fi
    if "$labels_applied"; then
        "$dnm_binary" remove >/dev/null 2>&1 || true
    fi
    if [[ -n "$work_directory" && -f "${work_directory}/Index.plist.backup" ]] \
        && ! cmp -s "${work_directory}/Index.plist.backup" "$wallpaper_store_plist"; then
        print_colored "$COLOR_YELLOW" "The wallpaper store differs from the backup (macOS rewrites it as Desktops change)."
        print_colored "$COLOR_YELLOW" "If the wallpaper looks wrong, restore it, then log out and in:"
        print_colored "$COLOR_YELLOW" "  cp '${work_directory}/Index.plist.backup' '${wallpaper_store_plist}'"
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
        -n|--dry-run) dry_run=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print_colored "$COLOR_RED" "Unknown option: $1"; usage; exit 2 ;;
    esac
done

if "$dry_run"; then
    print_colored "$COLOR_CYAN" "[dry run] would: back up Index.plist; use a private DNM_STORE_DIR"
    print_colored "$COLOR_CYAN" "[dry run] scenario 12: ask you to show a dynamic or aerial wallpaper, run 'dnm set', expect exit 3 and no change"
    print_colored "$COLOR_CYAN" "[dry run] scenario 13: ask you to show a wallpaper from a protected folder, run 'dnm set', expect the system error and exit 1"
    print_colored "$COLOR_CYAN" "[dry run] scenario 14: run set, show, list, remove with network access denied (sandbox-exec) and expect success"
    print_colored "$COLOR_CYAN" "[dry run] scenario 15: checksum the original image before and after"
    exit 0
fi

[[ -x "$dnm_binary" ]] || { print_colored "$COLOR_RED" "No executable at ${dnm_binary}. Run: just release"; exit 1; }
[[ -f "$wallpaper_store_plist" ]] || { print_colored "$COLOR_RED" "Cannot find the wallpaper store: ${wallpaper_store_plist}"; exit 1; }
command -v sandbox-exec >/dev/null 2>&1 || { print_colored "$COLOR_RED" "sandbox-exec is needed to block the network for scenario 14."; exit 1; }

work_directory="$(mktemp -d "${TMPDIR:-/tmp}/dnm-live-safety.XXXXXX")"
cp "$wallpaper_store_plist" "${work_directory}/Index.plist.backup"
export DNM_STORE_DIR="${work_directory}/store"
print_colored "$COLOR_BRIGHTYELLOW" "Backed up the wallpaper store to ${work_directory}"
read -r -p "This changes your real wallpaper. Are you idle, on the right Desktop, with 'Show on all Spaces' off? [y/N] " confirm
[[ "$confirm" == [yY]* ]] || { print_colored "$COLOR_RED" "Cancelled."; exit 1; }
trap cleanup EXIT

print_colored "$COLOR_YELLOW" "Run on: macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), $(uname -m), dnm $("$dnm_binary" --version), $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Scenario 12: unsupported wallpaper ------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenario 12: unsupported wallpaper"
wait_for_person "In System Settings > Wallpaper, choose a dynamic or aerial wallpaper for this Desktop."
set +e
"$dnm_binary" set "Test" >/dev/null 2>"${work_directory}/stderr.txt"
status_unsupported=$?
set -e
record_result "$([[ $status_unsupported -eq 3 ]] && echo true || echo false)" "set on a dynamic wallpaper exits 3 (got ${status_unsupported})"
record_result "$([[ ! -e "${DNM_STORE_DIR}/manifest.json" ]] && echo true || echo false)" "nothing was stored"
print_colored "$COLOR_YELLOW" "Message shown: $(cat "${work_directory}/stderr.txt")"

# --- Scenario 13: unreadable wallpaper -------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenario 13: wallpaper in a protected folder"
wait_for_person "Choose a wallpaper that lives in a macOS-protected folder (for example one inside ~/Documents), and make sure the terminal you run this from has NOT been allowed to read it."
set +e
"$dnm_binary" set "Test" >/dev/null 2>"${work_directory}/stderr.txt"
status_denied=$?
set -e
record_result "$([[ $status_denied -eq 1 ]] && echo true || echo false)" "set on an unreadable wallpaper exits 1 (got ${status_denied})"
print_colored "$COLOR_YELLOW" "Message shown (should be the system's own wording): $(cat "${work_directory}/stderr.txt")"

# --- Scenarios 14 and 15: no network, originals untouched ------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Scenarios 14 and 15: network blocked, originals untouched"
wait_for_person "Choose an ordinary image wallpaper stored somewhere readable, for example in ~/Pictures."
original_path=""
profile='(version 1)(allow default)(deny network*)'
no_network() { sandbox-exec -p "$profile" "$dnm_binary" "$@"; }

labels_applied=true
if no_network set "Offline"; then
    record_result true "set works with network access denied"
else
    record_result false "set works with network access denied"
fi
original_path="$(plutil -extract stamps.0.original.path raw -o - "${DNM_STORE_DIR}/manifest.json")"
checksum_before="$(shasum -a 256 "$original_path" | awk '{print $1}')"
for command_name in show list displays; do
    if no_network "$command_name" >/dev/null; then
        record_result true "${command_name} works with network access denied"
    else
        record_result false "${command_name} works with network access denied"
    fi
done
if no_network remove >/dev/null; then
    record_result true "remove works with network access denied"
else
    record_result false "remove works with network access denied"
fi
labels_applied=false
checksum_after="$(shasum -a 256 "$original_path" | awk '{print $1}')"
record_result "$([[ "$checksum_before" == "$checksum_after" ]] && echo true || echo false)" "the original image is byte-identical after labeling and removing"
