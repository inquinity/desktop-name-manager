#!/usr/bin/env bash
#
# The release procedure for the dnm command-line tool (spec 005, contracts/release-procedure.md).
# Runs on the maintainer's Mac, one stage at a time:
#
#   check -> build -> notarize -> verify -> draft -> publish -> cask -> record
#
# Nothing is published, pushed or changed in the tap unless that stage is run with --confirm. Credentials
# come only from the environment (DNM_SIGNING_IDENTITY, DNM_NOTARY_PROFILE) and are never printed.
#
# Usage: scripts/release.sh <version> <stage> [--dry-run] [--confirm] [--tap DIR] [--help]

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
release_repository="inquinity/desktop-name-manager"
temporary_tap="dnmrelease/check"
stages="check build notarize verify draft publish cask record"

version=""
stage=""
dry_run=false
confirmed=false
tap_directory=""
temporary_directory=""
unmet_gates=0

usage() {
    print_colored "$COLOR_YELLOW" "Usage: scripts/release.sh <version> <stage> [--dry-run] [--confirm] [--tap DIR] [--help]"
    print_colored "$COLOR_YELLOW" "Stages, in order: ${stages}"
    print_colored "$COLOR_YELLOW" "  check     the gates (clean tree, signed tag on HEAD, version, tests, Periphery, live checks, reviews)"
    print_colored "$COLOR_YELLOW" "  build     release build, binary checks, signing, zip and SHA-256"
    print_colored "$COLOR_YELLOW" "  notarize  submit the zip to Apple and wait (up to 30 minutes)"
    print_colored "$COLOR_YELLOW" "  verify    run a quarantined copy as a user's Mac would; compare the checksum"
    print_colored "$COLOR_YELLOW" "  draft     create a draft GitHub release (needs --confirm)"
    print_colored "$COLOR_YELLOW" "  publish   make the draft public (needs --confirm)"
    print_colored "$COLOR_YELLOW" "  cask      test the cask in a temporary local tap, write it into --tap DIR (needs --confirm); never pushes"
    print_colored "$COLOR_YELLOW" "  record    append the procedure log to the gate record"
    print_colored "$COLOR_YELLOW" "  --dry-run  with check or build: list every unmet gate, sign ad hoc if no identity is set, send nothing"
    print_colored "$COLOR_YELLOW" "Environment: DNM_SIGNING_IDENTITY (build), DNM_NOTARY_PROFILE (notarize). Their values are never printed."
}

die() {
    print_colored "$COLOR_RED" "release: $1" >&2
    exit "${2:-1}"
}

cleanup() {
    if [[ -n "$temporary_directory" && -d "$temporary_directory" ]]; then
        rm -rf "$temporary_directory"
    fi
}

# --- Arguments -------------------------------------------------------------------------------------

while (($# > 0)); do
    case "$1" in
        --dry-run) dry_run=true; shift ;;
        --confirm) confirmed=true; shift ;;
        --tap) tap_directory="${2:?--tap needs a folder}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -*) print_colored "$COLOR_RED" "Unknown option: $1"; usage; exit 2 ;;
        *)
            if [[ -z "$version" ]]; then version="$1"
            elif [[ -z "$stage" ]]; then stage="$1"
            else print_colored "$COLOR_RED" "Unexpected argument: $1"; usage; exit 2
            fi
            shift ;;
    esac
done

[[ -n "$version" && -n "$stage" ]] || { usage; exit 2; }
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "the version must look like 1.2.3, not \"${version}\"" 2
[[ " ${stages} " == *" ${stage} "* ]] || die "unknown stage \"${stage}\"; stages: ${stages}" 2

tag="v${version}"
artifact_directory="${repository_root}/build.noindex/release-artifacts/${version}"
zip_name="dnm-${version}-arm64.zip"
zip_path="${artifact_directory}/${zip_name}"
gate_record="${repository_root}/specs/005-packaging-and-release/releases/${version}.md"
procedure_log="${artifact_directory}/procedure-log.md"
dry_run_note=""
if "$dry_run"; then
    # Dry-run results never reach the gate record.
    procedure_log="${artifact_directory}/dry-run-log.md"
    dry_run_note=" (dry run)"
