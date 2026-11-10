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

- [X] T001 Confirm the baseline on `main`: `just build`, `just test` and `just periphery` pass before any change; quote `dnm --version`
- [X] T002 Test support: in `Tests/DesktopNameCoreTests/DesktopNavigatorTests.swift`, move `FakeSwitcher` to `Tests/DesktopNameCoreTests/Support/FakeSwitcher.swift` unchanged, so the scan tests can share it
  - Done with T003: `FakeSwitcher` moved to `Support/` and extended in the same change.

## Phase 2: Foundational (blocks every story)

- [X] T003 In `Tests/DesktopNameCoreTests/Support/FakeSwitcher.swift`, let the fake hold several displays' Desktops: per display UUID, an array of wallpaper URLs (one per Desktop) and a position; `step` moves the display last pointed at (or every display when `separateSpaces` is false) and updates a linked `FakeWallpaperSystem`'s `current` for each display it moves; keep the existing single-display initializer working for `DesktopNavigatorTests`; add `interruptAtStep: Int?` that calls a closure (to raise the interrupt flag) at that step
- [X] T004 In `Sources/DesktopNameCore/Switching/DesktopNavigator.swift`, add `walk(on display:, reading: () throws -> Void) throws` (research R1): permission check (the `--desktop` message, ending "Nothing was deleted." instead of "Nothing was changed." through a parameter), point at the display, step left until nothing moves counting `lefts` (origin = lefts + 1), call `reading` at Desktop 1, step right calling `reading` after each confirmed step until a step is not confirmed (last Desktop), then return to the origin and restore the pointer; when no step moves at all (no left and the first right not confirmed), return a `WalkOutcome.nothingMoved` (the one read at the start stands) instead of throwing, and `.walked(steps:)` otherwise, so the scan can decide afterwards (spec FR-017, research R1); check `announcedChanges` against the steps taken after the walk and throw the "changed while dnm was scanning" failure (contracts/cli.md §4) without switching back; `maximumSteps` guards each loop
- [X] T005 [P] In `Tests/DesktopNameCoreTests/DesktopNavigatorTests.swift`, walk tests with the fake: starting on Desktop 1, in the middle and on the last of 4 Desktops (every Desktop read once, in order, back at the start, pointer restored); one Desktop and shortcuts off both return `.nothingMoved` after one read (the walk cannot tell them apart); not trusted (the permission message first, nothing pointed at); someone else switches mid-walk (failure, no switching back); a lost step while returning (`lostWay`); the number of steps is at most 2 × Desktops (SC-004)
- [X] T006 In `Sources/DesktopNameCore/Operations/Cleanup.swift`, add `case notOnAnyDesktop` to `CleanupReason` (raw value `"notOnAnyDesktop"`) and handle it wherever reasons are described (the report text: "not on any Desktop"); in `Sources/DesktopNameCore/Operations/Reports.swift`, add `mode` (`"age"` or `"scan"`) to `Reports.Cleanup`, make `days` optional, encoded as an explicit `"days": null` in scan mode (a custom `encode(to:)` using `encode`, not `encodeIfPresent`, so the key is never missing), and add optional `scanned: [String]?`, `notChecked: [NotChecked]?` (`display`, `labels`) and `wouldScan: [String]?` (contracts/cli.md §6); the age-based document gains only `"mode": "age"`
  - Deviation: the JSON key stays spec 009's `why`, with the value `not on any Desktop` (the contract said `reason`/`notOnAnyDesktop`; corrected after review).
- [X] T007 [P] In `Tests/dnmTests/JsonContractTests.swift` (or the existing cleanup JSON test), the age-based `cleanup --json` document has `"mode": "age"` and is otherwise unchanged

**Checkpoint**: `just test` passes; the navigator can walk every Desktop of a display in tests; nothing uses it yet.

## Phase 3: User Story 1 — Find and delete labels of deleted Desktops exactly (P1) 🎯 MVP

**Goal**: `dnm cleanup --scan` walks every Desktop of every connected display, lists the labels no Desktop shows, and deletes them on agreement.

