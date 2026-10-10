---
description: "Task list for feature F8: display as a positional argument"
---

# Tasks: Feature F8 — Display as a Positional Argument

**Input**: `specs/008-positional-display/` (spec.md, plan.md, research.md, contracts/cli.md, quickstart.md)

**Tests**: included. Two decisions are open in `spec.md` (the lone-word refusal, and no short flag); T002 and T004
wait on the first.

## Phase 0: Spike

- [ ] T000 Confirm in a throwaway branch or test: optional positionals followed by an array with options interleaved; `positional@N` for each in the generated zsh and bash scripts; `--display` as `[String]` shows a repeat; `@testable import dnm` works for in-process parsing. Record the result in `research.md` R2.

## Phase 1: Core (US1 to US3)

- [ ] T001 `DisplayResolver.isReference(_:in:aliases:)` built from the resolver's own matchers: exact `main`, connected display name, or any alias name, ignoring case (FR-008)
- [ ] T002 `Sources/DesktopNameCore/Displays/DisplayArguments.swift`: the two tables of `contracts/cli.md` §2, resolving the display once and returning it with the override warning; every error of §3, quoting words that contain spaces in suggestions (FR-001 to FR-008)
- [ ] T003 [P] `Tests/DesktopNameCoreTests/DisplayArgumentsTests.swift`: a table of every invocation in `spec.md` (legitimate and error) with its outcome; quoting of suggestions for names with spaces; digits; `main` and `Main`; partial names; overridden and absent aliases; the same display twice; `--label` rules (SC-001)

## Phase 2: Commands (US1 to US4)

- [ ] T004 `DisplayOption` as `[String]`; `Context.resolveDisplay` reworked; `set` with `first`, `second`, `extra`, `--label` and a custom usage line; `remove`, `undo`, `show` with `first`, `extra` and custom usage (FR-001, FR-002, FR-004)
- [ ] T005 [P] `Tests/dnmTests/PositionalDisplayTests.swift`: each error case against the binary (exit 2, standard error, nothing created); `show` by display name and by alias equals `--display`; in-process parse tests of `set` with options between and around the words; a test that fails if a file under `Sources/dnm/Commands` calls the resolver or compares display names (SC-003, SC-004); no test changes a wallpaper

## Phase 3: Completion (spec 007)

- [ ] T006 Completion by position: first word of the four commands offers displays and usable aliases; second word of `set` and `--label` offer nothing (FR-009)
- [ ] T007 [P] Tests of the callback by position in `CompletionTests.swift`

## Phase 4: Documentation and verification

- [ ] T008 [P] README (grammar, `--label`, aliases to avoid quotes, scripts use `--display` and `--label`); release notes with the two changes of behavior (FR-010, FR-011)
- [ ] T009 [P] Amend spec 001 FR-023 and `contracts/cli.md`, spec 006 FR-011, spec 007 `contracts/cli.md`
- [ ] T010 `just test` and `just periphery` pass (SC-004)
- [ ] T011 Quickstart read-only scenarios and Tab; live scenarios with the `Index.plist` backup and restore (SC-002)
