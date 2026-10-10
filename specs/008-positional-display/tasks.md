---
description: "Task list for feature F8: display as a positional argument"
---

# Tasks: Feature F8 — Display as a Positional Argument

**Input**: `specs/008-positional-display/` (spec.md, plan.md, research.md, contracts/cli.md, quickstart.md)

**Tests**: included.

## Phase 1: Core (US1 to US3)

- [ ] T001 `DisplayResolver.isReference(_:in:aliases:)`: exact `main`, connected display name, or any alias name, ignoring case (FR-008)
- [ ] T002 `Sources/DesktopNameCore/Displays/DisplayArguments.swift`: the interpretation table of `contracts/cli.md` §2 and errors E1 to E5 (FR-001 to FR-008)
- [ ] T003 [P] Unit tests in `Tests/DesktopNameCoreTests/DisplayArgumentsTests.swift`: every row of the table, E1 to E5 messages, quoting and alias hints, digits, `main`, partial names, overridden and absent aliases, the same display twice

## Phase 2: Commands (US1 to US4)

- [ ] T004 `set`: `words` argument, validation, interpretation, `--display` unchanged (FR-001, FR-004)
- [ ] T005 `remove`, `undo`, `show`: `words` argument (at most one), same interpretation (FR-002, FR-006)
- [ ] T006 [P] Contract tests in `Tests/dnmTests/PositionalDisplayTests.swift`: E1 to E5 against the binary (exit 2, standard error, nothing created); `show` by display name and by alias equals `--display`; no test changes a wallpaper

## Phase 3: Completion (spec 007)

- [ ] T007 Argument counting that skips option values, and first-argument completion for the four commands; nothing for the second argument of `set` (FR-009)
- [ ] T008 [P] Tests for the counting helper and the callback in `CompletionTests.swift`

## Phase 4: Documentation and verification

- [ ] T009 [P] Help text of the four commands; README (grammar, aliases to avoid quotes); release notes with the E3 change (FR-010, FR-011)
- [ ] T010 [P] Amend spec 001 FR-023 and `contracts/cli.md`, spec 006 FR-011, spec 007 `contracts/cli.md`
- [ ] T011 `just test` and `just periphery` pass (SC-004)
- [ ] T012 Quickstart read-only scenarios 1 to 4 and 9; live scenarios 5 to 8 with the `Index.plist` backup and restore
