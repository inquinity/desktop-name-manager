---
description: "Task list for feature F6: remove repairs a misreported Desktop"
---

# Tasks: Feature F6 — `remove` repairs a misreported Desktop

**Input**: `specs/013-remove-repair/` (spec.md, plan.md, research.md, data-model.md, contracts/cli.md, quickstart.md)

**Tests**: included (SC-002, SC-003).

**Before starting**: confirm or change the proposed decisions Q1-Q5 in spec.md (`/speckit-clarify`). The tasks
assume the proposals; Q1 = "an option" adds T009a below.

**Rules for every task**: no automated test changes a real wallpaper (fake wallpaper system, temporary store);
synthetic names; public interfaces only in `Sources/`; `prototype/` only for research; live steps under the
live-test rules, with live control asked for and announced first when Desktops switch.

## Phase 1: Confirm (blocks everything; spec FR-001, research R1)

- [ ] T001 Confirm the baseline on `main`: `just build`, `just test`, `just periphery` pass; quote `dnm --version`
- [ ] T002 Live, by hand with the maintainer: reproduce KI-3 (quickstart steps 1-3) with a throwaway `DNM_STORE_DIR` and `Index.plist` backed up; record whether it reproduces on macOS 27
- [ ] T003 Live: snapshot the KI-3 state with `prototype/space-observer.swift` (read-only); note the new Desktop's entry versus `dnm show`; keep identifiers out of tracked files (notes in `working-notes/`, a scrubbed summary in KI-3)
- [ ] T004 Live: with a one-off prototype in `prototype/` (never shipped), set the reported URL and options again on the new Desktop and look at the screen; if nothing changes, try the labeled image then the original (research R1 step 4)
- [ ] T005 Record the outcome in `specs/001-labels-and-cli/known-issues.md` (KI-3) and `specs/013-remove-repair/research.md` (R1); if neither way works, stop here and close this spec as not feasible (spec Q5); if only the two-step way works, amend FR-002 and ask the maintainer before continuing

**Checkpoint**: the cause is known and a repair is shown to work.

## Phase 2: Core (spec FR-002, FR-003, FR-005; research R2, R3)

- [ ] T006 [P] In `Tests/DesktopNameCoreTests/RemoveLabelTests.swift`, tests first: a Desktop that reports the original of a label of this display is set again with the recorded placement and fill, outcome `.repaired`, no change record, manifest identical apart from `lastSeen` (SC-003); an unrelated image is not set, outcome `.noLabel` (SC-002); an original of a label of another display is not matched; a missing original throws `originalMissing` and sets nothing; two labels with one original use the most recent one's placement; no store yet: `.noLabel`, store not created; a normal label is removed exactly as before
- [ ] T007 In `Sources/DesktopNameCore/Operations/RemoveLabel.swift`, add `case repaired` to `RemoveLabelOutcome` and a `matchingOriginal(for url: URL?, on display: Display, in manifest: Manifest) -> Stamp?` (labels of `display.uuid` whose original resolves, through `Self.resolve`, to the same file as `url` after resolving symbolic links; the most recent `createdAt` wins); in `performRemoveLabel`, when `stamp(for:in:)` finds nothing, try the match: set the original with `apply(_:placement:on:)` and `Self.placement(of:)`, mark seen as today, record no change, return `.repaired`

**Checkpoint**: core tests pass.

## Phase 3: Command (spec FR-004, FR-007; contracts/cli.md)

- [ ] T008 In `Sources/dnm/Commands/RemoveCommand.swift`, print the repair line for `.repaired` (contracts/cli.md), and do not call `changed()` for it, so a part-way message on several displays does not name a repaired display (research R4); add the help sentence
- [ ] T009 [P] In `Tests/DesktopNameCoreTests/DisplayBatchTests.swift` (or `RemoveLabelTests`), several displays: one repaired, one removed, then a failure: the part-way message names only the removed display; in `Tests/dnmTests/`, `remove --help` has the sentence
- [ ] T009a (only if Q1 = an option) Add `--repair` to `remove`, its help, completion (spec 007) and tests; plain `remove` keeps `No label on <display>.`

## Phase 4: Docs (spec FR-008)

- [ ] T010 [P] `specs/001-labels-and-cli/known-issues.md`: KI-3 status "mitigated in <version>: `remove` sets the original again", with the confirmed cause; the spec 012 interaction (the scan may offer a label shown only on a misreported Desktop; repair first)
- [ ] T011 [P] `README.md`: where `remove` and the left-most Desktop are described, one sentence on the repair; in "Scanning every Desktop", one sentence on KI-3; `docs/release-notes/UNRELEASED.md`: one bullet

## Phase 5: Review and live

- [ ] T012 Independent code review by a fresh agent given only the branch's diff against `main` (constitution VII); fix or have the maintainer accept each finding; record it here
- [ ] T013 `just test` and `just periphery` pass (a native build first); scan the diff for personal paths, names and UUIDs
- [ ] T014 Live by hand (quickstart steps 5-7), quoting `dnm --version`; record the results here (SC-001)

## Dependencies

- Phase 1 blocks every other phase (T005 may stop the feature).
- T006 before T007; T007 before T008; T009 after T008; docs after T008; T012 after T011; T013 after the fixes; T014 last.

## Implementation strategy

Phase 1 is the decision point. If it confirms the repair, the change is small (one outcome, one lookup, one line),
and fits a patch release after 0.3.0.