fi

cd "$repository_root"
mkdir -p "$artifact_directory"
temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/dnm-release.XXXXXX")"
trap cleanup EXIT

[[ -f "$gate_record" ]] || die "no gate record for ${version}: create ${gate_record#"${repository_root}"/} first"

# --- Helpers ---------------------------------------------------------------------------------------

# Results go to a log in the build folder: writing the tracked gate record would dirty the tree, and the
# release build refuses a dirty tree. The record stage copies the log into the gate record at the end.
log_result() {
    local line
    line="- $(date -u +%Y-%m-%dT%H:%M:%SZ) ${stage}${dry_run_note}: $1"
    printf "%s\n" "$line" >>"$procedure_log"
    print_colored "$COLOR_GREEN" "$1"
}

require_command() {
    command -v "$1" >/dev/null || die "the command \"$1\" is needed for ${stage}"
}

require_confirmation() {
    # require_confirmation <what would happen>
    if ! "$confirmed"; then
        print_colored "$COLOR_YELLOW" "${stage} would: $1"
        die "${stage} changes something outside this Mac; run it again with --confirm"
    fi
}

require_file() {
    [[ -f "$1" ]] || die "${1#"${repository_root}"/} is missing: run the $2 stage first"
}

recorded_sha256() {
    require_file "${zip_path}.sha256" build
    awk '{print $1}' "${zip_path}.sha256"
}

# gate <description> <command...>: a gate that must pass. Under --dry-run, unmet gates are counted and
# listed instead of stopping at the first.
gate() {
    local description=$1
    shift
    if "$@"; then
        print_colored "$COLOR_GREEN" "PASS  ${description}"
    elif "$dry_run"; then
        print_colored "$COLOR_RED" "UNMET ${description}"
        unmet_gates=$((unmet_gates + 1))
    else
        die "gate not met: ${description}"
    fi
}

tree_is_clean() { [[ -z "$(git status --porcelain)" ]]; }

tag_is_signed_on_head() {
    git rev-parse -q --verify "refs/tags/${tag}" >/dev/null || return 1
    [[ "$(git cat-file -t "$tag")" == "tag" ]] || return 1
    [[ "$(git rev-list -n 1 "$tag")" == "$(git rev-parse HEAD)" ]] || return 1
    git cat-file tag "$tag" | grep -qE "BEGIN (SSH|PGP) SIGNATURE"
}

source_version() {
    sed -n 's/.*public static let version = "\([0-9.]*\)".*/\1/p' Sources/DesktopNameCore/DesktopNameCore.swift
}

version_matches_source() { [[ "$(source_version)" == "$version" ]]; }

version_is_unreleased() { ! gh release view "$tag" --repo "$release_repository" >/dev/null 2>&1; }

tests_pass() { just test >"${temporary_directory}/test.log" 2>&1; }

periphery_is_clean() { just periphery >"${temporary_directory}/periphery.log" 2>&1; }

live_checks_recorded() {
    local notes="specs/001-labels-and-cli/review-notes.md"
    grep -qE '^### Live run.*macOS 26' "$notes" && grep -qE '^### Live run.*macOS 27' "$notes"
}

maintainer_gates_checked() {
    # Every checkbox under "## Maintainer gates" in the gate record is ticked.
    ! awk '/^## Maintainer gates/{inside=1; next} /^## /{inside=0} inside' "$gate_record" | grep -q '^- \[ \]'
}

signing_identity_usable() {
    [[ -n "${DNM_SIGNING_IDENTITY:-}" ]] || return 1
    security find-identity -v -p codesigning 2>/dev/null | grep -qF "$DNM_SIGNING_IDENTITY"
}

notary_profile_usable() {
    [[ -n "${DNM_NOTARY_PROFILE:-}" ]] || return 1
    xcrun notarytool history --keychain-profile "$DNM_NOTARY_PROFILE" >/dev/null 2>&1
}

