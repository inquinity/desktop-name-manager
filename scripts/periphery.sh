#!/usr/bin/env bash
#
# Scan the package for unused code with Periphery and fail on any finding.
# Read-only: it builds into build.noindex/ and prints a report; it changes no tracked file.
#
# Usage: scripts/periphery.sh [--help]

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

usage() {
    print_colored "$COLOR_YELLOW" "Usage: scripts/periphery.sh [--help]"
    print_colored "$COLOR_YELLOW" "Scans the Swift package for unused code and exits non-zero on any finding."
    print_colored "$COLOR_YELLOW" "Configuration: .periphery.yml. Requires the 'periphery' command (Homebrew)."
}

while (($# > 0)); do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        *) print_colored "$COLOR_RED" "Unknown option: $1"; usage; exit 2 ;;
    esac
done

if ! command -v periphery >/dev/null 2>&1; then
    print_colored "$COLOR_RED" "periphery is not installed. Install it with: brew install periphery"
    exit 1
fi

# Run from the repository root so Package.swift and .periphery.yml are found.
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

print_colored "$COLOR_BRIGHTYELLOW" "Scanning for unused code (periphery $(periphery version))..."
# Periphery reads the compiler's index store. With Xcode 27's default SwiftPM build system
# that store is not written where Periphery looks, so the native build system is used.
if periphery scan --strict -- --build-system native --scratch-path "${repository_root}/build.noindex"; then
    print_colored "$COLOR_GREEN" "No unused code found."
else
    print_colored "$COLOR_RED" "Periphery failed or reported unused code (see above)."
    exit 1
fi
