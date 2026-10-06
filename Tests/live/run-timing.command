#!/usr/bin/env bash
#
# Double-click in Finder (it opens Terminal) to run the dnm timing check from a live-test kit.
# Shows the setup dnm can see, runs Tests/live/live-timing.sh, and appends everything to
# results/live-timing.txt. Lives at the top of the kit, next to `dnm` and `switch-timing`.

set -uo pipefail

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

kit_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_file="${kit_directory}/results/live-timing.txt"

# shellcheck disable=SC2329  # called by the EXIT trap
finish() {
    # Keep the Terminal window open so the result can be read.
    printf "\n"
    read -r -p "Press Return to close this window. " _
}
trap finish EXIT

cd "$kit_directory" || { print_colored "$COLOR_RED" "Cannot open the kit folder: ${kit_directory}"; exit 1; }
if [[ ! -x ./dnm || ! -x ./switch-timing || ! -x ./Tests/live/live-timing.sh ]]; then
    print_colored "$COLOR_RED" "This must sit in the dnm live-test kit folder, next to dnm and switch-timing."
    exit 1
fi
mkdir -p results

print_colored "$COLOR_BRIGHTYELLOW" "dnm timing check ($(./dnm --version))"
print_colored "$COLOR_YELLOW" "What dnm can see of the setup (Accessibility must say ok; the shortcuts cannot be read):"
./dnm check
printf "\n"
print_colored "$COLOR_YELLOW" "Needs: at least three Desktops on every display. Takes 10 to 20 minutes; don't type meanwhile."
print_colored "$COLOR_YELLOW" "Log: ${log_file}"
printf "\n"

Tests/live/live-timing.sh 2>&1 | tee -a "$log_file"
run_result=${PIPESTATUS[0]}

if ((run_result == 0)); then
    print_colored "$COLOR_GREEN" "Finished. Copy the whole kit folder back (the results folder matters most)."
else
    print_colored "$COLOR_RED" "The timing check stopped (exit ${run_result}). The reason is above and in ${log_file}."
fi
exit "$run_result"
