#!/usr/bin/env bash
#
# Build Acknowledgements.md: each open-source component in the dnm binary or in this source repository,
# the version that ships and the license it is used under, linked to that license at that version (the
# same process as the sibling project's bin/make-acknowledgements.sh; constitution 2.1.0).
#
# It does not reproduce the license texts. They are kept in Licenses/, and the release download includes
# those of the components in the binary: that is what meets the MIT and Apache requirement that the
# notice travel with every copy. A link alone would not: the file it points to can change or disappear.
#
# Rerun it whenever a component is added, removed, upgraded or relicensed. It refuses to run while a file
# in Licenses/ is unaccounted for, a license is named without an https link, a pinned link names a version
# other than the one that ships, or `dnm about` does not name a binary component at that version.
# AcknowledgementsTests runs its --check, so a stale page fails the tests.
#
# Usage: scripts/make-acknowledgements.sh [--dry-run] [--check] [--help]
# Requires bash (not POSIX sh); written for the bash 3.2 that ships with macOS.

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
OUTPUT_PATH="Acknowledgements.md"
ABOUT_SOURCE="Sources/DesktopNameCore/Operations/About.swift"

# One entry per component, in reading order:
#   "<component>|<binary or source>|<where, as Markdown, or empty>|<license, as Markdown>|<license files, comma-separated>|<version source>"
#
# <version source> says where the shipped version is read:
#   resolved:<identity>  the pin's version in Package.resolved (committed, so this is automatic);
#   <file>               the first x.y.z in that file's first 400 bytes.
# The license link must name that version, so an upgrade cannot leave the link behind. "binary" entries
# must also be named, with their version, by `dnm about` (About.acknowledgements).
ENTRIES=(
    "swift-argument-parser|binary||[Apache License 2.0 with Runtime Library Exception](https://github.com/apple/swift-argument-parser/blob/1.8.2/LICENSE.txt)|Licenses/swift-argument-parser-LICENSE.txt|resolved:swift-argument-parser"
    "Spec Kit|source|the files in \`.specify/\` and \`.claude/skills/speckit-*\`|[MIT License](https://github.com/github/spec-kit/blob/v1.0.12/LICENSE)|Licenses/spec-kit-LICENSE.txt|.specify/init-options.json"
)

mode="write"
scratch_file=""
# Fields of the entry split_entry last read.
entry_component=""
entry_scope=""
entry_where=""
entry_license=""
entry_paths=""
entry_version_source=""

usage() {
    printf '%b\n' "${COLOR_YELLOW}Usage: scripts/make-acknowledgements.sh [options]${COLOR_RESET}"
    printf '\n'
    printf '%s\n' "Write $OUTPUT_PATH: each component, the version that ships and the license it is used under."
    printf '\n'
    printf '%b\n' "${COLOR_YELLOW}Options:${COLOR_RESET}"
    printf '%s\n' '  -h, --help      Show this help text.'
    printf '%s\n' '  -n, --dry-run   Print the file to stdout instead of writing it.'
    printf '%s\n' '      --check     Write nothing; exit 1 if the committed file is out of date.'
}

die() {
    print_colored "$COLOR_RED" "Error: $1"
    exit 1
}

cleanup() {
    [[ -n "$scratch_file" ]] && rm -f "$scratch_file"
    return 0
}

split_entry() {
    IFS='|' read -r entry_component entry_scope entry_where entry_license entry_paths entry_version_source <<<"$1"
}

# One license path per line. The final newline matters: `read` returns non-zero on an unterminated last
# line, and a loop over it would silently skip the last path.
paths_of_entry() { printf '%s\n' "$entry_paths" | tr ',' '\n'; }

# Link targets in the license Markdown, one per line.
link_targets() { printf '%s\n' "$entry_license" | grep -oE '\]\([^)]*\)' | sed -E 's/^\]\((.*)\)$/\1/' || true; }

is_listed() {
    local wanted_path=$1 entry listed_paths
    for entry in "${ENTRIES[@]}"; do
        split_entry "$entry"
        # Captured first: piping straight into `grep -q` under pipefail can report a match as a failure if
        # grep exits before the writer is done.
        listed_paths="$(paths_of_entry)"
        grep -qxF "$wanted_path" <<<"$listed_paths" && return 0
    done
    return 1
}

# The version that ships, from the entry's version source.
shipped_version() {
    local source=$entry_version_source identity
    if [[ "$source" == resolved:* ]]; then
        identity="${source#resolved:}"
        # Package.resolved is JSON; the pin's "version" follows its "identity".
        awk -v identity="\"$identity\"" '
            $0 ~ "\"identity\"" && index($0, identity) { found = 1 }
            found && /"version"/ { gsub(/[^0-9.]/, ""); print; exit }
        ' "$PROJECT_ROOT/Package.resolved"
    else
        [[ -f "$PROJECT_ROOT/$source" ]] || die "$entry_component: version source $source does not exist."
        head -c 400 "$PROJECT_ROOT/$source" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true
    fi
}

