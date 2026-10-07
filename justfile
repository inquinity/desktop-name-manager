# Build and test tasks. SwiftPM's own folder (.build) is not used for our builds: everything goes to
# build.noindex, which Spotlight and Time Machine skip. Requires `just` (brew install just).

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

scratch := "build.noindex"

# List the available tasks.
default:
    @just --list

# Debug build of the library and dnm. Every build is stamped with its commit (see scripts/build-stamp.sh),
# so `dnm --version` shows which commit you are running.
build *args:
    flags=(); while IFS= read -r flag; do flags+=("$flag"); done < <(scripts/build-stamp.sh); \
    swift build --scratch-path {{ scratch }} --force-resolved-versions "${flags[@]}" {{ args }}

# Optimized build of dnm (build.noindex/release/dnm).
build-release *args:
    flags=(); while IFS= read -r flag; do flags+=("$flag"); done < <(scripts/build-stamp.sh); \
    swift build -c release --scratch-path {{ scratch }} --force-resolved-versions "${flags[@]}" {{ args }}

# Unit and contract tests (they never change your real wallpaper).
test *args:
    flags=(); while IFS= read -r flag; do flags+=("$flag"); done < <(scripts/build-stamp.sh); \
    swift test --scratch-path {{ scratch }} --force-resolved-versions "${flags[@]}" {{ args }}

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

# Cut a release (seg: major|minor|revision, or current to keep the version): bump, compose the notes,
# commit "Release <v> build <n>", make the signed tag, then check the gates. Pushes nothing.
release seg: _require-clean _require-notes
    #!/usr/bin/env bash
    set -euo pipefail
    scripts/bump-version.sh {{ seg }}
    v="$(scripts/ver)"; n="$(scripts/build-num)"
    notes="docs/release-notes/$v.md"
    scripts/compose-release-notes.sh --version "$v" > "$notes.tmp"
    mv "$notes.tmp" "$notes"
    scripts/compose-release-notes.sh --stub > docs/release-notes/UNRELEASED.md
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

# (internal) fail unless the working tree is clean
_require-clean:
    @git diff --quiet && git diff --cached --quiet \
        || { echo "working tree is dirty -- commit or stash first" >&2; exit 1; }

# Remove build output.
clean:
    swift package clean --scratch-path {{ scratch }}
