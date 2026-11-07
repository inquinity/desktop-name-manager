#!/usr/bin/env bash
#
# Move Version.xcconfig forward:
#   major|minor|revision  bump that segment of MARKETING_VERSION (major.minor.revision) and reset the segments
#                         below it. The build number is left alone. The release procedure does this right after
#                         a release (`just publish record`), so the file always names the version being worked on;
#                         `just bump <segment>` does it by hand.
#   build                 add one to CURRENT_PROJECT_VERSION, the build number. Every `just build` and
#                         `just build-release` does this (scripts/build-stamp.sh --bump), and so does `just release`,
#                         so no two builds share a number.
#
# Usage: scripts/bump-version.sh <major|minor|revision|build>

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
    major|minor|revision|build) ;;
    -h|--help) print_colored "$COLOR_YELLOW" "Usage: scripts/bump-version.sh <major|minor|revision|build>"; exit 0 ;;
    *) print_colored "$COLOR_RED" "bump-version: the segment must be major, minor, revision or build"; exit 2 ;;
esac

current_version="$("${PROJECT_ROOT}/scripts/ver")"
current_build="$("${PROJECT_ROOT}/scripts/build-num")"
[[ "$current_build" =~ ^[0-9]+$ ]] \
    || { print_colored "$COLOR_RED" "bump-version: CURRENT_PROJECT_VERSION is not a number: ${current_build}"; exit 1; }
if [[ "$segment" == "build" ]]; then
    new_build=$((current_build + 1))
    sed -i '' -E "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = ${new_build}/" "$VERSION_CONFIG"
    print_colored "$COLOR_GREEN" "Build ${current_build} -> ${new_build} (${current_version})."
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

sed -i '' -E "s/^MARKETING_VERSION = .*/MARKETING_VERSION = ${new_version}/" "$VERSION_CONFIG"
print_colored "$COLOR_GREEN" "Version ${current_version} -> ${new_version} (build ${current_build} stays; the next build moves it)."
