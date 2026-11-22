#!/usr/bin/env bash
#
# Tests for scripts/make-app.sh (spec 014, task T017): its dry run lists exactly the bundle layout in
# specs/014-menu-bar-app/contracts/app-bundle.md, and --dev switches to the development bundle ID. Writes nothing.
# `just test` runs this after the Swift tests.
#
# Usage: Tests/scripts/make-app-test.sh [--help]

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
    print_colored "$COLOR_YELLOW" "Usage: Tests/scripts/make-app-test.sh"
    exit 0
fi

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
make_app="${repository_root}/scripts/make-app.sh"
failures=0

check() {
    local description=$1
    shift
    if "$@"; then
        print_colored "$COLOR_GREEN" "PASS  ${description}"
    else
        print_colored "$COLOR_RED" "FAIL  ${description}"
        failures=$((failures + 1))
    fi
}

# The layout lines of a dry run: everything after the "Contents/:" heading, without color codes.
dry_run_layout() {
    "$make_app" --dry-run "$@" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | sed -n '/^Contents\/:$/,$p' | tail -n +2
}

dry_run_field() {
    local field=$1
    shift
    "$make_app" --dry-run "$@" 2>/dev/null | sed -n "s/^${field}: //p"
}

expected_layout="$(
    printf '%s\n' Info.plist PkgInfo MacOS/DesktopNameManager Helpers/dnm Resources/AppIcon.icns \
        Resources/MenuBarGlyph.svg Resources/Licenses/LICENSE.txt
    while IFS= read -r license_file; do
        printf 'Resources/Licenses/%s\n' "$(basename "$license_file")"
    done < <("${repository_root}/scripts/make-acknowledgements.sh" --binary-license-files)
)"

layout_matches() { [[ "$(dry_run_layout --dev debug)" == "$expected_layout" ]]; }
release_layout_matches() { [[ "$(dry_run_layout release)" == "$expected_layout" ]]; }
dev_bundle_id() { [[ "$(dry_run_field "bundle id" --dev debug)" == "com.altmansoftwaredesign.desktop-name-manager.dev" ]]; }
release_bundle_id() { [[ "$(dry_run_field "bundle id" release)" == "com.altmansoftwaredesign.desktop-name-manager" ]]; }
version_from_xcconfig() {
    [[ "$(dry_run_field version debug)" == "$("${repository_root}/scripts/ver") ($("${repository_root}/scripts/build-num"))" ]]
}
needs_a_configuration() { ! "$make_app" --dry-run >/dev/null 2>&1; }
rejects_unknown_options() { ! "$make_app" --dry-run --sign debug >/dev/null 2>&1; }
template_has_no_usage_descriptions() { ! grep -q 'UsageDescription' "${repository_root}/Resources/App/Info.plist"; }
template_is_an_accessory_app() {
    [[ "$(plutil -extract LSUIElement raw "${repository_root}/Resources/App/Info.plist")" == "true" ]]
}

check "the dry run lists exactly the contract's layout" layout_matches
check "a release dry run lists the same layout" release_layout_matches
check "--dev uses the development bundle ID" dev_bundle_id
check "without --dev the release bundle ID is used" release_bundle_id
check "the version and build come from Version.xcconfig" version_from_xcconfig
check "a configuration is required" needs_a_configuration
check "an unknown option is refused" rejects_unknown_options
check "the Info.plist template asks for no permission" template_has_no_usage_descriptions
check "the Info.plist template makes an accessory app (LSUIElement)" template_is_an_accessory_app

if ((failures > 0)); then
    print_colored "$COLOR_RED" "${failures} make-app test(s) failed."
    exit 1
fi
print_colored "$COLOR_GREEN" "All make-app tests passed."
