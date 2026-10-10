#!/usr/bin/env bash
#
# Compose the release notes for a version from docs/release-notes/UNRELEASED.md (the same process as the
# sibling project's bin/compose-release-notes.sh). `just release` writes the result to
# docs/release-notes/<version>.md and leaves the empty stub behind.
#
# Usage: scripts/compose-release-notes.sh --version X.Y.Z | --stub | --check [--help]

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
    printf "%b%s%b\n" "$color" "$message" "$COLOR_RESET" >&2
}

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNRELEASED_FILE="${PROJECT_ROOT}/docs/release-notes/UNRELEASED.md"
# The marker the empty stub carries; seeing it at release time means nothing was written down.
EMPTY_MARKER="_(nothing yet)_"

mode=""
version=""

usage() {
    print_colored "$COLOR_YELLOW" "Usage: scripts/compose-release-notes.sh --version X.Y.Z | --stub | --check"
    print_colored "$COLOR_YELLOW" "  --version X.Y.Z  print the notes for that version, built from docs/release-notes/UNRELEASED.md"
    print_colored "$COLOR_YELLOW" "  --stub           print the empty UNRELEASED.md stub"
    print_colored "$COLOR_YELLOW" "  --check          silent on success; exit 1 if UNRELEASED.md has nothing to release"
}

die() {
    print_colored "$COLOR_RED" "compose-release-notes: $1"
    exit 1
}

print_stub() {
    # The comment is kept in the stub, so the next change knows where its bullet goes.
    awk '/^-->/ { print; exit } { print }' "$UNRELEASED_FILE"
    printf '\n%s\n' "$EMPTY_MARKER"
}

# UNRELEASED.md minus its "# Unreleased" heading and its comment, without leading blank lines.
unreleased_body() {
    awk '
        NR == 1 && /^# Unreleased/ { next }
        /^<!--/ { in_comment = 1 }
        in_comment { if (/-->/) in_comment = 0; next }
        { print }
    ' "$UNRELEASED_FILE" | sed '/./,$!d'
}

check_notes() {
    [[ -f "$UNRELEASED_FILE" ]] || die "missing ${UNRELEASED_FILE#"$PROJECT_ROOT"/}"
    local body
    body="$(unreleased_body)"
    [[ -n "$body" ]] || die "docs/release-notes/UNRELEASED.md is empty: write down what changed first"
    # The composer adds this heading itself; a second one in UNRELEASED.md would be published twice (as in 0.1.1).
    if grep -qE '^## New in this release' <<<"$body"; then
        die "docs/release-notes/UNRELEASED.md must not have its own \"## New in this release\" heading: write bullets only"
    fi
    if grep -qF "$EMPTY_MARKER" <<<"$body"; then
        die "docs/release-notes/UNRELEASED.md still says ${EMPTY_MARKER}: write down what changed first"
    fi
}

while (($# > 0)); do
    case "$1" in
        --version) mode="version"; version="${2:?--version needs X.Y.Z}"; shift 2 ;;
        --stub) mode="stub"; shift ;;
        --check) mode="check"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print_colored "$COLOR_RED" "Unknown option: $1"; usage; exit 2 ;;
    esac
done

case "$mode" in
    stub) print_stub ;;
    check) check_notes ;;
    version)
        [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "the version must look like 1.2.3, not \"${version}\""
        check_notes
        printf '# Desktop Name Manager %s\n\n## New in this release\n\n' "$version"
        unreleased_body
        ;;
    *) usage; exit 2 ;;
esac
