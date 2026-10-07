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
release *args:
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

# Remove build output.
clean:
    swift package clean --scratch-path {{ scratch }}
