# Implementation Plan: Feature F3 (first part) — Several Displays in One Command

**Branch**: `010-several-displays` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/010-several-displays/spec.md`

## Summary

`set`, `remove` and `undo` act on every display named: the one interpretation function in the core
(`DisplayArguments`, spec 008) returns the displays in order, a small core helper runs the change display by
display and reports a part-way failure, and `undo`'s existing checks move into a read-only check that runs for every
display first. `remove` and `undo` take several display words; `set` takes one plus `--display`; `show` is unchanged.
No stored data, dependency, interface or permission changes.

## Technical Context

**Language/Version**: Swift 6.4

**Primary Dependencies**: `swift-argument-parser` 1.8.2 (no change)

**Storage**: the manifest, format 3, unchanged (data-model.md)

**Testing**: Swift Testing; unit tests in `DesktopNameCoreTests` with the fake wallpaper system, contract and
in-process parse tests in `dnmTests`, the live script `Tests/live/live-syntax.sh`

**Target Platform**: macOS 26 or later, Apple silicon (minimum unchanged: nothing newer is used, research R7)

**Project Type**: CLI over a shared core library (the app, M2, later)

**Performance Goals**: each display costs what a single command costs today (about a second for `set`); displays
are changed one after another

**Constraints**: public interfaces only; labeling needs no permission; `--desktop` keeps its opt-in Accessibility
use; nothing changes before every check that can be made without switching Desktops has passed

**Scale/Scope**: the displays connected to one Mac (typically 1 to 4)

## Constitution Check

| Principle | Result |
|---|---|
| I. Public APIs only | Pass: no new interface; the same `NSWorkspace` calls per display |
| II. Never require SIP changes | Pass |
| III. Least permission | Pass: labeling several displays needs no permission; `--desktop` asks for Accessibility exactly as today |
| IV. Local-only | Pass: no network |
| V. Reversible changes | Pass: every display's change is recorded and undoable as today; a part-way failure names the `dnm undo` that puts the changed displays back |
| VI. Distributable via Homebrew | Pass: no packaging change |
| VII. Tested | Pass: table-driven and fake-system tests, contract tests, and a live check on two or more displays before release (SC-004) |
| VIII. Public-repo hygiene | Pass: tests and docs use synthetic display names (`DP`, `main`) |

No violations; Complexity Tracking is empty. Re-checked after Phase 1: unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/010-several-displays/
├── plan.md              # this file
├── research.md          # R1-R7 (R4 has a decision pending)
├── data-model.md        # no stored-data change; in-memory values
├── quickstart.md        # automated and live validation
├── contracts/cli.md     # grammar, order, checks, output, exit status
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
Sources/DesktopNameCore/Displays/DisplayArguments.swift   # Targets (ordered, distinct); targets(...) for remove/undo; setRequest returns Targets
Sources/DesktopNameCore/Operations/DisplayBatch.swift     # New: run displays in order; part-way failure message, same DnmError case
Sources/DesktopNameCore/Operations/UndoLabel.swift        # checkUndo(on:): the existing checks, read-only; undoLastChange calls it
Sources/dnm/DisplayOption.swift                           # DisplayWords: visible, completed extra words (remove, undo); show keeps one word
Sources/dnm/Context.swift                                 # targets(...) for remove/undo; setRequest returns Targets; warn once
Sources/dnm/Commands/{Set,Remove,Undo}Command.swift       # loop through DisplayBatch; usage lines; one reminder after the loop
Sources/dnm/Commands/ShowCommand.swift                    # unchanged behavior (its own one-word arguments if DisplayWords changes)
Tests/DesktopNameCoreTests/Support/FakeWallpaperSystem.swift  # a failure for one display
Tests/DesktopNameCoreTests/DisplayArgumentsTests.swift    # the table of the spec's command lines (SC-001)
Tests/DesktopNameCoreTests/DisplayBatchTests.swift        # New: order, first/second-of-three failure, message, quoting
Tests/DesktopNameCoreTests/UndoLabelTests.swift           # checkUndo refuses what undo refuses, changes nothing
Tests/dnmTests/*                                          # refusals through the binary; parse and completion by position
Tests/live/live-syntax.sh                                 # several displays changed, show refused, wallpapers restored
README.md, docs/release-notes/UNRELEASED.md, specs/008 (FR-002, FR-004, FR-006, clarification, contracts/cli.md),
specs/007 (contracts/cli.md: completion of repeated display words), specs/001 (contracts/cli.md if it states one display)
```

**Structure Decision**: the existing single package (core library, `dnm` executable, two test targets); one new
core file and one new test file.

## Phases

0. **Decision R4** (maintainer): with `--desktop`, check Desktop-level conditions while changing (recommended, amends
   FR-004 and User Story 5 scenario 2) or in a checking pass first.
1. **Core reading**: `DisplayArguments.Targets` and `targets(...)`; `setRequest` returns `Targets`; `show` keeps
   `target(...)`. The table test of every command line in the spec, ordered displays, duplicates by different names,
   empty values, the word's hint, notices once.
2. **Core running**: `checkUndo(on:)` split out of `undoLastChange` (same checks, read-only, same messages);
   `DisplayBatch` with its tests, using a per-display failure in the fake system.
3. **Commands**: `set`, `remove`, `undo` resolve, check, then loop through `DisplayBatch`, printing each line;
   one reminder after the loop; usage lines and help; `DisplayWords` extra words visible and completed for `remove`
   and `undo`, `show` unchanged. The `CommandsStayThinTests` tripwire still passes. Contract tests for the refusals
   (exit status, nothing created) and in-process parse and completion tests.
4. **Docs**: README (several displays, examples with displays before the label; remove "not supported"), help,
   release notes (a new ability; one display behaves as before), spec 008 and 007 amendments.
5. **Live**: `Tests/live/live-syntax.sh` updated and run on two displays (quickstart 1 to 8) under the live-test
   rules; scenario 7 needs live control, announced and approved first.
6. **Release gates** for 0.2.2 as for 0.2.1: independent code and security reviews, the live record, the gate record.

## Complexity Tracking

None.
