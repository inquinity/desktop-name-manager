#!/usr/bin/env bash
#
# Run a local CodeQL scan of the Swift code and print a short summary of the findings.
#
# Needs the CodeQL CLI (brew install codeql) and a checkout of the CodeQL query repository
# (github.com/github/codeql) found through the CODEQL_REPO environment variable, checked out at
# the release tag recorded in scripts/codeql-queries-tag.txt. This script never downloads anything.
# Results go to the untracked .codeql/ folder; record the versions and findings in
# specs/001-labels-and-cli/review-notes.md.
#
# Usage: scripts/codeql-local.sh [--suite NAME] [--dry-run] [--help]

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
    printf "${color}${message}${COLOR_RESET}\n"
}

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
results_directory="${repository_root}/.codeql"
pinned_tag_file="${repository_root}/scripts/codeql-queries-tag.txt"
suite_name="swift-security-and-quality"
dry_run=false

usage() {
    print_colored "$COLOR_YELLOW" "Usage: scripts/codeql-local.sh [--suite NAME] [--dry-run] [--help]"
    print_colored "$COLOR_YELLOW" "  --suite NAME   query suite (default: ${suite_name}; also swift-code-scanning)"
    print_colored "$COLOR_YELLOW" "  --dry-run, -n  print the commands without running them"
    print_colored "$COLOR_YELLOW" "Environment: CODEQL_REPO = path to a github/codeql checkout at the pinned release tag."
    print_colored "$COLOR_YELLOW" "Pinned tag: ${pinned_tag_file}"
}

while (($# > 0)); do
    case "$1" in
        --suite) suite_name="${2:?--suite needs a name}"; shift 2 ;;
        -n|--dry-run) dry_run=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print_colored "$COLOR_RED" "Unknown option: $1"; usage; exit 2 ;;
    esac
done

command -v codeql >/dev/null 2>&1 || { print_colored "$COLOR_RED" "codeql is not installed. Install it with: brew install codeql"; exit 1; }
[[ -n "${CODEQL_REPO:-}" && -d "${CODEQL_REPO}/swift" ]] || {
    print_colored "$COLOR_RED" "Set CODEQL_REPO to a checkout of github.com/github/codeql (it must contain a swift/ folder)."
    exit 1
}
[[ -f "$pinned_tag_file" ]] || {
    print_colored "$COLOR_RED" "No pinned query tag. Record the release tag you have reviewed in ${pinned_tag_file}."
    exit 1
}

pinned_tag="$(tr -d '[:space:]' <"$pinned_tag_file")"
checked_out_tag="$(git -C "$CODEQL_REPO" describe --tags --exact-match 2>/dev/null || true)"
if [[ "$checked_out_tag" != "$pinned_tag" ]]; then
    print_colored "$COLOR_RED" "The query repository is at '${checked_out_tag:-no tag}', not the pinned tag '${pinned_tag}'."
    print_colored "$COLOR_RED" "Check out the pinned tag (git -C \"\$CODEQL_REPO\" checkout ${pinned_tag}) or update the pin after reviewing the new queries."
    exit 1
fi

suite_file="${CODEQL_REPO}/swift/ql/src/codeql-suites/${suite_name}.qls"
[[ -f "$suite_file" ]] || { print_colored "$COLOR_RED" "No such suite: ${suite_file}"; exit 1; }

database_directory="${results_directory}/database"
results_file="${results_directory}/results.sarif"

print_colored "$COLOR_BRIGHTYELLOW" "CodeQL $(codeql version --format=terse), queries ${pinned_tag}, suite ${suite_name}"

run_step() {
    if "$dry_run"; then
        print_colored "$COLOR_CYAN" "[dry run] $*"
    else
        "$@"
    fi
}

run_step mkdir -p "$results_directory"
# The build is traced so CodeQL sees the compiler calls. A clean build makes it see every file.
run_step swift package clean
run_step codeql database create "$database_directory" --language=swift --source-root="$repository_root" \
    --command="swift build" --overwrite
run_step codeql database analyze "$database_directory" "$suite_file" --search-path="$CODEQL_REPO" --no-download \
    --format=sarif-latest --output="$results_file"

if "$dry_run"; then
    exit 0
fi

finding_count="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(sum(len(r.get("results",[])) for r in d.get("runs",[])))' "$results_file")"
print_colored "$COLOR_BRIGHTYELLOW" "Results: ${results_file}"
if ((finding_count == 0)); then
    print_colored "$COLOR_GREEN" "CodeQL reported no findings."
else
    print_colored "$COLOR_RED" "CodeQL reported ${finding_count} finding(s). Triage them and record the outcome in review-notes.md."
    python3 -c '
import json, sys
data = json.load(open(sys.argv[1]))
for run in data.get("runs", []):
    for result in run.get("results", []):
        location = result["locations"][0]["physicalLocation"] if result.get("locations") else {}
        path = location.get("artifactLocation", {}).get("uri", "?")
        line = location.get("region", {}).get("startLine", "?")
        print("  {}  {}:{}  {}".format(result.get("ruleId", "?"), path, line, result["message"]["text"].splitlines()[0]))
' "$results_file"
    exit 1
fi
