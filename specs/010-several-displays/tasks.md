---
description: "Task list for feature F3 (first part): several displays in one command"
---

# Tasks: Feature F3 (first part) — Several Displays in One Command

**Input**: `specs/010-several-displays/` (spec.md, plan.md, research.md, data-model.md, contracts/cli.md, quickstart.md)

**Tests**: included (the spec's SC-001 to SC-004 ask for them). The decisions in `spec.md` are made, including
research R4 (with `--desktop`, Desktop-level checks are made while changing).

**Rules for every task**: no test changes a real wallpaper (the fake wallpaper system and a temporary store only);
synthetic display names (`main`, `DP`, `Side`) in tests and docs; build and test with `just` (`build.noindex/`).

## Phase 1: Setup

- [ ] T001 Test support: in `Tests/DesktopNameCoreTests/Support/FakeWallpaperSystem.swift`, add a failure for one display (`setErrors: [String: Error]`, keyed by display UUID, checked before the existing global `setError`), so a test can make the second of three displays fail (research R6)

## Phase 2: Foundational (blocks every story)

- [ ] T002 In `Sources/DesktopNameCore/Displays/DisplayArguments.swift`, add `Targets` (the displays in order and the override notices, joined once) and make the private `resolve` return every distinct display in order: "the display words, in order, then each `--display` value, in order"; "a display named more than once, by the same or a different name, is one display, at its first place"; no display named means the main display; an empty value is refused; the word's hint stays on the word (data-model.md, contracts/cli.md §2, FR-001, FR-005)
- [ ] T003 In the same file, keep `target(command:words:displayFlags:in:aliases:)` for `show` only: at most one word, and two different displays still refused with "Multiple displays for a single command are not currently supported." (FR-002)
- [ ] T004 In the same file, add `targets(command:words:displayFlags:in:aliases:)` for `remove` and `undo` (any number of display words), and change `setRequest` to return `Targets` (at most one display word; the spec 008 rules for `set` unchanged otherwise) (FR-001, FR-010)
- [ ] T005 [P] Extend `Tests/DesktopNameCoreTests/DisplayArgumentsTests.swift` with the table of every command line in `spec.md` and `contracts/cli.md` §2 and the ordered displays each resolves to (or its error): duplicates by different names (`main` and its name, an alias and its display), order kept, an empty value among several, a typo among several (the resolver's message), `show` refusing two, `set` with three words still refused, the override notice once (SC-001)
- [ ] T006 Create `Sources/DesktopNameCore/Operations/DisplayBatch.swift`: run a closure for each display in order, recording each that succeeds; on an error, rethrow the same `DnmError` case (so the exit status is the error's own) with, when at least one display was already changed, the message followed by `Changed before this: <names>. To put them back within 60 seconds: dnm undo <displays>.`, the displays quoted with `ShellQuoting.quote`; prefix `On <name>: ` when the error's message does not name the display; a failure on the first display passes the error through unchanged (research R3, contracts/cli.md §4, FR-006)
- [ ] T007 [P] Create `Tests/DesktopNameCoreTests/DisplayBatchTests.swift`: all succeed in order; a failure on the first (error unchanged, nothing else attempted); on the second of three (the first changed, the third never attempted, the message names both and the undo command, the case and exit status kept); names with spaces and quotes are quoted; one display behaves exactly as a single call (FR-009)
- [ ] T008 In `Sources/DesktopNameCore/Operations/UndoLabel.swift`, split the read-only checks out of `undoLastChange` into `checkUndo(on:)` (a record for the display within its window, the current wallpaper is what the change produced, the files it needs exist; same messages), with a variant that checks the record and window only for `--desktop` (research R4); `undoLastChange` calls the full check first, so its behavior is unchanged
- [ ] T009 [P] In `Tests/DesktopNameCoreTests/UndoLabelTests.swift`, test that `checkUndo` refuses exactly what `undoLastChange` refuses, with the same message, and changes no file and no wallpaper; and that the record-only variant passes where only the current wallpaper differs

**Checkpoint**: `just test` passes; the commands still use one display.

## Phase 3: User Story 1 — Label several displays at once (P1) 🎯 MVP

**Goal**: `dnm set main "Mail" --display DP` labels both displays.

**Independent test**: with the fake system and two displays, the command labels both, prints two lines in order, exit 0.

- [ ] T010 [US1] In `Sources/dnm/Context.swift`, `setRequest` returns `Targets`; `warn` prints each override notice once, after the label and options are validated and before the first change (research R5)
- [ ] T011 [US1] In `Sources/dnm/Commands/SetCommand.swift`, validate the label and options, get the `Targets`, then run `DisplayBatch` over them, each display through `context.onDesktop` and `labeler.setLabel`, printing its confirmation line as it succeeds; `Nudge.showIfDue` once, after the loop; the help says several displays may be named, with the example `dnm set main "Mail" --display DP` (FR-007, FR-011, FR-013)
- [ ] T012 [P] [US1] In `Tests/dnmTests/` (the in-process parse tests), `set` with a display word and repeated `--display` parses into the expected words and flags; options between the words still work

**Checkpoint**: User Story 1 works on its own; one display behaves as in 0.2.1.

## Phase 4: User Story 2 — Remove or undo on several displays (P1)

**Goal**: `dnm remove main DP` and `dnm undo main DP` act on both.

**Independent test**: with the fake system, `remove` on two displays (one without a label prints "No label on ..." and is not a failure); `undo` on two within the window; `undo` where one display has nothing to undo changes nothing and exits 1.

- [ ] T013 [US2] In `Sources/dnm/DisplayOption.swift`, make the extra display words of `remove` and `undo` a visible, completed argument (`[<display> ...]`, completion `Completions.displays(includeAliases: true)`), and give `show` its own one-word arguments so its help and its "at most one display" error are unchanged (research R2, FR-012)
- [ ] T014 [US2] In `Sources/dnm/Context.swift`, add `targets(command:words:option:)` for `remove` and `undo`; `target(...)` stays for `show`
- [ ] T015 [US2] In `Sources/dnm/Commands/RemoveCommand.swift`, run `DisplayBatch` over the targets, printing `No label on <display>.` or the removed line per display; the reminder once after the loop; usage `dnm remove [<display> ...] [options]` and the example `dnm remove main DP`
- [ ] T016 [US2] In `Sources/dnm/Commands/UndoCommand.swift`, before the first change call `checkUndo` for every display (the record-only variant with `--desktop`), then run `DisplayBatch`; usage `dnm undo [<display> ...] [options]` and the example `dnm undo main DP` (FR-003, FR-004)
- [ ] T017 [P] [US2] In `Tests/dnmTests/` (in-process parse and completion tests), `remove` and `undo` with several words and `--display`; Tab offers displays and aliases for the second and later words of `remove` and `undo` and for a repeated `--display`, and still nothing beyond one word for `show` (FR-012)

**Checkpoint**: User Stories 1 and 2 work; `show` is unchanged.

## Phase 5: User Story 3 — A mistake changes nothing (P1)

**Goal**: a typo, an invalid label or option, or `show` with two displays changes nothing.

- [ ] T018 [P] [US3] In `Tests/dnmTests/PositionalDisplayTests.swift` (through the built binary, exit status and standard error, no store created): `set main "x" --display NoSuchDisplay` (exit 2), `remove main NoSuch`, a 31-character label with two displays, `show main --display DP` (exit 2, the "Multiple displays" message); replace the existing cases that expected the refusal for `set`, `remove` and `undo` with these (SC-002, SC-003)
- [ ] T019 [P] [US3] In `Tests/DesktopNameCoreTests/` (fake system), a refused `set`, `remove` or `undo` on several displays leaves every display's wallpaper and the stored data byte-identical (SC-002)

## Phase 6: User Story 4 — A failure part-way says what changed (P2)

**Goal**: a failure on the second of three displays leaves exactly the first changed and says so.

- [ ] T020 [US4] In `Tests/DesktopNameCoreTests/` (fake system, `setErrors` from T001), `set` and `remove` on three displays with the second failing: the first changed and recorded (its undo works), the third untouched, the error's message names both and the `dnm undo` command, the exit status is the failing error's (FR-006, SC-002)

## Phase 7: User Story 5 — Several displays with `--desktop` (P3)

**Goal**: `--desktop N` labels Desktop N of each display, each returning to where it was.

- [ ] T021 [US5] In `Tests/DesktopNameCoreTests/DesktopNavigatorTests.swift` (fake switcher), two displays in turn with `--desktop 2`: each is visited and returned; the second without a Desktop 2 fails when reached, after the first is labeled, and the part-way message follows (FR-004)
- [ ] T022 [US5] Check that `Context.onDesktop` needs no change for several displays (one switcher per display, pointer restored each time); if it does, change it in `Sources/dnm/Context.swift` and say so in `research.md`

## Phase 8: Polish and cross-cutting

- [ ] T023 [P] `README.md`: several displays (examples with the displays before the label: `dnm set main "Mail" --display DP`, `dnm remove main DP`, `dnm undo main DP`); remove the statement that two displays are not supported; a part-way failure and how to undo it
- [ ] T024 [P] `docs/release-notes/UNRELEASED.md` (bullets only): several displays for `set`, `remove` and `undo`; one display behaves as before; `show` stays one display
- [ ] T025 [P] Amend `specs/008-positional-display/spec.md` (FR-002, FR-004, FR-006 and the clarification on several displays, pointing to spec 010) and `specs/008-positional-display/contracts/cli.md` §1 and §2; amend `specs/007-shell-completions/contracts/cli.md` (completion of every display word of `remove` and `undo`); check `specs/001-labels-and-cli/contracts/cli.md` for a one-display statement
- [ ] T026 `Tests/live/live-syntax.sh` (with the shell-script-expert skill, small changes only): the `set` check that expected two displays to be refused becomes a check that both are labeled; add quickstart scenarios 1 to 6 and 8 for two or more displays; skip them with a message on one display; every wallpaper restored with `dnm remove` (SC-004)
- [ ] T027 `just test` and `just periphery` pass (a native build first, so periphery reads a fresh index); scan the diff for personal paths, names and UUIDs (SC-005)
- [ ] T028 Live run of `Tests/live/live-syntax.sh` on the maintainer's Mac with two or more displays, under the live-test rules (back up `Index.plist`, private `DNM_STORE_DIR`, restore with `dnm remove`), quoting `dnm --version`; quickstart scenario 7 (`--desktop` on every display) only after asking for live control and announcing it; record the results in this file (SC-004)

## Dependencies

- T001 before T007, T019, T020.
- T002 before T003 and T004; T004 before T005; T006 before T007; T008 before T009.
- Phase 2 before every story. US1 (Phase 3) and US2 (Phase 4) are independent of each other; US3 needs US1 and US2
  (its refusals run through those commands); US4 needs T006 and T011 or T015; US5 needs US1.
- Phase 8 after the stories it describes; T028 last.

## Parallel examples

- Phase 2: T005, T007 and T009 (three test files) once T004, T006 and T008 are done.
- Phase 4: T017 alongside T015 and T016 (different files).
- Phase 8: T023, T024 and T025 together.

## Implementation strategy

1. Phases 1 and 2, then User Story 1: the MVP is `set` on several displays.
2. User Story 2 (`remove`, `undo`), then the refusals (US3) and the part-way failure (US4).
3. `--desktop` (US5), then docs and the live run.
4. Release gates for 0.2.2 (independent code and security reviews, the gate record), as for 0.2.1.