# Text between a "## <heading>" line and the next "## " heading of the gate record.
gate_record_section() {
    awk -v heading="## $1" '$0 == heading {inside=1; next} /^## /{inside=0} inside' "$gate_record" | sed '/./,$!d'
}

# --- Stages ----------------------------------------------------------------------------------------

stage_check() {
    require_command gh
    require_command just
    gate "the working tree is clean" tree_is_clean
    gate "${tag} is a signed, annotated tag on HEAD" tag_is_signed_on_head
    gate "${version} is the version in DesktopNameCoreInfo (found $(source_version))" version_matches_source
    if "$dry_run"; then
        print_colored "$COLOR_YELLOW" "SKIP  no GitHub release ${tag} yet (dry run: not asked)"
    else
        gate "no GitHub release ${tag} exists yet" version_is_unreleased
    fi
    gate "live checks are recorded for macOS 26 and macOS 27" live_checks_recorded
    gate "every maintainer gate in ${gate_record#"${repository_root}"/} is checked" maintainer_gates_checked
    gate "just test passes" tests_pass
    gate "just periphery finds no unused code" periphery_is_clean
    if "$dry_run" && ((unmet_gates > 0)); then
        print_colored "$COLOR_RED" "${unmet_gates} gate(s) unmet."
        exit 1
    fi
    log_result "all gates met for ${version} at $(git rev-parse --short HEAD)"
}

stage_build() {
    require_command codesign
    require_command ditto
    local signing_identity="-"
    if signing_identity_usable; then
        signing_identity="$DNM_SIGNING_IDENTITY"
    elif "$dry_run"; then
        print_colored "$COLOR_YELLOW" "No usable DNM_SIGNING_IDENTITY: signing ad hoc for the dry run."
    else
        die "DNM_SIGNING_IDENTITY is not set or not a code-signing identity in the keychain"
    fi

    # A release stamp needs a clean tree; a dry run on a dirty tree builds an interim stamp instead.
    local stamp_option="--release" expected_version="$version"
    if "$dry_run" && ! tree_is_clean; then
        stamp_option=""
        expected_version=""
        print_colored "$COLOR_YELLOW" "Dirty tree: building with an interim stamp for the dry run."
    fi
    local stamp_flags=() stamp_flag
    while IFS= read -r stamp_flag; do
        stamp_flags+=("$stamp_flag")
    done < <(scripts/build-stamp.sh ${stamp_option:+"$stamp_option"})

    print_colored "$COLOR_BRIGHTYELLOW" "Building dnm ${version} for arm64..."
    local build_arguments=(-c release --arch arm64 --product dnm --scratch-path build.noindex --force-resolved-versions)
    swift build "${build_arguments[@]}" "${stamp_flags[@]}"
    local built_binary
    built_binary="$(swift build "${build_arguments[@]}" --show-bin-path)/dnm"
    [[ -x "$built_binary" ]] || die "the build produced no binary at ${built_binary}"

    local payload="${artifact_directory}/payload"
    rm -rf "$payload"
    mkdir -p "$payload"
    cp "$built_binary" "${payload}/dnm"
    cp LICENSE "${payload}/LICENSE"
    local binary="${payload}/dnm"

    local reported_version
    reported_version="$("$binary" --version)"
    if [[ -n "$expected_version" && "$reported_version" != "$expected_version" ]]; then
        die "the release build reports ${reported_version}, not ${expected_version}"
    fi
    log_result "built dnm ${reported_version} for $(lipo -archs "$binary")"

    # Security plan S7: no build folder, home folder or user name inside the binary.
    local leaked=""
    for needle in "$repository_root" "$HOME" "$(id -un)"; do
        if strings -a "$binary" | grep -qF "$needle"; then leaked="yes"; fi
    done
    [[ -z "$leaked" ]] || die "the binary contains the build folder, the home folder or the user name"
    log_result "no build folder, home folder or user name in the binary"

    # Only system libraries, and none for networking or private frameworks (the linkage test's rules).
    local libraries
    libraries="$(otool -L "$binary" | tail -n +2 | awk '{print $1}')"
    if grep -vE '^(/usr/lib/|/System/Library/Frameworks/)' <<<"$libraries" | grep -q .; then
        die "the binary links a library outside /usr/lib and /System/Library/Frameworks"
    fi
    if grep -qE 'Network\.framework|CFNetwork|SkyLight|WebKit|SystemConfiguration|NetworkExtension|MultipeerConnectivity|libcurl|PrivateFrameworks' <<<"$libraries"; then
        die "the binary links a networking or private framework"
    fi
    log_result "links only allowed system libraries ($(wc -l <<<"$libraries" | tr -d ' '))"

    # Hardened runtime, no entitlements. A secure timestamp needs a real identity (and the network).
    local timestamp_option="--timestamp"
    [[ "$signing_identity" == "-" ]] && timestamp_option="--timestamp=none"
    codesign --force --sign "$signing_identity" --options runtime "$timestamp_option" \
        --identifier com.altmansoftwaredesign.dnm "$binary"
    codesign --verify --strict --verbose=2 "$binary"
    if [[ "$signing_identity" != "-" ]]; then
        local details
        details="$(codesign -dvv "$binary" 2>&1)"
        grep -q "Authority=Developer ID Application" <<<"$details" || die "the signature is not a Developer ID Application signature"
        grep -qE "flags=.*runtime" <<<"$details" || die "the signature lacks the hardened runtime"
        log_result "signed with a Developer ID Application identity, hardened runtime, timestamp, no entitlements"
    else
        log_result "signed ad hoc (dry run)"
    fi

    rm -f "$zip_path" "${zip_path}.sha256"
    # The signature is embedded in the binary, so extended attributes (which ditto would store as "._" files)
    # are left out.
    ditto -c -k --norsrc --noextattr --noqtn "$payload" "$zip_path"
    local contents
    contents="$(zipinfo -1 "$zip_path" | sort | tr '\n' ' ')"
    [[ "$contents" == "LICENSE dnm " ]] || die "the zip holds \"${contents}\", not exactly dnm and LICENSE"
    (cd "$artifact_directory" && shasum -a 256 "$zip_name" >"${zip_name}.sha256")
    log_result "${zip_name}: SHA-256 $(recorded_sha256)"
}

