---
description: "Task list for feature F2: display aliases"
---

# Tasks: Feature F2 — Display Aliases

**Input**: Design documents from `specs/006-display-aliases/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [contracts/cli.md](contracts/cli.md), [data-model.md](data-model.md), [research.md](research.md), [quickstart.md](quickstart.md)

**Tests**: Included. Unit tests in `DesktopNameCoreTests` and contract tests in `dnmTests`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on unfinished tasks)
- **[Story]**: User story from `spec.md` (US1 to US4)
- Paths follow the project structure in `plan.md`

---

## Phase 1: Foundational (Core Model & Store)

**Purpose**: Data model, schema versions, and alias operations.

- [x] T001 [US1] Create `DisplayAlias` (`name`, `displayUUID`, `displayName?`; no timestamp) and name validation in `Sources/DesktopNameCore/Model/DisplayAlias.swift` (length 1–30; ASCII alphanumeric, `-`, `_`; reject only-digit names, `main`, spaces and special characters, with the messages in `contracts/cli.md` §2).
- [x] T002 [US1] Update `Manifest` in `Sources/DesktopNameCore/Model/Stamp.swift`: add `aliases` (decoded with `decodeIfPresent … ?? []`), set `currentSchemaVersion = 2`; every save writes version 2 (FR-017).
- [x] T003 [US1] Update the version check in `Sources/DesktopNameCore/Store/Store.swift` to read versions 1 and 2 and refuse newer ones. No alias methods on `Store`.
- [x] T004 [US1] Add alias operations on `DesktopLabeler` in `Sources/DesktopNameCore/Operations/Aliases.swift`: `aliases()` (read only, never creates the store), `setAlias` (returns created, unchanged or moved-from; stores the new capitalization and the display's name), `removeAlias`; all writes in `Store.transaction`.
- [x] T005 [US3] In `setAlias`, refuse a display whose identity is the `no-uuid-…` fallback or is reported by another connected display, and a name equal to a connected display's name (FR-004, FR-016).
- [x] T006 [P] [US1] Unit tests in `Tests/DesktopNameCoreTests/DisplayAliasTests.swift`: name validation; a version 1 manifest decodes with no aliases and is saved as version 2; a version 3 manifest is refused.
- [x] T007 [P] [US1] Unit tests in `Tests/DesktopNameCoreTests/AliasOperationTests.swift`: create, unchanged, move (with capitalization change), remove, missing alias, and the identity refusals of T005, with the fake wallpaper system.

---

## Phase 2: User Story 1 - Create and Use a Display Alias (P1)

**Purpose**: Enable setting an alias and resolving it with `--display <value>`.

- [x] T008 [US1] Update `DisplayResolver.resolve` in `Sources/DesktopNameCore/Displays/DisplayResolver.swift` to take a full or display-only mode and apply the order in FR-011: exact display name, then exact alias (full mode only; not connected → exit 2), then partial name. It stays the only display resolution in the code (FR-019).
- [x] T009 [US1] Update `Sources/dnm/Context.swift` to read aliases from the store and pass them to `DisplayResolver`.
- [x] T010 [US1] Implement `dnm alias <name> [<display>]` in `Sources/dnm/Commands/AliasCommand.swift`: defaults to `main`; resolves the display with `DisplayResolver` in display-only mode (FR-003, FR-019); prints `Aliased …` or `Moved alias … from … to …` without quotes (FR-007, FR-014).
- [x] T011 [US1] Register `AliasCommand.self` in `Sources/dnm/Dnm.swift`.
- [x] T012 [US1] Update the `--display` help in `Sources/dnm/DisplayOption.swift` to mention aliases.
- [x] T013 [P] [US1] Contract tests in `Tests/dnmTests/AliasCommandTests.swift`: alias on main and on a named display, the same command again, moving an alias, and `--display <alias>` with `set`, `show`, `remove` and `undo`; an alias `LG` resolves while `LG` is part of two display names (US1 scenario 5); a partial alias (`des` for `desk`) does not resolve.

---

## Phase 3: User Story 2 - List and Remove Display Aliases (P2)

**Purpose**: View configured aliases (text and JSON) and delete aliases.

- [x] T014 [US2] Implement removal in `AliasCommand.swift` (`--remove`), printing `Removed alias <name>.` or exiting 2 if not found.
- [x] T015 [US2] Implement listing (bare `dnm alias`): aligned columns of alias, display (connected name, else recorded name, else identity) and status; `No aliases. …` when there are none.
- [x] T016 [US2] Implement `dnm alias --json` as `{"aliases": [...]}` (contract §3) in `Sources/DesktopNameCore/Operations/Reports.swift` and `AliasCommand.swift`; `--json` with a name is invalid input.
- [x] T017 [P] [US2] Contract tests for listing (connected, not connected, no name recorded), `--json`, `--json` with a name, and `--remove` (success and error paths).

---

## Phase 4: User Story 3 - Collision Handling and Overrides (P3)

**Purpose**: Precedence, collision prevention on creation, and override warnings.

- [x] T018 [US3] In `DisplayResolver`, when an exact display name also matches an alias, return the display and an override warning; `Context` prints it to stderr.
- [x] T019 [US3] Mark overridden aliases in the listing as `(overridden by connected display <name>)` and print the warning to stderr.
- [x] T020 [P] [US3] Unit tests in `DisplayResolverTests.swift` for both modes (display-only ignores aliases), the DP1 case (alias `DP1` → LG Ultra HD while a display named `DP1` is connected: `DP1` reaches the display, `LG Ultra` reaches the LG), and contract tests in `AliasCommandTests.swift` for the collision refusal, overrides precedence and warnings.

---

## Phase 5: User Story 4 - Integration with `dnm displays` and `dnm check` (P4)

**Purpose**: Surface aliases in existing display inspection commands.

- [x] T021 [US4] Add `aliases: [String]` to `Reports.Display` in `Sources/DesktopNameCore/Operations/Reports.swift` (always present, empty when none; overridden aliases left out).
- [x] T022 [US4] Update `Sources/dnm/Commands/DisplaysCommand.swift` to print `aliases: a, b` after the name and main marker (contract §5).
- [x] T023 [US4] Add the Aliases row to `check` in `Sources/DesktopNameCore/Operations/Check.swift` (contract §6) and update the expected rows in `AboutCheckTests.swift` and `SetOptionsContractTests.swift`.
- [x] T024 [P] [US4] Contract tests for `dnm displays` text and JSON and the `check` Aliases row.

---

## Phase 6: Documentation

- [x] T025 Amend spec 001: FR-023 and `specs/001-labels-and-cli/contracts/cli.md` with the `--display` resolution order including aliases (FR-018).
- [x] T026 [P] README: aliases in the `--display` description and a short `dnm alias` section.
- [x] T027 [P] `docs/release-notes/UNRELEASED.md`: `dnm alias`, and that the store moves to schema 2, which older releases refuse.
- [x] T028 [P] Roadmap feature map: link F2 to this spec (done with the review, 2026-10-08).

---

## Phase 7: Polish & Verification

- [x] T029 Run `just test` and verify all unit and contract tests pass.
- [x] T030 Run `just periphery` and verify no unused code.
- [x] T031 Manual validation with `specs/006-display-aliases/quickstart.md` and a temporary `DNM_STORE_DIR`; quote `dnm --version`. Done 2026-10-09 on `0.1.0 (1) 3aef7d9+`: scenarios 1 and 3-8 (override checked with a hand-made manifest). Scenario 2 (`set`/`remove` on the real wallpaper) is not run: it needs the `Index.plist` backup and restore.
