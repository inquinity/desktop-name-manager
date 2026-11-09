#!/usr/bin/env bash
#
# Move Version.xcconfig forward:
#   major|minor|revision  bump that segment of MARKETING_VERSION (major.minor.revision) and reset the segments
#                         below it. The build number is left alone. The release procedure does this right after
#                         a release (`just publish record`), so the file always names the version being worked on;
#                         `just bump <segment>` does it by hand.
#   build                 add one to CURRENT_PROJECT_VERSION, the build number, and print the new number (alone,
#                         on standard output; the message goes to standard error). Every `just build` and
#                         `just build-release` does this (scripts/build-stamp.sh --bump), and so does `just release`.
#                         Callers use the printed number rather than reading the file again, so two builds started
#                         together still get different numbers.
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

# Function to print colored output (to standard error: `build` prints only the new number on standard output,
# which callers capture, so every message must stay visible on the terminal)
print_colored() {
    local color=$1
    local message=$2
    printf "%b%s%b\n" "$color" "$message" "$COLOR_RESET" >&2
}

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_CONFIG="${PROJECT_ROOT}/Version.xcconfig"

segment="${1:-}"
case "$segment" in
    major|minor|revision|build) ;;
    -h|--help) print_colored "$COLOR_YELLOW" "Usage: scripts/bump-version.sh <major|minor|revision|build>"; exit 0 ;;
    *) print_colored "$COLOR_RED" "bump-version: the segment must be major, minor, revision or build"; exit 2 ;;
esac

# One bump at a time: two builds started together must not both read N and write N + 1. mkdir is atomic.
lock_directory="${PROJECT_ROOT}/build.noindex/version-bump.lock"
mkdir -p "${PROJECT_ROOT}/build.noindex"
lock_attempts=0
until mkdir "$lock_directory" 2>/dev/null; do
    lock_attempts=$((lock_attempts + 1))
    if ((lock_attempts > 100)); then
        print_colored "$COLOR_RED" "bump-version: ${lock_directory} has been held for 10 seconds; remove it if no build is running"
        exit 1
    fi
    sleep 0.1
done
trap 'rmdir "$lock_directory" 2>/dev/null || true' EXIT

current_version="$("${PROJECT_ROOT}/scripts/ver")"
current_build="$("${PROJECT_ROOT}/scripts/build-num")"
[[ "$current_build" =~ ^[0-9]+$ ]] \
    || { print_colored "$COLOR_RED" "bump-version: CURRENT_PROJECT_VERSION is not a number: ${current_build}"; exit 1; }
if [[ "$segment" == "build" ]]; then
    new_build=$((current_build + 1))
    sed -i '' -E "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = ${new_build}/" "$VERSION_CONFIG"
    print_colored "$COLOR_GREEN" "Build ${current_build} -> ${new_build} (${current_version})."
    printf '%s\n' "$new_build"
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