stage_notarize() {
    require_file "$zip_path" build
    notary_profile_usable || die "DNM_NOTARY_PROFILE is not set or cannot authenticate with notarytool"
    print_colored "$COLOR_BRIGHTYELLOW" "Submitting ${zip_name} to Apple's notary service (waiting up to 30 minutes)..."
    local result="${artifact_directory}/notarization.json"
    xcrun notarytool submit "$zip_path" --keychain-profile "$DNM_NOTARY_PROFILE" --wait --timeout 30m \
        --output-format json >"$result" || true
    local status submission
    status="$(plutil -extract status raw -o - "$result" 2>/dev/null || printf 'unknown')"
    submission="$(plutil -extract id raw -o - "$result" 2>/dev/null || printf 'unknown')"
    if [[ "$status" != "Accepted" ]]; then
        if [[ "$submission" != "unknown" ]]; then
            xcrun notarytool log "$submission" --keychain-profile "$DNM_NOTARY_PROFILE" || true
        fi
        die "notarization ended with status \"${status}\" (submission ${submission})"
    fi
    log_result "notarized: status Accepted, submission ${submission}"
}

stage_verify() {
    require_file "$zip_path" build
    require_file "${artifact_directory}/notarization.json" notarize
    (cd "$artifact_directory" && shasum -a 256 -c "${zip_name}.sha256" >/dev/null) || die "the zip no longer matches its SHA-256"
    local unpacked="${temporary_directory}/unpacked"
    ditto -x -k "$zip_path" "$unpacked"
    local binary="${unpacked}/dnm"
    # Mark it as downloaded, as a browser or Homebrew would, so macOS performs its first-run check.
    xattr -w com.apple.quarantine "0081;$(printf '%x' "$(date +%s)");dnm-release;" "$binary"
    local reported
    reported="$("$binary" --version)" || die "macOS refused to run the quarantined binary"
    [[ "$reported" == "$version" ]] || die "the downloaded binary reports ${reported}, not ${version}"
    log_result "a quarantined copy ran and reported ${reported} (macOS's first-run check passed)"
    if command -v syspolicy_check >/dev/null; then
        syspolicy_check distribution "$binary" >"${temporary_directory}/syspolicy.log" 2>&1 \
            || die "syspolicy_check distribution rejected the binary: $(tail -n 3 "${temporary_directory}/syspolicy.log")"
        log_result "syspolicy_check distribution: no issues"
    fi
    log_result "checksum matches: $(recorded_sha256)"
}

