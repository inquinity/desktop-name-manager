# Build and test tasks. SwiftPM's own folder (.build) is not used for our builds: everything goes to
# build.noindex, which Spotlight and Time Machine skip. Requires `just` (brew install just).

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

scratch := "build.noindex"

# List the available tasks.
default:
    @just --list

# Debug build of the library and dnm. Every build moves the build number in Version.xcconfig forward and is
# stamped with it and its commit (see scripts/build-stamp.sh), so `dnm --version` shows exactly what you run.
build *args:
    stamp="$(scripts/build-stamp.sh --bump)"; flags=(); while IFS= read -r flag; do flags+=("$flag"); done <<<"$stamp"; \
    swift build --scratch-path {{ scratch }} --force-resolved-versions "${flags[@]}" {{ args }}

# Optimized build of dnm (build.noindex/release/dnm), with a new build number like `just build`.
build-release *args:
    stamp="$(scripts/build-stamp.sh --bump)"; flags=(); while IFS= read -r flag; do flags+=("$flag"); done <<<"$stamp"; \
    swift build -c release --scratch-path {{ scratch }} --force-resolved-versions "${flags[@]}" {{ args }}

# Unit and contract tests (they never change your real wallpaper). They keep the build number: the release
# check runs them on the tagged commit, which must stay clean. The version-script tests run in a throwaway
# repository afterwards.
test *args:
    stamp="$(scripts/build-stamp.sh)"; flags=(); while IFS= read -r flag; do flags+=("$flag"); done <<<"$stamp"; \
    swift test --scratch-path {{ scratch }} --force-resolved-versions "${flags[@]}" {{ args }}; \
    Tests/scripts/version-scripts-test.sh

# Unused-code scan (needs `brew install periphery`).
periphery:
    scripts/periphery.sh

# Assemble the live-test kit to copy to another Mac (dist/dnm-live-kit).
kit:
    scripts/make-live-kit.sh

# RESEARCH ONLY: watch how macOS ties Desktops to wallpapers (private, read-only calls; never shipped).
observe *args:
    mkdir -p {{ scratch }}/research
    swiftc -O -o {{ scratch }}/research/space-observer prototype/space-observer.swift
    {{ scratch }}/research/space-observer {{ args }}

# Print "<version> build <build number>" from Version.xcconfig.
version:
    @printf '%s build %s\n' "$(scripts/ver)" "$(scripts/build-num)"

# Start the next version by hand (seg: major|minor|revision). The release procedure already moves to the next
# revision after a release (`just publish record`); use this when the next version should be something else.
bump seg:
    scripts/bump-version.sh {{ seg }}

# Cut a release of the version in Version.xcconfig: give it a new build number, compose the notes, commit
# "Release <v> build <n>", make the signed tag, then check the gates. Pushes nothing.
release: _require-clean _require-notes
    #!/usr/bin/env bash
    set -euo pipefail
    v="$(scripts/ver)"
    if git rev-parse -q --verify "refs/tags/v$v" >/dev/null; then
        echo "v$v is already tagged: start the next version first (just bump <segment>)" >&2; exit 1
    fi
    n="$(scripts/bump-version.sh build)"
    notes="docs/release-notes/$v.md"
    scripts/compose-release-notes.sh --version "$v" > "$notes.tmp"
    mv "$notes.tmp" "$notes"
    scripts/compose-release-notes.sh --stub > docs/release-notes/UNRELEASED.md.tmp
    mv docs/release-notes/UNRELEASED.md.tmp docs/release-notes/UNRELEASED.md
    git add Version.xcconfig "$notes" docs/release-notes/UNRELEASED.md
    git commit -m "Release $v build $n"
    git tag -s "v$v" -m "Desktop Name Manager $v"
    printf '\nTagged v%s (signed). Checking the gates; then: just publish build, notarize, verify, and push/draft/publish/cask with --confirm\n\n' "$v"
    scripts/release.sh "$v" check

# Run one stage of the release procedure for the version in Version.xcconfig (see scripts/release.sh --help).
publish stage *args:
    scripts/release.sh "$(scripts/ver)" {{ stage }} {{ args }}

# (internal) fail before anything changes if the notes cannot be composed
_require-notes:
    @scripts/compose-release-notes.sh --check

# (internal) fail unless the working tree is clean; a build number moved by `just build` is fine, since the
# release commit takes Version.xcconfig anyway
_require-clean:
    @[[ "$(scripts/tree-state)" != "dirty" ]] \
        || { echo "working tree is dirty -- commit or stash first" >&2; exit 1; }

# Remove build output.
clean:
    swift package clean --scratch-path {{ scratch }}
