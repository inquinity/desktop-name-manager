# Build and test tasks. SwiftPM's own folder (.build) is not used for our builds: everything goes to
# build.noindex, which Spotlight and Time Machine skip. Requires `just` (brew install just).

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

scratch := "build.noindex"

# List the available tasks.
default:
    @just --list

# Debug build of the library and dnm.
build *args:
    swift build --scratch-path {{ scratch }} {{ args }}

# Optimized build of dnm (build.noindex/release/dnm).
release *args:
    swift build -c release --scratch-path {{ scratch }} {{ args }}

# Unit and contract tests (they never change your real wallpaper).
test *args:
    swift test --scratch-path {{ scratch }} {{ args }}

# Unused-code scan (needs `brew install periphery`).
periphery:
    scripts/periphery.sh

# Assemble the live-test kit to copy to another Mac (dist/dnm-live-kit).
kit:
    scripts/make-live-kit.sh

# Remove build output.
clean:
    swift package clean --scratch-path {{ scratch }}