render_release_notes() {
    local notes="${artifact_directory}/release-notes.md" sha
    sha="$(recorded_sha256)"
    local changes gaps toolchain commit
    changes="$(gate_record_section "Changes")"
    gaps="$(gate_record_section "Known gaps")"
    toolchain="$(swift --version 2>&1 | head -n 1)"
    commit="$(git rev-parse --short "$tag")"
    CHANGES="$changes" KNOWN_GAPS="$gaps" TOOLCHAIN="$toolchain" COMMIT="$commit" SHA="$sha" VERSION="$version" \
        perl -0pe 's/\@CHANGES\@/$ENV{CHANGES}/g; s/\@KNOWN_GAPS\@/$ENV{KNOWN_GAPS}/g; s/\@TOOLCHAIN\@/$ENV{TOOLCHAIN}/g;
                   s/\@COMMIT\@/$ENV{COMMIT}/g; s/\@SHA256\@/$ENV{SHA}/g; s/\@VERSION\@/$ENV{VERSION}/g' \
        packaging/release-notes.md.template >"$notes"
    printf "%s" "$notes"
}

stage_draft() {
    require_confirmation "create a DRAFT release ${tag} on ${release_repository} with ${zip_name} and its .sha256 (not public)"
    require_command gh
    require_file "$zip_path" build
    grep -q "Accepted" "${artifact_directory}/notarization.json" 2>/dev/null || die "the zip is not notarized: run notarize and verify first"
    grep -q " verify: " "$procedure_log" 2>/dev/null || die "the download was not verified: run verify first"
    local notes
    notes="$(render_release_notes)"
    gh release create "$tag" "$zip_path" "${zip_path}.sha256" --repo "$release_repository" --draft --verify-tag \
        --title "Desktop Name Manager ${version}" --notes-file "$notes"
    log_result "draft release ${tag} created"
}

stage_publish() {
    require_confirmation "check the draft ${tag}'s download against the recorded SHA-256, then make the release PUBLIC"
    require_command gh
    local is_draft
    is_draft="$(gh release view "$tag" --repo "$release_repository" --json isDraft -q .isDraft 2>/dev/null)" \
        || die "there is no release ${tag}: run draft first"
    [[ "$is_draft" == "true" ]] || die "${tag} is already published"
    local downloaded="${temporary_directory}/downloaded"
    gh release download "$tag" --repo "$release_repository" --pattern "$zip_name" --dir "$downloaded"
    [[ "$(shasum -a 256 "${downloaded}/${zip_name}" | awk '{print $1}')" == "$(recorded_sha256)" ]] \
        || die "the draft's ${zip_name} does not match the recorded SHA-256"
    gh release edit "$tag" --repo "$release_repository" --draft=false
    log_result "release ${tag} published"
}

render_cask() {
    local cask="${artifact_directory}/desktop-name-manager.rb" scope
    # The Accessibility note shown by dnm itself (security plan S1).
    scope="$(sed -n 's/.*public static let accessibilityScope = "\(.*\)"$/\1/p' Sources/DesktopNameCore/Operations/About.swift)"
    [[ -n "$scope" ]] || die "cannot read About.accessibilityScope for the cask caveats"
    SCOPE="$scope" SHA="$(recorded_sha256)" VERSION="$version" \
        perl -0pe 's/\@ACCESSIBILITY_SCOPE\@/$ENV{SCOPE}/g; s/\@SHA256\@/$ENV{SHA}/g; s/\@VERSION\@/$ENV{VERSION}/g' \
        packaging/desktop-name-manager.rb.template >"$cask"
    grep -q '^ *zap ' "$cask" && die "the cask must not have a zap stanza"
    printf "%s" "$cask"
}

