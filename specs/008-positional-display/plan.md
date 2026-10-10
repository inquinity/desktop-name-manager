# Implementation Plan: Feature F8 — Display as a Positional Argument

**Branch**: n/a (spec directory `008-positional-display`; work happens on main) | **Date**: 2026-10-09 | **Spec**: [spec.md](spec.md)

## Summary

Read `dnm set [<display>] <label>`, `dnm set [<display>] --label <text>` and `dnm remove|undo|show [<display>]` in
one core function that also resolves the display (once), keep `--display` (now refusing a repeat), and update
completion, help, README, release notes and the specs it amends. No dependency, interface or permission change.

## Technical Context

Swift 6.4; `swift-argument-parser` 1.8.2; Swift Testing (unit in `DesktopNameCoreTests`, contract and in-process
parse tests in `dnmTests`). Public APIs only; no permissions; no network.

## Constitution Check

All principles pass: no new interface (I, II), no permission (III), no network (IV), only the reading of
command-line words changes and every change is still undoable (V), no packaging change (VI), tested at three
levels (VII), tests use synthetic display names (VIII).

## Source changes

```text
Sources/DesktopNameCore/Displays/DisplayResolver.swift          # isReference, from the resolver's own matchers
Sources/DesktopNameCore/Displays/DisplayArguments.swift         # New: reads words and flags, resolves once, the errors
Sources/dnm/DisplayOption.swift                                 # --display becomes [String] so a repeat is seen
Sources/dnm/Context.swift                                       # resolveDisplay no longer takes a DisplayOption
Sources/dnm/Commands/{Set,Remove,Undo,Show}Command.swift        # positional first/second/extra; --label; custom usage
Tests/DesktopNameCoreTests/DisplayArgumentsTests.swift          # New: the table of invocations, every error
Tests/dnmTests/PositionalDisplayTests.swift                     # New: errors and `show` through the binary; in-process parsing
Tests/dnmTests/CompletionTests.swift                            # first-word completion by position
README.md, docs/release-notes/UNRELEASED.md, specs/001 (FR-023, contracts/cli.md), specs/006 (FR-011), specs/007 (contracts/cli.md)
```

## Phases

0. **Spike**: confirm the parser accepts optional positional arguments followed by an array with options
   interleaved, that the generated scripts give `positional@N` for each, that `--display` as `[String]` sees a
   repeat, and that `@testable import dnm` (the `@main` target) works for in-process parse tests. Adjust the plan
   if not.
1. **Core**: `DisplayResolver.isReference` (shared matchers); `DisplayArguments` with a table-driven unit test of
   every invocation in the spec and every error, quoting of suggested commands, digits, `main`/`Main`, partial
   names, overridden and absent aliases, the same display twice.
2. **Commands**: the four commands read their words through `DisplayArguments` and pass the resolved display on;
   `--label`; custom usage; `Context.resolveDisplay` takes the resolved display or its value. Contract tests for
   the error cases and for `show` by name and alias; in-process parse tests for `set` (options between words).
   A test fails if a command file calls the resolver or compares display names (SC-003).
3. **Completion**: nothing to count; check by position that the first word offers displays and usable aliases
   and the second word and `--label` offer nothing (spec 007 contract updated).
4. **The positional syntax suite** (four layers): the table-driven unit test of the interpretation; the in-process
   parse tests (`CommandParsingTests`); the binary error tests (exit 2, nothing created); and a live script,
   `Tests/live/live-syntax.sh`, that runs the syntax on every connected display and the multi-display cases that
   must be refused.
5. **Docs and verification**: README (grammar, aliases to avoid quotes, scripts use `--display`/`--label`), help,
   release notes with the two changes of behavior, the amended specs; the interactive Tab check; a live `set`,
   `remove`, `undo` on a throwaway wallpaper under the project's live-test rules (back up `Index.plist` first).
