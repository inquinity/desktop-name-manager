#!/usr/bin/env bash
#
# Tests for scripts/tree-state and scripts/bump-version.sh, in a throwaway git repository (the real
# Version.xcconfig is never touched). `just test` runs this after the Swift tests.
#
# Usage: Tests/scripts/version-scripts-test.sh [--help]

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

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    print_colored "$COLOR_YELLOW" "Usage: Tests/scripts/version-scripts-test.sh"
    exit 0
fi

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
scratch_repository="$(mktemp -d)"
trap 'rm -rf "$scratch_repository"' EXIT
failures=0

# git in the scratch repository only, with no signing and a neutral identity.
scratch_git() {
    git -C "$scratch_repository" -c commit.gpgsign=false -c user.name=test -c user.email=test@example.invalid "$@"
}

expect_equal() {
    local description=$1 expected=$2 actual=$3
    if [[ "$expected" == "$actual" ]]; then
        print_colored "$COLOR_GREEN" "PASS  ${description}"
    else
        print_colored "$COLOR_RED" "FAIL  ${description}: expected \"${expected}\", got \"${actual}\""
        failures=$((failures + 1))
    fi
}

tree_state() { "${scratch_repository}/scripts/tree-state"; }
set_build() { sed -i '' -E "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $1/" "${scratch_repository}/Version.xcconfig"; }
reset_tree() { scratch_git reset -q --hard; scratch_git clean -qfd; }

# --- A small repository with the scripts and a version file ---
mkdir -p "${scratch_repository}/scripts"
for script_name in tree-state bump-version.sh ver build-num; do
    cp "${repository_root}/scripts/${script_name}" "${scratch_repository}/scripts/"
done
printf '// test\n\nMARKETING_VERSION = 0.2.2\nCURRENT_PROJECT_VERSION = 5\n' >"${scratch_repository}/Version.xcconfig"
printf 'readme\n' >"${scratch_repository}/README.md"
scratch_git init -q
scratch_git add -A
scratch_git commit -qm initial

# --- tree-state ---
expect_equal "a committed tree is clean" "clean" "$(tree_state)"

set_build 6
expect_equal "a higher build number alone is build-number" "build-number" "$(tree_state)"
scratch_git add Version.xcconfig
expect_equal "a staged higher build number is build-number" "build-number" "$(tree_state)"
set_build 7
expect_equal "staged 6 and unstaged 7 are build-number" "build-number" "$(tree_state)"
reset_tree

set_build 4
expect_equal "a lower build number is dirty" "dirty" "$(tree_state)"
reset_tree

set_build 6
printf 'more\n' >>"${scratch_repository}/README.md"
expect_equal "a build number and another change are dirty" "dirty" "$(tree_state)"
reset_tree

set_build 6
printf 'new\n' >"${scratch_repository}/new-file"
expect_equal "a build number and an untracked file are dirty" "dirty" "$(tree_state)"
reset_tree

sed -i '' -E 's/^MARKETING_VERSION = .*/MARKETING_VERSION = 0.2.3/' "${scratch_repository}/Version.xcconfig"
expect_equal "a version change is dirty" "dirty" "$(tree_state)"
reset_tree

sed -i '' -E 's/^MARKETING_VERSION = .*/MARKETING_VERSION = 0.2.3/' "${scratch_repository}/Version.xcconfig"
scratch_git add Version.xcconfig
sed -i '' -E 's/^MARKETING_VERSION = .*/MARKETING_VERSION = 0.2.2/' "${scratch_repository}/Version.xcconfig"
set_build 6
expect_equal "a staged version change under an unstaged build number is dirty" "dirty" "$(tree_state)"
reset_tree

printf '// test\r\n\r\nMARKETING_VERSION = 0.2.2\r\nCURRENT_PROJECT_VERSION = 6\r\n' >"${scratch_repository}/Version.xcconfig"
expect_equal "line endings changed to CRLF are dirty" "dirty" "$(tree_state)"
reset_tree

scratch_git mv README.md README.txt
expect_equal "a rename is dirty" "dirty" "$(tree_state)"
reset_tree

# --- bump-version.sh ---
"${scratch_repository}/scripts/bump-version.sh" build >/dev/null
expect_equal "build adds one to the build number" "0.2.2 5->6" "$("${scratch_repository}/scripts/ver") 5->$("${scratch_repository}/scripts/build-num")"
"${scratch_repository}/scripts/bump-version.sh" revision >/dev/null
expect_equal "revision moves the version and keeps the build number" "0.2.3 6" "$("${scratch_repository}/scripts/ver") $("${scratch_repository}/scripts/build-num")"
"${scratch_repository}/scripts/bump-version.sh" minor >/dev/null
expect_equal "minor resets the revision" "0.3.0 6" "$("${scratch_repository}/scripts/ver") $("${scratch_repository}/scripts/build-num")"
"${scratch_repository}/scripts/bump-version.sh" major >/dev/null
expect_equal "major resets minor and revision" "1.0.0 6" "$("${scratch_repository}/scripts/ver") $("${scratch_repository}/scripts/build-num")"
reset_tree

for build_index in 1 2 3 4 5 6 7 8; do
    "${scratch_repository}/scripts/bump-version.sh" build >/dev/null &
done
wait
expect_equal "eight bumps at once give eight numbers" "13" "$("${scratch_repository}/scripts/build-num")"
reset_tree

bump_status=0
"${scratch_repository}/scripts/bump-version.sh" current >/dev/null 2>&1 || bump_status=$?
expect_equal "an unknown segment is refused" "2" "$bump_status"

if ((failures > 0)); then
    print_colored "$COLOR_RED" "${failures} version-script test(s) failed."
    exit 1
fi
print_colored "$COLOR_GREEN" "All version-script tests passed."