**Independent test**: with the fake switcher, three Desktops labeled `A`, `B`, `C` on one display and `B`'s Desktop removed from the fake, the scan's candidates are exactly `B`; after deletion `A` and `C` remain with `lastSeen` updated; the display is back at its start.

- [X] T008 [US1] Create `Sources/DesktopNameCore/Operations/Scan.swift`: `ScanResult` (data-model.md: `scanned` displays in order with the file names seen on each, `seen` the union, `notConnected` with each display's recorded name and label count, `separateSpaces`); `DesktopLabeler.scan(switcher:separateSpaces:progress:)` that, when separate Spaces are on, walks each connected display in turn (calling `progress(display)` before each) reading only that display, and when off walks once pointed at the main display reading every connected display at each stop (research R3); after every walk, if any display returned `.nothingMoved` and no step was confirmed in the whole run, throw the `--desktop` "nothing moved" failure ending "Nothing was deleted." (shortcuts off or a single Desktop cannot be told apart); otherwise those displays count as one Desktop with their one read (spec FR-017)
- [X] T009 [US1] In `Sources/DesktopNameCore/Operations/Scan.swift`, the stable read (research R2): after each step, read `system.currentWallpaper(on:)`, read again after about 100 ms (turning the run loop, as `waitUntilShowing` does), and accept the file name once two consecutive reads agree, bounded by 1.5 s (then take the last read); a `nil` URL means "no labeled image"
- [X] T010 [US1] In `Sources/DesktopNameCore/Operations/Cleanup.swift`, add `scanPlan(from: ScanResult) -> CleanupPlan`: candidates are the stamps whose `displayUUID` is a scanned display and whose `fileName` is not in `seen`, active or retired, with reason `notOnAnyDesktop`, `since` = `lastSeen ?? createdAt`, size from the file (0 when missing); stamps of `notConnected` displays are never candidates (FR-004)
- [X] T011 [US1] In `Sources/DesktopNameCore/Operations/Cleanup.swift`, let `carryOut` take the scan's `seen` names: inside the exclusive change, re-read the manifest, drop candidates showing on a current Desktop now, mark `seen` ∪ shown-now with `lastSeen = now`, remove the remaining records, clear `maintenance`, then delete the files (data-model.md "Writes"); add `markSeen(_ names:)` as its own locked change for the declined or nothing-to-delete case (FR-006)
- [X] T012 [P] [US1] Create `Tests/DesktopNameCoreTests/ScanTests.swift`: the independent test above; a label shown on two Desktops (KI-1 copy) is not a candidate; a retired label shown nowhere is a candidate; a missing image file is a candidate of size 0; a label on another connected display seen only there is not a candidate; separate Spaces off (one walk, both displays read at each stop, correct result); a wallpaper that reports late (`readsBeforeSetShows`-style delay in the fake) is still read correctly; FR-017: one display with one Desktop alone → the "nothing moved" failure and no candidates; shortcuts off on two displays → the same; a main display with one Desktop beside a display with three (in either order) → both scanned, the one-Desktop display's label not a candidate (SC-002)
- [X] T013 [P] [US1] In `Tests/DesktopNameCoreTests/CleanupTests.swift`: `carryOut` after a scan re-checks (a candidate put on screen meanwhile is kept), marks seen, clears the nudge state; `markSeen` alone changes only `lastSeen`; nothing else in the manifest changes (byte-compare the rest); every existing age-based `cleanup` test in this file passes unchanged with the new `carryOut` signature
- [X] T014 [US1] In `Sources/dnm/Commands/CleanupCommand.swift`, add `@Flag(name: .long, help: "Visit every Desktop of every connected display (needs Accessibility; the Desktops slide by), then list the labels that no Desktop shows and ask before deleting them.") var scan = false`; on a terminal: check Accessibility (no output before it), print the description and estimate (contracts/cli.md §2 step 3, including the shared-Spaces wording), ask `Scan every Desktop now? [y/N]` (or `--yes`), run the scan in `MainActor.assumeIsolated` with a `SystemDesktopSwitcher` (stopped afterwards) and `NSScreen.screensHaveSeparateSpaces` read after creating the application, print `Scanning <display>…` with `Output.err` per display on a terminal (FR-016), then the report (§2 step 6), ask `Delete these N labeled images (X)? [y/N]` (or `--yes`), and `Deleted …` / `Nothing was deleted.`; nothing to delete prints `Every label of the connected displays shows on a Desktop; nothing to clean up.`
- [X] T015 [US1] Keep the command thin: the description, estimate and report text are built in core (`Reports` or `Scan.swift`) and unit-tested; the order of questions is a small core function `ScanFlow.next(after:answer:yes:terminal:json:)` returning the next step (describe, ask to scan, walk, report, ask to delete, delete, keep, describe-only exit), and `CleanupCommand` only follows it; a table test in `Tests/DesktopNameCoreTests/ScanTests.swift` shows that deletion is reached only after two yes answers or `--yes`, never with `--json` without `--yes`, never without a terminal without `--yes` (SC-005); `CommandsStayThinTests` still passes

**Checkpoint**: User Story 1 works with the fake; the command runs a real scan (checked live in Phase 8).

## Phase 4: User Story 2 — Know what the scan could not judge (P1)

**Goal**: labels of displays that are not connected are left alone and named.

**Independent test**: with stamps for a display UUID that is not connected, the scan plan lists none of them and `notConnected` names the display with its label count.

- [X] T016 [US2] In `Sources/DesktopNameCore/Operations/Scan.swift`, fill `notConnected` from the manifest (stamps whose `displayUUID` is not connected, grouped, with the recorded `displayName` or "Unknown display"); the report prints `Not checked: <display> is not connected (N labels).` for each (contracts/cli.md §2)
- [X] T017 [P] [US2] In `Tests/DesktopNameCoreTests/ScanTests.swift`: absent-display labels are never candidates and are named with their count; when only absent-display labels exist, nothing is walked for them and the report says so (User Story 2 scenarios 1-2)

**Checkpoint**: User Stories 1 and 2 work.

## Phase 5: User Story 3 — A scan that stops changes nothing (P1)

**Goal**: every failure and Ctrl-C deletes nothing and returns what it can.

**Independent test**: with the fake switcher, a failure on the second display and an interrupt at a chosen step each leave the store byte-identical, the first display back at its start, and the right message and exit status.

- [X] T018 [US3] Create `Sources/DesktopNameCore/Switching/Interrupt.swift` (research R4): `Interrupt.install()` sets a `sigaction` handler for `SIGINT` that, the first time, sets an atomic flag; when the flag is already set, writes a message prepared in advance with `write(2)` to standard error and calls `_exit(130)`; `Interrupt.prepare(display:)` is called before each display's walk and formats `Stopped; <display> may be on another Desktop.\n` into a static byte buffer (no allocation or formatting in the handler), so the line names the display (contracts/cli.md §5); `Interrupt.restore()` puts the previous handler back; `Interrupt.isRequested` reads the flag; a test hook can set the flag without a signal
- [X] T019 [US3] In `Sources/DesktopNameCore/Switching/DesktopNavigator.swift`, `walk` checks an `isInterrupted` closure before each forward step: when true, it stops reading, returns to the origin, restores the pointer and throws `DnmError.interrupted(scanned:)` (a new case with exit status 130 and the message `Stopped. Scanned: <displays>. Nothing was deleted.`, or `Stopped before any display was scanned. Nothing was deleted.` when the list is empty; the scan, not the walk, fills in the displays already finished); `scan` installs the interrupt handler around the whole walk and restores it after (FR-015)
- [X] T020 [US3] In `Sources/DesktopNameCore/Operations/Scan.swift`, on any failure after the first display, the error message adds `Scanned and returned: <displays>.` (contracts/cli.md §4); nothing is written to the store on any failure or interrupt
- [X] T021 [P] [US3] In `Tests/DesktopNameCoreTests/ScanTests.swift` and `Tests/DesktopNameCoreTests/DesktopNavigatorTests.swift`: not trusted (exit 1, nothing pointed at, nothing written); shortcuts off; someone else switches on the second display (first display returned, second not, message names both); a lost step; an interrupt at step 3 of 6 (back at the start, `interrupted` with the scanned displays, exit 130); in every case the store is byte-identical (SC-003)

**Checkpoint**: User Stories 1 to 3 work.

## Phase 6: User Story 4 — Scripts and JSON (P2)

**Goal**: without a terminal or with `--json`, nothing switches unless `--yes`.

**Independent test**: through the binary, `dnm cleanup --scan` with standard input not a terminal prints the description and `Nothing was scanned: add --yes to scan without asking.`, exits 0, and no Desktop moves.

- [X] T022 [US4] In `Sources/dnm/Commands/CleanupCommand.swift`: without a terminal and without `--yes`, print the description and `Nothing was scanned: add --yes to scan without asking.`, exit 0; with `--json` and without `--yes`, print one document with `"mode": "scan"`, `"days": null`, `"wouldScan"`, `"scanned": []`, `"deleted": false`; with `--json --yes`, scan, delete and print the document with `scanned` and `notChecked` (FR-002, FR-011); no progress lines with `--json`
- [X] T023 [P] [US4] In `Tests/dnmTests/CleanupCommandTests.swift`, through the binary with a scratch store and standard input not a terminal: `cleanup --scan` describes and exits 0; `cleanup --scan --json` prints a valid document with `wouldScan` and nothing else on standard output; neither touches the store (no manifest created). The permission check comes first (FR-001), so read whether Accessibility is granted to the test process from the `Accessibility` item's state (`ok` or `attention`) in `dnm check --json` and branch: granted → the description path above; not granted → the `--desktop` permission message, exit 1, nothing else printed
  - Every crafted store's labels belong to a display that is not connected (the tests cannot learn a real display's identity), so the binary tests cover the permission branch and the nothing-to-scan path; the describe text and the flow are covered in core (`ScanText`, `ScanFlow`).