remove_temporary_tap() {
    brew untap "$temporary_tap" >/dev/null 2>&1 || true
}

stage_cask() {
    require_confirmation "test the cask in a temporary local tap (${temporary_tap}), then write Casks/desktop-name-manager.rb into the tap clone given with --tap"
    require_command brew
    [[ -n "$tap_directory" && -d "${tap_directory}/Casks" ]] || die "--tap must name the local clone of the tap (a folder with Casks/)"
    local is_draft
    is_draft="$(gh release view "$tag" --repo "$release_repository" --json isDraft -q .isDraft 2>/dev/null || printf 'missing')"
    [[ "$is_draft" == "false" ]] || die "${tag} is not published yet: the cask must point at a public download"
    local cask
    cask="$(render_cask)"

    # FR-011: audit and test from a local copy before anything reaches the tap.
    remove_temporary_tap
    brew tap-new --no-git "$temporary_tap" >/dev/null
    trap 'remove_temporary_tap; cleanup' EXIT
    local local_tap
    local_tap="$(brew --repository "$temporary_tap")"
    mkdir -p "${local_tap}/Casks"
    cp "$cask" "${local_tap}/Casks/desktop-name-manager.rb"
    brew audit --cask --new --strict "${temporary_tap}/desktop-name-manager"
    log_result "brew audit --cask --new --strict passed"
    brew install --cask "${temporary_tap}/desktop-name-manager"
    local prefix main_version alias_version
    prefix="$(brew --prefix)"
    main_version="$("${prefix}/bin/dnm" --version)"
    alias_version="$("${prefix}/bin/desktop-name" --version)"
    brew uninstall --cask "${temporary_tap}/desktop-name-manager"
    [[ "$main_version" == "$version" && "$alias_version" == "$version" ]] \
        || die "after a local install, dnm reports ${main_version} and desktop-name ${alias_version}, not ${version}"
    [[ ! -e "${prefix}/bin/dnm" && ! -e "${prefix}/bin/desktop-name" ]] || die "uninstalling left dnm or desktop-name behind"
    log_result "local install, run (dnm and desktop-name report ${version}) and uninstall passed"
    remove_temporary_tap

    cp "$cask" "${tap_directory}/Casks/desktop-name-manager.rb"
    log_result "wrote Casks/desktop-name-manager.rb into the tap clone (not pushed)"
    print_colored "$COLOR_GREEN" "Review, then commit and push the tap yourself:"
    print_colored "$COLOR_GREEN" "  git -C '${tap_directory}' diff"
    print_colored "$COLOR_GREEN" "  git -C '${tap_directory}' add Casks/desktop-name-manager.rb"
    print_colored "$COLOR_GREEN" "  git -C '${tap_directory}' commit -m 'desktop-name-manager ${version}'"
    print_colored "$COLOR_GREEN" "  git -C '${tap_directory}' push"
}

stage_record() {
    [[ -s "$procedure_log" ]] || die "no procedure log yet for ${version}"
    cat "$procedure_log" >>"$gate_record"
    : >"$procedure_log"
    print_colored "$COLOR_GREEN" "Appended the procedure log to ${gate_record#"${repository_root}"/}; review and commit it."
}

# --- Main ------------------------------------------------------------------------------------------

if "$dry_run" && [[ "$stage" != "check" && "$stage" != "build" ]]; then
    print_colored "$COLOR_YELLOW" "Dry run: ${stage} would run after check and build; it sends something outside this Mac, so it is not run."
    exit 0
fi

print_colored "$COLOR_BRIGHTYELLOW" "Release ${version}: ${stage}${dry_run_note}"
"stage_${stage}"
