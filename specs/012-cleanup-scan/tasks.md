---
description: "Task list for feature F9: dnm cleanup --scan"
---

# Tasks: Feature F9 — `dnm cleanup --scan`

**Input**: `specs/012-cleanup-scan/` (spec.md, plan.md, research.md, data-model.md, contracts/cli.md, quickstart.md)

**Tests**: included (the spec's SC-001 to SC-006 ask for them).

**Rules for every task**: no automated test switches a real Desktop or changes a real wallpaper (the fake wallpaper
system, a fake switcher and a temporary store only); synthetic display names (`Built-in Display`, `DP1`, `Studio
Display`) in tests and docs; public interfaces only; build and test with `just` (`build.noindex/`). Live runs need
live control, asked for and announced first (`say "Requesting lyve control"`, then `say "Completed using lyve
control"`).

## Phase 1: Setup

- [ ] T001 Confirm the baseline on `main`: `just build`, `just test` and `just periphery` pass before any change; quote `dnm --version`
- [ ] T002 Test support: in `Tests/DesktopNameCoreTests/DesktopNavigatorTests.swift`, move `FakeSwitcher` to `Tests/DesktopNameCoreTests/Support/FakeSwitcher.swift` unchanged, so the scan tests can share it

## Phase 2: Foundational (blocks every story)

- [ ] T003 In `Tests/DesktopNameCoreTests/Support/FakeSwitcher.swift`, let the fake hold several displays' Desktops: per display UUID, an array of wallpaper URLs (one per Desktop) and a position; `step` moves the display last pointed at (or every display when `separateSpaces` is false) and updates a linked `FakeWallpaperSystem`'s `current` for each display it moves; keep the existing single-display initializer working for `DesktopNavigatorTests`; add `interruptAtStep: Int?` that calls a closure (to raise the interrupt flag) at that step
- [ ] T004 In `Sources/DesktopNameCore/Switching/DesktopNavigator.swift`, add `walk(on display:, reading: () throws -> Void) throws` (research R1): permission check (the `--desktop` message, ending "Nothing was deleted." instead of "Nothing was changed." through a parameter), point at the display, step left until nothing moves counting `lefts` (origin = lefts + 1), call `reading` at Desktop 1, step right calling `reading` after each confirmed step until a step is not confirmed (last Desktop), then return to the origin and restore the pointer; when `lefts == 0` and the first step right is not confirmed, the display has one Desktop only if a probe cannot tell: use `visit`'s rule (step right and back) and throw `nothingMoved` when nothing moves at all; check `announcedChanges` against the steps taken after the walk and throw the "changed while dnm was scanning" failure (contracts/cli.md §4) without switching back; `maximumSteps` guards each loop
- [ ] T005 [P] In `Tests/DesktopNameCoreTests/DesktopNavigatorTests.swift`, walk tests with the fake: starting on Desktop 1, in the middle and on the last of 4 Desktops (every Desktop read once, in order, back at the start, pointer restored); one Desktop (read once, no error); shortcuts off (`nothingMoved`, nothing read after the first); not trusted (the permission message first, nothing pointed at); someone else switches mid-walk (failure, no switching back); a lost step while returning (`lostWay`); the number of steps is at most 2 × Desktops (SC-004)
- [ ] T006 In `Sources/DesktopNameCore/Operations/Cleanup.swift`, add `case notOnAnyDesktop` to `CleanupReason` (raw value `"notOnAnyDesktop"`) and handle it wherever reasons are described (the report text: "not on any Desktop"); in `Sources/DesktopNameCore/Operations/Reports.swift`, add `mode` (`"age"` or `"scan"`) to `Reports.Cleanup`, make `days` optional (`null` in scan mode), and add optional `scanned: [String]?`, `notChecked: [NotChecked]?` (`display`, `labels`) and `wouldScan: [String]?` (contracts/cli.md §6); the age-based document gains only `"mode": "age"`
- [ ] T007 [P] In `Tests/dnmTests/JsonContractTests.swift` (or the existing cleanup JSON test), the age-based `cleanup --json` document has `"mode": "age"` and is otherwise unchanged

**Checkpoint**: `just test` passes; the navigator can walk every Desktop of a display in tests; nothing uses it yet.

## Phase 3: User Story 1 — Find and delete labels of deleted Desktops exactly (P1) 🎯 MVP

**Goal**: `dnm cleanup --scan` walks every Desktop of every connected display, lists the labels no Desktop shows, and deletes them on agreement.

**Independent test**: with the fake switcher, three Desktops labeled `A`, `B`, `C` on one display and `B`'s Desktop removed from the fake, the scan's candidates are exactly `B`; after deletion `A` and `C` remain with `lastSeen` updated; the display is back at its start.

- [ ] T008 [US1] Create `Sources/DesktopNameCore/Operations/Scan.swift`: `ScanResult` (data-model.md: `scanned` displays in order with the file names seen on each, `seen` the union, `notConnected` with each display's recorded name and label count, `separateSpaces`); `DesktopLabeler.scan(switcher:separateSpaces:progress:)` that, when separate Spaces are on, walks each connected display in turn (calling `progress(display)` before each) reading only that display, and when off walks once pointed at the main display reading every connected display at each stop (research R3)
- [ ] T009 [US1] In `Sources/DesktopNameCore/Operations/Scan.swift`, the stable read (research R2): after each step, read `system.currentWallpaper(on:)`, read again after about 100 ms (turning the run loop, as `waitUntilShowing` does), and accept the file name once two consecutive reads agree, bounded by 1.5 s (then take the last read); a `nil` URL means "no labeled image"
- [ ] T010 [US1] In `Sources/DesktopNameCore/Operations/Cleanup.swift`, add `scanPlan(from: ScanResult) -> CleanupPlan`: candidates are the stamps whose `displayUUID` is a scanned display and whose `fileName` is not in `seen`, active or retired, with reason `notOnAnyDesktop`, `since` = `lastSeen ?? createdAt`, size from the file (0 when missing); stamps of `notConnected` displays are never candidates (FR-004)
- [ ] T011 [US1] In `Sources/DesktopNameCore/Operations/Cleanup.swift`, let `carryOut` take the scan's `seen` names: inside the exclusive change, re-read the manifest, drop candidates showing on a current Desktop now, mark `seen` ∪ shown-now with `lastSeen = now`, remove the remaining records, clear `maintenance`, then delete the files (data-model.md "Writes"); add `markSeen(_ names:)` as its own locked change for the declined or nothing-to-delete case (FR-006)
- [ ] T012 [P] [US1] Create `Tests/DesktopNameCoreTests/ScanTests.swift`: the independent test above; a label shown on two Desktops (KI-1 copy) is not a candidate; a retired label shown nowhere is a candidate; a missing image file is a candidate of size 0; a label on another connected display seen only there is not a candidate; separate Spaces off (one walk, both displays read at each stop, correct result); a wallpaper that reports late (`readsBeforeSetShows`-style delay in the fake) is still read correctly (SC-002)
- [ ] T013 [P] [US1] In `Tests/DesktopNameCoreTests/CleanupTests.swift`: `carryOut` after a scan re-checks (a candidate put on screen meanwhile is kept), marks seen, clears the nudge state; `markSeen` alone changes only `lastSeen`; nothing else in the manifest changes (byte-compare the rest)
- [ ] T014 [US1] In `Sources/dnm/Commands/CleanupCommand.swift`, add `@Flag(name: .long, help: "Visit every Desktop of every connected display (needs Accessibility; the Desktops slide by), then list the labels that no Desktop shows and ask before deleting them.") var scan = false`; on a terminal: check Accessibility (no output before it), print the description and estimate (contracts/cli.md §2 step 3, including the shared-Spaces wording), ask `Scan every Desktop now? [y/N]` (or `--yes`), run the scan in `MainActor.assumeIsolated` with a `SystemDesktopSwitcher` (stopped afterwards) and `NSScreen.screensHaveSeparateSpaces` read after creating the application, print `Scanning <display>…` with `Output.err` per display on a terminal (FR-016), then the report (§2 step 6), ask `Delete these N labeled images (X)? [y/N]` (or `--yes`), and `Deleted …` / `Nothing was deleted.`; nothing to delete prints `Every label of the connected displays shows on a Desktop; nothing to clean up.`
- [ ] T015 [US1] Keep the command thin: the description, estimate and report text are built in core (`Reports` or `Scan.swift`) and unit-tested; `CommandsStayThinTests` still passes

**Checkpoint**: User Story 1 works with the fake; the command runs a real scan (checked live in Phase 8).

## Phase 4: User Story 2 — Know what the scan could not judge (P1)

**Goal**: labels of displays that are not connected are left alone and named.

**Independent test**: with stamps for a display UUID that is not connected, the scan plan lists none of them and `notConnected` names the display with its label count.

- [ ] T016 [US2] In `Sources/DesktopNameCore/Operations/Scan.swift`, fill `notConnected` from the manifest (stamps whose `displayUUID` is not connected, grouped, with the recorded `displayName` or "Unknown display"); the report prints `Not checked: <display> is not connected (N labels).` for each (contracts/cli.md §2)
- [ ] T017 [P] [US2] In `Tests/DesktopNameCoreTests/ScanTests.swift`: absent-display labels are never candidates and are named with their count; when only absent-display labels exist, nothing is walked for them and the report says so (User Story 2 scenarios 1-2)

**Checkpoint**: User Stories 1 and 2 work.

## Phase 5: User Story 3 — A scan that stops changes nothing (P1)

**Goal**: every failure and Ctrl-C deletes nothing and returns what it can.

**Independent test**: with the fake switcher, a failure on the second display and an interrupt at a chosen step each leave the store byte-identical, the first display back at its start, and the right message and exit status.

- [ ] T018 [US3] Create `Sources/DesktopNameCore/Switching/Interrupt.swift` (research R4): `Interrupt.install()` sets a `sigaction` handler for `SIGINT` that, the first time, sets an atomic flag; when the flag is already set, writes `Stopped; the display may be on another Desktop.\n` with `write(2)` to standard error and calls `_exit(130)`; `Interrupt.restore()` puts the previous handler back; `Interrupt.isRequested` reads the flag; a test hook can set the flag without a signal
- [ ] T019 [US3] In `Sources/DesktopNameCore/Switching/DesktopNavigator.swift`, `walk` checks an `isInterrupted` closure before each forward step: when true, it stops reading, returns to the origin, restores the pointer and throws `DnmError.interrupted(scanned:)` (a new case with exit status 130 and the message `Stopped. Scanned: <displays>. Nothing was deleted.`); `scan` installs the interrupt handler around the whole walk and restores it after (FR-015)
- [ ] T020 [US3] In `Sources/DesktopNameCore/Operations/Scan.swift`, on any failure after the first display, the error message adds `Scanned and returned: <displays>.` (contracts/cli.md §4); nothing is written to the store on any failure or interrupt
- [ ] T021 [P] [US3] In `Tests/DesktopNameCoreTests/ScanTests.swift` and `Tests/DesktopNameCoreTests/DesktopNavigatorTests.swift`: not trusted (exit 1, nothing pointed at, nothing written); shortcuts off; someone else switches on the second display (first display returned, second not, message names both); a lost step; an interrupt at step 3 of 6 (back at the start, `interrupted` with the scanned displays, exit 130); in every case the store is byte-identical (SC-003)

**Checkpoint**: User Stories 1 to 3 work.

## Phase 6: User Story 4 — Scripts and JSON (P2)

**Goal**: without a terminal or with `--json`, nothing switches unless `--yes`.

**Independent test**: through the binary, `dnm cleanup --scan` with standard input not a terminal prints the description and `Nothing was scanned: add --yes to scan without asking.`, exits 0, and no Desktop moves.

- [ ] T022 [US4] In `Sources/dnm/Commands/CleanupCommand.swift`: without a terminal and without `--yes`, print the description and `Nothing was scanned: add --yes to scan without asking.`, exit 0; with `--json` and without `--yes`, print one document with `"mode": "scan"`, `"days": null`, `"wouldScan"`, `"scanned": []`, `"deleted": false`; with `--json --yes`, scan, delete and print the document with `scanned` and `notChecked` (FR-002, FR-011); no progress lines with `--json`
- [ ] T023 [P] [US4] In `Tests/dnmTests/CleanupCommandTests.swift`, through the binary with a scratch store and standard input not a terminal: `cleanup --scan` describes and exits 0; `cleanup --scan --json` prints a valid document with `wouldScan` and nothing else on standard output; neither touches the store (no manifest created). The permission check comes first (FR-001), so read whether Accessibility is granted to the test process from the `Accessibility` item's state (`ok` or `attention`) in `dnm check --json` and branch: granted → the description path above; not granted → the `--desktop` permission message, exit 1, nothing else printed

**Checkpoint**: User Stories 1 to 4 work.

## Phase 7: User Story 5 — Clear options (P2)

**Goal**: options that do not apply are refused, not ignored.

**Independent test**: `dnm cleanup --scan --days 7` exits 2 with the contract's message, before anything else.

- [ ] T024 [US5] In `Sources/dnm/Commands/CleanupCommand.swift`, make `days` an `Int?` (the default of 30 applied when absent, help text unchanged) and add `validate()`: `--scan` with `--days` (including `--days 30`) throws `--scan looks at every Desktop, so --days does not apply.` (exit 2), checked before the permission (FR-009, research R6)
- [ ] T025 [P] [US5] In `Tests/dnmTests/CleanupCommandTests.swift`: `--scan --days 7` and `--scan --days 30` exit 2 with the message and nothing else; `cleanup --scan DP1` and `cleanup --scan --desktop 2` exit 2 with the parser's usage error; `cleanup --days 7` without `--scan` still works (FR-010)

**Checkpoint**: every story works with the fakes.

## Phase 8: Polish and cross-cutting

- [ ] T026 [P] In `Tests/dnmTests/CompletionTests.swift`, both generated scripts offer `--scan` for `cleanup` (FR-012)
- [ ] T027 [P] `README.md`: the scan (what it does, the Accessibility permission, what the person sees, Ctrl-C, displays not connected), when to prefer it over the age-based cleanup; `docs/release-notes/UNRELEASED.md` (bullets only): `dnm cleanup --scan`, and the JSON `mode` field (FR-013)
- [ ] T028 [P] `specs/001-labels-and-cli/known-issues.md`: a note under KI-2 that the scan names displays that are not connected and leaves their labels alone; `specs/007-shell-completions/contracts/cli.md`: `cleanup --scan`; `specs/009-stamp-reuse-and-cleanup/contracts/cli.md`: the `(stage 2)` usage line points to `specs/012-cleanup-scan/contracts/cli.md`
- [ ] T029 Create `Tests/live/live-scan.sh` (with the shell-script-expert skill): checks `Index.plist` is backed up and `DNM_STORE_DIR` is private, labels three Desktops on each connected display with `--desktop`, pauses for the person to delete one labeled Desktop in Mission Control (naming which), runs `dnm cleanup --scan --yes`, and checks that exactly that label was deleted, the others remain, and each display is back on the Desktop it started on; prints the time from start to report; removes every label with `dnm remove` at the end (quickstart Live 1-2)
- [ ] T030 `just test` and `just periphery` pass (a native build first, so periphery reads a fresh index); `CommandsStayThinTests` still passes; scan the diff for personal paths, names and UUIDs
- [ ] T031 Quickstart by-hand scenarios 1-6, then the live scenarios 1-4 (and 5 if the maintainer can switch "Displays have separate Spaces") on the maintainer's Mac under the live-test rules and approved live control, quoting `dnm --version`; record the results in this file (SC-001, SC-004)

## Dependencies

- T001, T002 first. T003 before T005 and every scan test; T004 before T005 and T008; T006 before T007, T010 and T022.
- Phase 2 before every story. US1 (Phase 3): T008 → T009 → T010 → T011 → T014; T012, T013 after T011.
- US2 (Phase 4) needs T008 and T010. US3 (Phase 5) needs T004 and T008; T018 before T019. US4 (Phase 6) needs T014.
  US5 (Phase 7) needs only Phase 2 and the command file (after T014, same file).
- Phase 8 after the stories it describes; T029 before T031; T031 last.

## Parallel examples

- Phase 2: T005 and T007 once T004 and T006 are done.
- Phase 3: T012 and T013 together after T011.
- After US1: US2 (T016-T017) and US3 (T018-T021) side by side; they share `Scan.swift`, so T016 and T020 are applied
  in turn, not at once.
- Phase 8: T026, T027 and T028 together.

## Implementation strategy

1. **MVP**: Phases 1-3 (with Phase 5's interrupt before any live run, since a live walk without Ctrl-C handling is
   the behavior the maintainer rejected).
2. Then US2 (absent displays), US4 (scripts and JSON), US5 (refusals).
3. Polish, the live script, the live runs in each display configuration.
4. Version: F9 ships in 0.3.0 with F7; whichever lands first runs `just bump minor`.
