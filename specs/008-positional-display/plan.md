# Implementation Plan: Feature F8 — Display as a Positional Argument

**Branch**: n/a (spec directory `008-positional-display`; work happens on main) | **Date**: 2026-10-09 | **Spec**: [spec.md](spec.md)

## Summary

Interpret `dnm set [<display>] <label>` and `dnm remove|undo|show [<display>]` in one core function, resolve the
display through the existing resolver, keep `--display`, and update completion, help, README, release notes and
the specs it amends. No dependency, interface or permission changes.

## Technical Context

Swift 6.4; `swift-argument-parser` 1.8.2; Swift Testing (unit in `DesktopNameCoreTests`, contract in `dnmTests`).
Public APIs only; no permissions; no network.

## Constitution Check

All principles pass: no new interface (I, II), no permission (III), no network (IV), only the interpretation of
command-line words changes and every change is still undoable (V), no packaging change (VI), tested at both levels
(VII), tests use synthetic display names (VIII).

## Source changes

```text
Sources/DesktopNameCore/Displays/DisplayResolver.swift          # isReference (exact main / display / alias)
Sources/DesktopNameCore/Displays/DisplayArguments.swift         # New: the interpretation, errors E1 to E5
Sources/dnm/Commands/{Set,Remove,Undo,Show}Command.swift        # words argument; call the interpretation
Sources/dnm/Completions.swift                                   # first-argument completion; argument counting
Sources/dnm/DisplayOption.swift                                 # help mentions the argument
Tests/DesktopNameCoreTests/DisplayArgumentsTests.swift          # New: every row of the table and every error
Tests/dnmTests/PositionalDisplayTests.swift                     # New: error cases and show through the binary
Tests/dnmTests/CompletionTests.swift                            # first-argument completion
README.md, docs/release-notes/UNRELEASED.md, specs/001 (FR-023, contracts/cli.md), specs/006 (FR-011), specs/007 (contracts/cli.md)
```

## Phases

1. **Core**: `DisplayResolver.isReference`; `DisplayArguments` with unit tests for the interpretation table,
   E1 to E5, the quoting and alias hints, digits, `main`, partial names, overridden and absent aliases.
2. **Commands**: the four commands take `words`, validate and interpret; `--display` unchanged; contract tests
   for the error cases and for `show` through a display name (read-only).
3. **Completion**: first-argument completion and argument counting, with tests (spec 007 contract updated).
4. **Docs and verification**: README, help, release notes (including the E3 change), the amended specs; the
   interactive Tab check; a live `set`, `remove`, `undo` on a throwaway wallpaper per the project's live-test
   rules (back up `Index.plist` first) before release.
