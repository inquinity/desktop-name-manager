#!/usr/bin/env bash
#
# Write the build stamp (which commit a build came from) and print the linker flags that put it into the
# binary. Used by the justfile and the live-kit script, so `dnm --version` says exactly what you are testing.
#
# Usage: scripts/build-stamp.sh [--release] [--help]
#   (no option)  an interim build: reported as <version>-dev+<commit> (with .dirty if uncommitted changes)
#   --release    a release build: reported as the plain version. Only the release procedure (spec 005) uses this.
#
# Prints one line of linker flags on standard output; everything else goes to standard error.

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

# Function to print colored output (to standard error, so standard output stays the flags)
print_colored() {
    local color=$1
    local message=$2
    printf "%b%s%b\n" "$color" "$message" "$COLOR_RESET" >&2
}

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stamp_directory="${repository_root}/build.noindex/stamps"
kind="interim"

usage() {
    print_colored "$COLOR_YELLOW" "Usage: scripts/build-stamp.sh [--release] [--help]"
    print_colored "$COLOR_YELLOW" "Writes build.noindex/stamps/<name>.txt and prints the linker flags that embed it."
}

while (($# > 0)); do
    case "$1" in
        --release) kind="release"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print_colored "$COLOR_RED" "Unknown option: $1"; usage; exit 2 ;;
    esac
done

commit="$(git -C "$repository_root" rev-parse --short HEAD)"
dirty=0
# Uncommitted changes, including new files that are not ignored.
if [[ -n "$(git -C "$repository_root" status --porcelain)" ]]; then
    dirty=1
fi
if [[ "$kind" == "release" && "$dirty" == 1 ]]; then
    print_colored "$COLOR_RED" "A release build must come from a clean tree."
    exit 1
fi

# The file name carries the stamp, so a different commit changes the link command and forces a relink.
mkdir -p "$stamp_directory"
stamp_file="${stamp_directory}/stamp-${commit}-${kind}-${dirty}.txt"
printf 'commit=%s\ndirty=%s\nkind=%s\n' "$commit" "$dirty" "$kind" >"$stamp_file"

# -sectcreate takes a segment, a section and a file: the binary then holds the stamp in __DNM,build.
printf '%s' "-Xlinker -sectcreate -Xlinker __DNM -Xlinker build -Xlinker ${stamp_file}"
