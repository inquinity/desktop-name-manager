# Implementation Plan: Feature F6 — `remove` repairs a misreported Desktop

**Branch**: `013-remove-repair` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/013-remove-repair/spec.md`

## Summary

Confirm known issue KI-3 live and that setting the reported original again repairs it (research R1). Then, in
`remove`, when the reported image is no label but is the recorded original of a label of this display (R2), set that
original again with its recorded placement and return a new outcome, `.repaired` (R3), with a result line (R4). No
change record, no stored-data change. The plan assumes the proposed decisions Q1-Q5 in the spec; a different answer
to Q1 (an option instead of plain `remove`) adds the option and its help, completion and tests, and nothing else.

## Technical Context

**Language/Version**: Swift 6.4

**Primary Dependencies**: `swift-argument-parser` 1.8.2 (no change); AppKit (already used)

**Storage**: the manifest, format 3, unchanged; `lastSeen` marked as `remove` does today

**Testing**: Swift Testing with the fake wallpaper system (a Desktop that reports an original of a label; one that
reports an unrelated image; a missing original; two labels with one original; several displays); command tests
through the binary for help text; a live by-hand check of KI-3's steps (SC-001)

**Target Platform**: macOS 26 or later (unchanged)

**Project Type**: CLI over a shared core library

**Performance Goals**: none new (one extra lookup in the manifest when no label is found)

**Constraints**: public interfaces only in the product; the research step uses `prototype/` only; no permission

**Scale/Scope**: one function in core, one outcome, one line of output

## Constitution Check

| Principle | Result |
|---|---|
| I. Public APIs only | Pass: `desktopImageURL(for:)` and `setDesktopImageURL` as today; the research tools stay in `prototype/` |
| II. Never require SIP changes | Pass |
| III. Least permission | Pass: no permission (as `remove` today; `--desktop` keeps its Accessibility use) |
| IV. Local-only | Pass |
| V. Reversible changes | Pass: the repair sets the image macOS already reports; nothing is deleted |
| VI. Distributable via Homebrew | Pass: no packaging change |
| VII. Tested | Pass: fake-system tests for each case, a by-hand live check |
| VIII. Public-repo hygiene | Pass: synthetic names in tests; the research notes go in `working-notes/` until they are scrubbed of identifiers |

No violations.

## Project Structure

```text
specs/013-remove-repair/
├── plan.md, research.md, data-model.md, quickstart.md, contracts/cli.md, tasks.md

Sources/DesktopNameCore/Operations/RemoveLabel.swift   # .repaired outcome; matchingOriginal(for:on:in:)
Sources/dnm/Commands/RemoveCommand.swift               # the repair line; help text
Sources/DesktopNameCore/Operations/DisplayBatch.swift  # (if needed) a repaired display is not "changed"
Tests/DesktopNameCoreTests/RemoveLabelTests.swift      # the cases in Technical Context
Tests/dnmTests/...                                     # help text
prototype/ (research only, not shipped)                # the R1 confirmation, if a new tool is needed
README.md, specs/001-labels-and-cli/known-issues.md (KI-3), docs/release-notes/UNRELEASED.md
```

## Phases

0. **Confirm** (R1): live, read-only plus one prototype set, under the live-test rules; record the outcome. Stop here
   if neither way works (spec Q5).
1. **Core**: the match (R2) and the outcome (R3), with tests first.
2. **Command**: the line (R4), help, several displays.
3. **Docs**: README, KI-3 (mitigated), release notes, the spec 012 interaction note.
4. **Review and live**: independent code review; SC-001 by hand.

## Complexity Tracking

None.