# Every listed license file must exist, every file in Licenses/ must be listed, every link must be a
# complete https link, a pinned link must name the version that ships, and dnm about must name every
# binary component at that version.
validate_sources() {
    local entry license_path candidate_path link_target targets opened_links closed_links version about_text
    about_text="$(cat "$PROJECT_ROOT/$ABOUT_SOURCE")"
    for entry in "${ENTRIES[@]}"; do
        split_entry "$entry"
        [[ "$entry_scope" == "binary" || "$entry_scope" == "source" ]] \
            || die "$entry_component: the scope must be binary or source, not \"$entry_scope\"."
        while IFS= read -r license_path; do
            [[ -f "$PROJECT_ROOT/$license_path" ]] || die "$license_path is listed but does not exist."
        done < <(paths_of_entry)

        targets="$(link_targets)"
        # `|| true`: no "](" at all is reported by the check below, not by set -e.
        opened_links="$({ grep -o '](' <<<"$entry_license" || true; } | wc -l | tr -d ' ')"
        closed_links="$(grep -c . <<<"$targets" || true)"
        [[ "$opened_links" -gt 0 ]] || die "$entry_component names its license without linking to it."
        [[ "$opened_links" -eq "$closed_links" ]] || die "$entry_component has a link that is never closed."
        while IFS= read -r link_target; do
            [[ "$link_target" == https://* ]] \
                || die "$entry_component links to \"$link_target\"; use a full https URL."
        done <<<"$targets"

        version="$(shipped_version)"
        [[ -n "$version" ]] || die "$entry_component: no x.y.z version found from $entry_version_source."
        [[ "$entry_license" == *"$version"* ]] \
            || die "$entry_component ships $version, but its license link names another version."
        if [[ "$entry_scope" == "binary" ]]; then
            grep -qF "\"$entry_component\", version: \"$version\"" <<<"$about_text" \
                || die "$entry_component $version is in the binary, but $ABOUT_SOURCE does not name it at that version."
        fi
    done
    for candidate_path in "$PROJECT_ROOT"/Licenses/*; do
        [[ -f "$candidate_path" ]] || continue
        is_listed "${candidate_path#"$PROJECT_ROOT"/}" \
            || die "${candidate_path#"$PROJECT_ROOT"/} is not listed in ENTRIES."
    done
}

render_scope() {
    local scope=$1 entry where
    for entry in "${ENTRIES[@]}"; do
        split_entry "$entry"
        [[ "$entry_scope" == "$scope" ]] || continue
        where=""
        [[ -n "$entry_where" ]] && where=" ($entry_where)"
        printf -- '- **%s** %s%s is used under the %s.\n' "$entry_component" "$(shipped_version)" "$where" "$entry_license"
    done
}

render() {
    printf '# Acknowledgements\n\n'
    printf 'Desktop Name Manager includes the open-source software below. Generated by\n'
    # shellcheck disable=SC2016  # the backticks are Markdown code, not a substitution
    printf '`scripts/make-acknowledgements.sh`; do not edit by hand.\n\n'
    # shellcheck disable=SC2016
    printf '## In the `dnm` binary\n\n'
    render_scope binary
    printf '\n## In this source repository\n\n'
    render_scope source
    # shellcheck disable=SC2016
    printf '\nThe full text of each license is in `Licenses/`. The release download includes the license files of\n'
    printf 'the components in the binary.\n'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -n|--dry-run) mode="print" ;;
        --check) mode="check" ;;
        *) print_colored "$COLOR_RED" "Unknown option: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

validate_sources

case "$mode" in
    print)
        render
        ;;
    check)
        scratch_file="$(mktemp "${TMPDIR:-/tmp}/acknowledgements.XXXXXX")"
        trap cleanup EXIT
        render >"$scratch_file"
        if ! cmp -s "$scratch_file" "$PROJECT_ROOT/$OUTPUT_PATH"; then
            print_colored "$COLOR_RED" "$OUTPUT_PATH is out of date: run scripts/make-acknowledgements.sh"
            exit 1
        fi
        print_colored "$COLOR_GREEN" "$OUTPUT_PATH is up to date."
        ;;
    write)
        render >"$PROJECT_ROOT/$OUTPUT_PATH"
        print_colored "$COLOR_GREEN" "Wrote $OUTPUT_PATH."
        ;;
esac