**Checkpoint**: User Stories 1 to 4 work.

## Phase 7: User Story 5 — Clear options (P2)

**Goal**: options that do not apply are refused, not ignored.

**Independent test**: `dnm cleanup --scan --days 7` exits 2 with the contract's message, before anything else.

- [X] T024 [US5] In `Sources/dnm/Commands/CleanupCommand.swift`, make `days` an `Int?` (the default of 30 applied when absent, help text unchanged) and add `validate()`: `--scan` with `--days` (including `--days 30`) throws `--scan looks at every Desktop, so --days does not apply.` (exit 2), checked before the permission (FR-009, research R6)
- [X] T025 [P] [US5] In `Tests/dnmTests/CleanupCommandTests.swift`: `--scan --days 7` and `--scan --days 30` exit 2 with the message and nothing else; `cleanup --scan DP1` and `cleanup --scan --desktop 2` exit 2 with the parser's usage error; `cleanup --days 7` without `--scan` still works (FR-010)

**Checkpoint**: every story works with the fakes.

## Phase 8: Polish and cross-cutting

- [X] T026 [P] In `Tests/dnmTests/CompletionTests.swift`, both generated scripts offer `--scan` for `cleanup` (FR-012)
- [X] T027 [P] `README.md`: the scan (what it does, the Accessibility permission, what the person sees, Ctrl-C, displays not connected), when to prefer it over the age-based cleanup; `docs/release-notes/UNRELEASED.md` (bullets only): `dnm cleanup --scan`, and the JSON `mode` field (FR-013)
- [X] T028 [P] `specs/001-labels-and-cli/known-issues.md`: a note under KI-2 that the scan names displays that are not connected and leaves their labels alone; `specs/007-shell-completions/contracts/cli.md`: `cleanup --scan`; `specs/009-stamp-reuse-and-cleanup/contracts/cli.md`: the `(stage 2)` usage line points to `specs/012-cleanup-scan/contracts/cli.md`; the new exit status 130 (interrupted scan) in the exit-code list of `Sources/dnm/Dnm.swift`'s help discussion and in "Exit codes (FR-013)" of `specs/001-labels-and-cli/contracts/cli.md`
- [X] T029 Create `Tests/live/live-scan.sh` (with the shell-script-expert skill): checks `Index.plist` is backed up and `DNM_STORE_DIR` is private, labels three Desktops on each connected display with `--desktop`, pauses for the person to delete one labeled Desktop in Mission Control (naming which), runs `dnm cleanup --scan --yes`, and checks that exactly that label was deleted, the others remain, and each display is back on the Desktop it started on; prints the time from start to report; removes every label with `dnm remove` at the end (quickstart Live 1-2)
- [X] T030 Independent review before merge (constitution VII): a code review and a security review (the Accessibility use, the signal handler, deletion), each by a separate agent with fresh context given only the branch's diff against `main`; findings fixed (with a fresh re-review of the fixes) or accepted by the maintainer, and recorded in this file
  - Code review (fresh agent, `main...012-cleanup-scan` at `d7961fb`, 2026-11-09): 2 high, 4 medium, 4 low.
    1. High: a read error (display disconnected) counted as "shows nothing", so `--yes` could delete that display's labels. Fixed: a failed read stops the scan; the connected displays are compared at the end.
    2. High: a Ctrl-C during the last walk's final step or its way back was lost, and `--yes` deleted. Fixed: checked again after the last walk.
    3. Medium: a step that timed out but moved could end a walk early, skipping a Desktop. Fixed: a 0.5 s wait for late notices before each count check.
    4. Medium: on Ctrl-C the walk stepped back without checking the count. Fixed: the count is checked first; a mismatch is the "did not switch back" failure.
    5. Medium: two agreeing reads could accept a stale value. Fixed: three agreeing reads; a test with a two-read delay.
    6. Medium: contract §6 said `reason`/`notOnAnyDesktop`. Fixed in the contract (and spec 009's list of `why` values).
    7. Low: reaching the step limit ended a walk silently. Fixed: it fails.
    8. Low: the signal handler could run a static's one-time setup. Fixed: `install` sets them up.
    9. Low: with `--yes` the list came after the deletion. Fixed: before.
    10. Low: live script (trap after the backup, names parsed with sed, the return check could pass trivially, Desktop 3 cleanup). Fixed: trap first, names through plutil, a warning when parked on an unlabeled Desktop, a comment.
  - Security review (fresh agent, same range): 2 medium, 4 low; the same as code findings 1, 2, 7 and 8, plus: one lost key press can look like the last Desktop (low; mitigated by finding 3's wait, a full fix would need a second press at each edge, about 3 s per display, beyond SC-004); the live script hid `dnm remove` failures (fixed: it prints them and how to clean up).
  - Re-review of the fix commit `cb66f83` (fresh agent): every finding closed and every new test fails on the old code; 1 medium and 3 low new findings, all fixed in the next commit: a display that cannot be read is not stepped back (its shortcuts would switch another display), and the message says dnm did not switch back; a Ctrl-C between the walk's last check and the handler's removal is caught by `Interrupt.restore()`; the step-limit failure says when the way back failed; two wording fixes in the live script.
  - Second re-review (`3a6b4f4`): no high or medium; 3 low, fixed in the release-review commit below (the walked display is named when another display's read fails with shared Spaces; tests for a failed way back after the step limit and after a read error, which now say so).
  - Release reviews, range `v0.2.2..012-cleanup-scan` (fresh agents, 2026-11-09). Code: no critical; high = the live checks (T032, the maintainer's); 1 medium (a display where nothing moved is silently taken for one Desktop: now named in the report and in the JSON `oneDesktop`), 7 low (no undo-window note: README; the KI-2 caveat: in help; contract quotes; `--json` help; `wouldScan` with `--yes`; non-DnmError errors lost "Scanned and returned": fixed; `just release` truncated UNRELEASED.md before reading it: justfile writes a temporary file). Security: 1 medium (keys typed during the scan could answer the delete question: the terminal's input is flushed before each question), 2 low (a garbled second-Ctrl-C line if the signal lands on another thread: accepted; live-syntax.sh's trap could clean up through the quiet store: fixed). Both asked whether a read that never settles should stop the scan: it now does.
  - Re-review of `d9fb25d`: the code fixes are closed with no regression; 1 medium in the release tooling (`--stub` copied UNRELEASED.md, which had lost its comment, so the next file would keep 0.3.0's bullets): fixed in `9934044` with a fixed stub text; 3 low (stale comments: fixed; the one-Desktop line comes after the fact with `--yes`: noted; a temporary file left if `--stub` failed: cannot happen after `--check`). Re-review of `9934044`: no finding above low; its two test suggestions added.
  - Open questions for the maintainer: with "Displays have separate Spaces" off, does one step post one change notice or one per display (if one per display, every shared-Spaces scan stops safely with "changed while scanning")? Do the shortcuts move the display under the pointer (as `--desktop` assumes, checked live in spec 010)? SIGTERM or SIGHUP during a walk leave the display where it is (not handled).
- [X] T031 `just test` and `just periphery` pass (a native build first, so periphery reads a fresh index); `CommandsStayThinTests` still passes; scan the diff for personal paths, names and UUIDs
  - `just test` (364 core, 82 CLI) and `just periphery` pass after a native build; no personal paths, names or UUIDs in the diff (2026-11-09).
- [ ] T032 Quickstart by-hand scenarios 1-6, then the live scenarios 1-4 (and 5 if the maintainer can switch "Displays have separate Spaces") on the maintainer's Mac under the live-test rules and approved live control, quoting `dnm --version`; record the results in this file (SC-001, SC-004)
  - 2026-11-10, `0.3.0 build 30 (7d4952f)`, macOS 27.2, two displays (separate Spaces on), private store, `Index.plist`
    backed up. By hand 1-5 passed on 2026-11-09 (read-only).
  - Live 2 (two displays): `Tests/live/live-scan.sh` passed all 7 checks: one candidate, the deleted Desktop's label,
    deleted, both displays scanned and back on their starting Desktops. The scan took 19 s for 3 Desktops on each
    display (SC-004: under 20 s; little margin). A first attempt stopped before scanning because one Desktop of the
    second display still showed a labeled image from another store; `set` refused it and changed nothing, as designed.
  - Live 4 (Ctrl-C): a scan with one label on each display, interrupted by Ctrl-C sent to the terminal while it walked
    the first display: `Stopped before any display was scanned. Nothing was deleted.`, exit 130, both labels kept,
    both displays back on the Desktop they started on. The Ctrl-C was delivered to the terminal tab directly; a key
    press while the Desktops switch away from the terminal is still to be checked by hand.
  - Still open: by hand 6 (Accessibility off), Live 1 (one display), Live 3 (a display not connected), Live 5
    (optional).

## Dependencies

- F7 (`specs/011-quiet-flag`) is merged first: it adds the shared `-q` option to `cleanup`, the `Output` gate, and
  the 0.3.0 version bump, and this feature's progress lines rely on its kinds of standard-error text.
- T001, T002 first. T003 before T005 and every scan test; T004 before T005 and T008; T006 before T007, T010 and T022.
- Phase 2 before every story. US1 (Phase 3): T008 → T009 → T010 → T011 → T014; T012, T013 after T011.
- US2 (Phase 4) needs T008 and T010. US3 (Phase 5) needs T004 and T008; T018 before T019. US4 (Phase 6) needs T014.
  US5 (Phase 7) needs only Phase 2 and the command file (after T014, same file).
- Phase 8 after the stories it describes; T030 (review) after T029; T031 after the review's fixes; T032 last.

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
4. Version: F9 ships in 0.3.0 with F7, which is built first and bumps the version (its T001).
