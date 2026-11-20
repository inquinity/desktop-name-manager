#!/usr/bin/env bash
#
# Assemble "Desktop Name Manager.app" from a finished build (spec 014, contracts/app-bundle.md). It copies the app and
# dnm (which keeps working on its own from inside the bundle), fills in Info.plist from Version.xcconfig, makes the
# icon, and adds the license files of the shipped components. It builds nothing: run `just build` (or
# `just build-release`) first, or use `just app`.
#
# Usage: scripts/make-app.sh [--dev] [--output DIR] [--dry-run] [--help] <debug|release>
#   --dev          use the development bundle ID (…desktop-name-manager.dev) and sign ad hoc, for running locally
#   --output DIR   where to put the bundle (default: build.noindex/app; an existing bundle there is replaced)
#   --dry-run, -n  print the bundle's layout and what would be done, without writing anything
# Release signing, notarization and packaging belong to the release procedure (spec 005), not to this script.

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

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_name="Desktop Name Manager"
release_bundle_id="com.altmansoftwaredesign.desktop-name-manager"
output_directory="${repository_root}/build.noindex/app"
configuration=""
development=false
dry_run=false

usage() {
    print_colored "$COLOR_YELLOW" "Usage: scripts/make-app.sh [--dev] [--output DIR] [--dry-run] [--help] <debug|release>"
    print_colored "$COLOR_YELLOW" "  debug|release  which build to package (build.noindex/<configuration>/)"
    print_colored "$COLOR_YELLOW" "  --dev          development bundle ID (.dev) and an ad-hoc signature, for running locally"
    print_colored "$COLOR_YELLOW" "  --output DIR   where to put the bundle (default: build.noindex/app)"
    print_colored "$COLOR_YELLOW" "  --dry-run, -n  print the layout and the steps without writing anything"
    print_colored "$COLOR_YELLOW" "Assembles \"${app_name}.app\" from an existing build; it builds nothing."
}

while (($# > 0)); do
    case "$1" in
        --dev) development=true; shift ;;
        --output)
            [[ $# -ge 2 ]] || { print_colored "$COLOR_RED" "--output needs a directory."; exit 2; }
            output_directory="$2"; shift 2 ;;
        -n|--dry-run) dry_run=true; shift ;;
        -h|--help) usage; exit 0 ;;
        debug|release)
            [[ -z "$configuration" ]] || { print_colored "$COLOR_RED" "Give one configuration, not two."; exit 2; }
            configuration="$1"; shift ;;
        *) print_colored "$COLOR_RED" "Unknown argument: $1"; usage; exit 2 ;;
    esac
done

if [[ -z "$configuration" ]]; then
    print_colored "$COLOR_RED" "Say which build to package: debug or release."
    usage
    exit 2
fi

build_directory="${repository_root}/build.noindex/${configuration}"
resources_source="${repository_root}/Resources/App"
bundle="${output_directory}/${app_name}.app"
contents="${bundle}/Contents"
bundle_id="$release_bundle_id"
"$development" && bundle_id="${release_bundle_id}.dev"
version="$("${repository_root}/scripts/ver")"
build_number="$("${repository_root}/scripts/build-num")"

# The license files of the components compiled into the binaries, as the release download carries them.
license_files=()
while IFS= read -r license_file; do
    [[ -n "$license_file" ]] && license_files+=("$license_file")
done < <("${repository_root}/scripts/make-acknowledgements.sh" --binary-license-files)

# Every path in the bundle, relative to Contents/ (contracts/app-bundle.md). The dry run prints exactly this list.
bundle_layout() {
    printf '%s\n' "Info.plist" "PkgInfo" "MacOS/DesktopNameManager" "Helpers/dnm" "Resources/AppIcon.icns" \
        "Resources/Licenses/LICENSE.txt"
    local license_file
    for license_file in "${license_files[@]}"; do
        printf 'Resources/Licenses/%s\n' "$(basename "$license_file")"
    done
}

require_file() {
    local path=$1
    local hint=$2
    if [[ ! -f "$path" ]]; then
        print_colored "$COLOR_RED" "Missing: ${path#"${repository_root}/"}. ${hint}"
        exit 1
    fi
}

# Check every input before writing anything, so a failed run leaves no half-made bundle. A dry run only reports
# missing executables, so the layout can be checked before anything is built.
for executable in DesktopNameManager dnm; do
    if "$dry_run" && [[ ! -f "${build_directory}/${executable}" ]]; then
        print_colored "$COLOR_RED" "Not built yet: build.noindex/${configuration}/${executable} (a real run would stop here)."
    else
        require_file "${build_directory}/${executable}" "Build first: just build (or just build-release)."
    fi
done
require_file "${resources_source}/Info.plist" "The Info.plist template is part of the repository."
require_file "${repository_root}/LICENSE" "The project license is part of the repository."
for license_file in "${license_files[@]}"; do
    require_file "${repository_root}/${license_file}" "Listed by scripts/make-acknowledgements.sh."
done
if [[ ! -d "${resources_source}/AppIcon.iconset" ]]; then
    print_colored "$COLOR_RED" "Missing: Resources/App/AppIcon.iconset."
    exit 1
fi

if "$dry_run"; then
    print_colored "$COLOR_BRIGHTYELLOW" "Dry run: would assemble ${bundle#"${repository_root}/"}"
    printf 'bundle id: %s\nversion: %s (%s)\nsigning: %s\n' "$bundle_id" "$version" "$build_number" \
        "$("$development" && printf 'ad hoc' || printf 'none (the release procedure signs)')"
    print_colored "$COLOR_YELLOW" "Contents/:"
    bundle_layout
    exit 0
fi

work_directory="$(mktemp -d "${TMPDIR:-/tmp}/make-app.XXXXXX")"
cleanup() { rm -rf "$work_directory"; }
trap cleanup EXIT

staged="${work_directory}/${app_name}.app/Contents"
mkdir -p "${staged}/MacOS" "${staged}/Helpers" "${staged}/Resources/Licenses"

cp "${build_directory}/DesktopNameManager" "${staged}/MacOS/DesktopNameManager"
cp "${build_directory}/dnm" "${staged}/Helpers/dnm"
sed -e "s/@VERSION@/${version}/g" -e "s/@BUILD@/${build_number}/g" -e "s/@BUNDLE_ID@/${bundle_id}/g" \
    "${resources_source}/Info.plist" >"${staged}/Info.plist"
plutil -lint -s "${staged}/Info.plist"
printf 'APPL????' >"${staged}/PkgInfo"
iconutil -c icns "${resources_source}/AppIcon.iconset" -o "${staged}/Resources/AppIcon.icns"
cp "${repository_root}/LICENSE" "${staged}/Resources/Licenses/LICENSE.txt"
for license_file in "${license_files[@]}"; do
    cp "${repository_root}/${license_file}" "${staged}/Resources/Licenses/"
done

if "$development"; then
    # Nested code first, then the bundle; no --deep (it hides what is signed).
    codesign --force --sign - --timestamp=none "${staged}/Helpers/dnm"
    codesign --force --sign - --timestamp=none "${work_directory}/${app_name}.app"
fi

mkdir -p "$output_directory"
rm -rf "$bundle"
mv "${work_directory}/${app_name}.app" "$bundle"
print_colored "$COLOR_GREEN" "Assembled ${bundle#"${repository_root}/"} (${bundle_id}, ${version} build ${build_number})."
