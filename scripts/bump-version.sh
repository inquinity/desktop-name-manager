#!/usr/bin/env bash
#
# Bump one segment of MARKETING_VERSION in Version.xcconfig (major.minor.revision), resetting the segments
# below it, and move CURRENT_PROJECT_VERSION (the build number) forward with it: a bump is a single "cut a
# new version" operation, as in the sibling project. `current` changes nothing (the first release).
#
# Usage: scripts/bump-version.sh <major|minor|revision|current>

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

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_CONFIG="${PROJECT_ROOT}/Version.xcconfig"

segment="${1:-}"
case "$segment" in
    major|minor|revision|current) ;;
    -h|--help) print_colored "$COLOR_YELLOW" "Usage: scripts/bump-version.sh <major|minor|revision|current>"; exit 0 ;;
    *) print_colored "$COLOR_RED" "bump-version: the segment must be major, minor, revision or current"; exit 2 ;;
esac

current_version="$("${PROJECT_ROOT}/scripts/ver")"
current_build="$("${PROJECT_ROOT}/scripts/build-num")"
if [[ "$segment" == "current" ]]; then
    print_colored "$COLOR_YELLOW" "Keeping ${current_version} (${current_build})."
    exit 0
fi

IFS='.' read -r major minor revision <<<"$current_version"
[[ -n "${major:-}" && -n "${minor:-}" && -n "${revision:-}" ]] \
    || { print_colored "$COLOR_RED" "bump-version: MARKETING_VERSION is not major.minor.revision: ${current_version}"; exit 1; }
case "$segment" in
    major) major=$((major + 1)); minor=0; revision=0 ;;
    minor) minor=$((minor + 1)); revision=0 ;;
    revision) revision=$((revision + 1)) ;;
esac
new_version="${major}.${minor}.${revision}"
new_build=$((current_build + 1))

sed -i '' -E \
    -e "s/^MARKETING_VERSION = .*/MARKETING_VERSION = ${new_version}/" \
    -e "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = ${new_build}/" \
    "$VERSION_CONFIG"
print_colored "$COLOR_GREEN" "Version ${current_version} (${current_build}) -> ${new_version} (${new_build})."
