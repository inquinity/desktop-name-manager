#!/usr/bin/env bash
#
# Write the build stamp (which commit a build came from) and print the linker flags that put it into the
# binary. Used by the justfile and the live-kit script, so `dnm --version` says exactly what you are testing.
#
# Usage: scripts/build-stamp.sh [--bump] [--release] [--help]
#   (no option)  an interim build: reported as "<version> build <build> (<commit>)" (with + if uncommitted changes)
#   --bump       first move the build number in Version.xcconfig forward by one (`just build`, `just build-release`
#                and the live kit do, so every build has a new number; `just test` and periphery do not)
#   --release    a release build: reported as "<version> build <build>". Only the release procedure (spec 005) uses
#                this; it never bumps (the release commit already holds the release's build number).
# The version and build number come from Version.xcconfig. A change to its build-number line alone does not count
# as uncommitted (scripts/tree-state), so a bumped build of a committed tree still shows no +.
#
# Prints the linker flags on standard output, one per line (so a path with spaces stays one argument);
# everything else goes to standard error. Read them into an array, for example:
#   stamp_flags=(); while IFS= read -r flag; do stamp_flags+=("$flag"); done < <(scripts/build-stamp.sh)

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
bump=false

usage() {
    print_colored "$COLOR_YELLOW" "Usage: scripts/build-stamp.sh [--bump] [--release] [--help]"
    print_colored "$COLOR_YELLOW" "Writes build.noindex/stamps/<name>.txt and prints the linker flags that embed it."
}

while (($# > 0)); do
    case "$1" in
        --release) kind="release"; shift ;;
        --bump) bump=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print_colored "$COLOR_RED" "Unknown option: $1"; usage; exit 2 ;;
    esac
done

if [[ "$kind" == "release" && "$bump" == true ]]; then
    print_colored "$COLOR_RED" "A release build never bumps the build number: --bump and --release do not go together."
    exit 2
fi

commit="$(git -C "$repository_root" rev-parse --short HEAD)"
# Uncommitted changes, including new files that are not ignored; a bumped build number alone is not one.
tree_state="$("${repository_root}/scripts/tree-state")"
dirty=0
[[ "$tree_state" == "dirty" ]] && dirty=1
# A release build must match its commit exactly, build number included.
if [[ "$kind" == "release" && "$tree_state" != "clean" ]]; then
    print_colored "$COLOR_RED" "A release build must come from a clean tree."
    exit 1
fi

# The version and build number come from Version.xcconfig, the single source (as in the sibling project). A bump
# reports the number it wrote: read back from the file, another build's bump in between could give both the same.
version="$("${repository_root}/scripts/ver")"
if "$bump"; then
    build="$("${repository_root}/scripts/bump-version.sh" build)"
else
    build="$("${repository_root}/scripts/build-num")"
fi

# The file name carries the stamp, so a different commit changes the link command and forces a relink.
mkdir -p "$stamp_directory"
stamp_file="${stamp_directory}/stamp-${version}-${build}-${commit}-${kind}-${dirty}.txt"
printf 'version=%s\nbuild=%s\ncommit=%s\ndirty=%s\nkind=%s\n' "$version" "$build" "$commit" "$dirty" "$kind" >"$stamp_file"

# -sectcreate takes a segment, a section and a file: the binary then holds the stamp in __DNM,build.
printf '%s\n' -Xlinker -sectcreate -Xlinker __DNM -Xlinker build -Xlinker "$stamp_file"
