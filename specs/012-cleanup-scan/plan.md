# Implementation Plan: Feature F9 — `dnm cleanup --scan`

**Branch**: `012-cleanup-scan` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/012-cleanup-scan/spec.md`

## Summary

`dnm cleanup --scan` walks every Desktop of every connected display with the same public switching `--desktop`
uses, notes the labeled image each Desktop shows, and offers to delete the labels of connected displays that no
Desktop showed. The navigator gains a walk (research R1) with a stable read at each stop (R2) and a single walk when
"Displays have separate Spaces" is off (R3); Ctrl-C steps back before stopping (R4); the selection and the locked
deletion reuse the age-based cleanup's plan, report and deletion (R5). No stored-data change.

## Technical Context

**Language/Version**: Swift 6.4

**Primary Dependencies**: `swift-argument-parser` 1.8.2 (no change); AppKit, ApplicationServices (already used)

**Storage**: the manifest, format 3, unchanged (data-model.md); `lastSeen` updated by the scan

**Testing**: Swift Testing; core tests with the fake wallpaper system and a fake switcher that models Desktops with
wallpapers per display (walk order, return, failures, interrupt, separate Spaces off, selection, deletion); command
tests in-process and through the binary (refusals, no-terminal and `--json` behavior, help); a new live script

**Target Platform**: macOS 26 or later, Apple silicon (minimum unchanged: the walk uses what `--desktop` already
uses, and `NSScreen.screensHaveSeparateSpaces` and `sigaction` are far older than macOS 26)

**Project Type**: CLI over a shared core library

**Performance Goals**: at most about 2 steps per Desktop per display, about 1 s per step; 3 Desktops on each of 2
displays in under 20 s (SC-004)

**Constraints**: public interfaces only (no `Index.plist`, no SkyLight); Accessibility only for `--scan`, opt-in and
never prompted; nothing deleted without two answers or `--yes`; nothing deleted on any failure or interrupt

**Scale/Scope**: up to 16 Desktops per display, typically 1 to 4 displays

## Constitution Check

| Principle | Result |
|---|---|
| I. Public APIs only | Pass: the `--desktop` switching (shortcuts, `activeSpaceDidChangeNotification`), `desktopImageURL(for:)`, `NSScreen.screensHaveSeparateSpaces`, `sigaction` |
| II. Never require SIP changes | Pass |
| III. Least permission | Pass: Accessibility only for `--scan`, checked without prompting, explained when missing; labeling and the age-based cleanup still need none |
| IV. Local-only | Pass: no network |
| V. Reversible changes | Pass with the accepted exception of spec 009: a deleted image is gone, but only after two answers, and the scan makes that safer (only labels no Desktop shows); a deleted label is recreated by labeling again |
| VI. Distributable via Homebrew | Pass: no packaging change |
| VII. Tested | Pass: fake-switcher tests for every walk and failure path, selection and deletion tests, command tests, a live script in each display configuration |
| VIII. Public-repo hygiene | Pass: synthetic display names in tests and docs; the live script prints no identifiers |

No violations; Complexity Tracking is empty. Re-checked after Phase 1: unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/012-cleanup-scan/
├── plan.md              # this file
├── research.md          # R1-R8
├── data-model.md        # ScanResult, the new candidate reason, seen marking; no stored-data change
├── quickstart.md        # automated and live validation
├── contracts/cli.md     # the option, order, output, JSON, exit statuses, interrupt
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
Sources/DesktopNameCore/Switching/DesktopNavigator.swift  # walk(on:reading:) and the walk for shared Spaces; interrupt check between steps
Sources/DesktopNameCore/Switching/Interrupt.swift         # New: SIGINT flag (first: flag; second: one line, _exit(130)); install/restore around the walk
Sources/DesktopNameCore/Operations/Scan.swift             # New: ScanResult; scan(displays:switcher:separateSpaces:progress:) over the walk with stable reads
Sources/DesktopNameCore/Operations/Cleanup.swift          # CleanupReason.notOnAnyDesktop; scanPlan(from:); carryOut and a seen-only change accept the scan's seen names
Sources/DesktopNameCore/Operations/Reports.swift          # cleanup report: scanned displays, displays not checked; JSON fields
Sources/dnm/Commands/CleanupCommand.swift                 # --scan; --days optional and refused with --scan; order of R6; progress lines; exit 130
Tests/DesktopNameCoreTests/DesktopNavigatorTests.swift    # walk: start in the middle, one Desktop, shortcuts off, lost step, someone else switches, interrupt, return
Tests/DesktopNameCoreTests/ScanTests.swift                # New: per-display reads, separate Spaces off, stable read, selection, absent displays, missing file
Tests/DesktopNameCoreTests/CleanupTests.swift             # scan plan, deletion re-check, seen marking with and without deletion, nudge reset
Tests/dnmTests/CleanupCommandTests.swift                  # refusals (--days, display words), permission message first, no terminal, --json without --yes, help
Tests/live/live-scan.sh                                   # New: label three Desktops, delete one by hand, scan, compare (Index.plist backup, live-control announcements)
README.md, docs/release-notes/UNRELEASED.md, specs/009 (pointer, done), specs/007 contracts (completion of --scan),
specs/001-labels-and-cli/known-issues.md (KI-2 note: the scan names absent displays)
```

**Structure Decision**: the existing single package; two new core files, one new core test file, one new live
script.

## Phases

1. **Walk**: `walk(on:reading:)` in the navigator with the fake switcher extended to hold a wallpaper per Desktop;
   tests for every path in the list above; the shared-Spaces walk reads every display at each stop.
2. **Interrupt**: `Interrupt` (flag, install and restore); the walk checks it between steps and returns before
   throwing; a fake raises it at a chosen step; the second-interrupt path is a small function tested without
   signals, and checked live.
3. **Scan and selection**: `Scan` builds the `ScanResult` with the stable read; `scanPlan` selects; `carryOut`
   re-checks and marks seen; a seen-only change for the declined case; tests with the fake system (SC-002, SC-003).
4. **Command**: `--scan` with the order of research R6, the description and estimate, the two questions, progress
   lines, the report (scanned displays, displays not checked), JSON, exit statuses (1 for failures, 130 for an
   interrupt, 2 for refused options); help text; completion offers `--scan`.
5. **Docs**: README (the scan, what it needs and shows, when to prefer it), release notes, KI-2 note, spec 007
   completion contract.
6. **Live**: `Tests/live/live-scan.sh` under the live-test rules, announced as live control and approved first, on
   one display and on two (SC-001, SC-004); Ctrl-C during a walk by hand; "Displays have separate Spaces" off if the
   maintainer can switch it (it needs a log-out).
7. **Release gates** for 0.3.0 with F7.

## Complexity Tracking

None.
