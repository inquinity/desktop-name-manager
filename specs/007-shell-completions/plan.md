# Implementation Plan: Feature F1 — Shell Completions

**Branch**: n/a (spec directory `007-shell-completions`; work happens on main) | **Date**: 2026-10-09 | **Spec**: [spec.md](spec.md)

## Summary

Use the parser's completion support: fixed lists from the validating enums, custom callbacks for displays and
aliases (rules in the core next to the resolver, thin helpers in the CLI), and package the generated scripts
in the release zip and cask. No new dependency or interface.

## Technical Context

**Language/Version**: Swift 6.4, Swift 6 mode. **Dependency**: `swift-argument-parser` 1.8.2 (pinned, reviewed).
**Storage**: none new; the callbacks read the manifest and never create it. **Testing**: Swift Testing, unit tests
in `DesktopNameCoreTests`, contract tests in `dnmTests` against the built binary; release checks in
`scripts/release.sh`. **Platform**: macOS 26+. **Constraints**: public APIs only; no permissions; no network;
read-only.

## Constitution Check

| Principle | Status | How |
|---|---|---|
| I. Public APIs only | Pass | Same display and store reads as `dnm displays` and spec 006. |
| II. Never require SIP changes | Pass | No system change; files go where Homebrew puts completions. |
| III. Least permission | Pass | No permission; completion switches no Desktop. |
| IV. Local-only | Pass | No network; the callback is a local run of the same binary. |
| V. Reversible changes | Pass | The cask removes the files; completions change nothing else. |
| VI. Distributable via Homebrew | Pass | Uses the cask's own completion stanzas. |
| VII. Tested | Pass | Unit, contract and release-procedure checks; a live install check. |
| VIII. Public-repo hygiene | Pass | Tests use synthetic display names. |

## Source changes

```text
Sources/DesktopNameCore/Displays/DisplayResolver.swift   # completionCandidates (the rules)
Sources/dnm/Completions.swift                            # New: callbacks over the system and the store
Sources/dnm/DisplayOption.swift                          # --display completion
Sources/dnm/Commands/SetCommand.swift                    # fixed values for --style/--color/--position/--size
Sources/dnm/Commands/AliasCommand.swift                  # name (--remove) and display completions
scripts/release.sh                                       # build: generate and check the scripts; zip list; cask test
packaging/desktop-name-manager.rb.template               # completion stanzas
Tests/DesktopNameCoreTests/DisplayResolverTests.swift    # candidate rules
Tests/dnmTests/CompletionTests.swift                     # New: callback and script contract tests
README.md, docs/release-notes/UNRELEASED.md, specs/005-packaging-and-release (FR-005, contracts/cask.md, release-procedure.md)
```

## Phases

1. **Core and CLI**: `completionCandidates` with unit tests; callbacks and fixed lists; contract tests against the
   hidden call and the generated scripts (the fixed lists equal the enumerations; both names registered).
2. **Packaging**: generate the three files in `build`, extend the zip's expected list and the checks, the cask
   template and the cask test (install and uninstall check the files); update spec 005's contracts.
3. **Documentation**: README section, release notes, spec 005 FR-005.
4. **Verification**: `just test`, `just periphery`; simulated Tab in bash and zsh against the debug build;
   after release, the live install check (quickstart).
