---
description: "Task list for feature F8: display as a positional argument"
---

# Tasks: Feature F8 — Display as a Positional Argument

**Input**: `specs/008-positional-display/` (spec.md, plan.md, research.md, contracts/cli.md, quickstart.md)

**Tests**: included. The decisions in `spec.md` are made.

## Phase 0: Spike

- [x] T000 Spike: optional positionals followed by an array with options interleaved; the scripts' positions; `--display` as `[String]` shows a repeat; `@testable import dnm` for in-process parsing. Done 2026-10-09, all confirmed; result in `research.md` R2. `Tests/dnmTests/CommandParsingTests.swift` exists.

## Phase 1: Core (US1 to US3)

- [x] T001 `DisplayResolver.isReference(_:in:aliases:)` built from the resolver's own matchers: exact `main`, connected display name, or any alias name, ignoring case (FR-008)
- [x] T002 `Sources/DesktopNameCore/Displays/DisplayArguments.swift`: the two tables of `contracts/cli.md` §2, resolving the display once and returning it with the override warning; every error of §3, with suggestions shell-quoted by one small function (`research.md` R4b) (FR-001 to FR-008)
- [x] T003 [P] `Tests/DesktopNameCoreTests/DisplayArgumentsTests.swift`: a table of every invocation in `spec.md` (legitimate and error) with its outcome; shell quoting of suggestions (space, `$`, single and double quote, empty, non-ASCII); digits; `main` and `Main`; partial names; overridden and absent aliases; the same display twice; `--label` rules (SC-001)

## Phase 2: Commands (US1 to US4)

- [x] T004 `DisplayOption` as `[String]`; `Context.resolveDisplay` reworked; `set` with `first`, `second`, `extra`, `--label` and a custom usage line; `remove`, `undo`, `show` with `first`, `extra` and custom usage (FR-001, FR-002, FR-004)
- [x] T005 [P] `Tests/dnmTests/PositionalDisplayTests.swift`: each error case against the binary (exit 2, standard error, nothing created); `show` by display name and by alias equals `--display`; in-process parse tests of `set` with options between and around the words; a test that fails if a file under `Sources/dnm/Commands` calls the resolver or compares display names (SC-003, SC-004); no test changes a wallpaper

## Phase 3: Completion (spec 007)

- [x] T006 Completion by position: first word of the four commands offers displays and usable aliases; second word of `set` and `--label` offer nothing (FR-009)
- [x] T007 [P] Tests of the callback by position in `CompletionTests.swift`

## Phase 4: Documentation and verification

- [x] T008 [P] README (grammar, `--label` and `--label=-x` for a dash-leading label, aliases to avoid quotes, scripts use `--display` and `--label`; every example writes the display before the label, FR-012; one line that `dnm alias` reads like a shell alias, new name first then what it stands for, while `set` reads display then label; a note that a label equal to an alias or display name needs `--label` or `main`); release notes with the two changes of behavior (FR-010, FR-011)
- [x] T009 [P] Amend spec 001 FR-023 and `contracts/cli.md`, spec 006 FR-011, spec 007 `contracts/cli.md`
- [x] T010 `just test` and `just periphery` pass (SC-004)
- [ ] T011 Quickstart read-only scenarios and Tab; live scenarios with the `Index.plist` backup and restore (SC-002)
- [x] T012 (written 2026-10-10; syntax-checked, shellcheck-clean, dry run; the live run is the maintainer's, with the `Index.plist` backup) The positional syntax suite, live: `Tests/live/live-syntax.sh`, in the style of `live-desktops.sh` (colors, `--dry-run`, `Index.plist` backup and restore, live-control announcements). On every connected display (one, two or three): label, show, undo and remove by exact name, by a unique part of the name, by alias and by `main`, as a word, as `--display`, and with `--label`; then the multi-display syntax that must be refused (a word plus `--display`, `--display` repeated, `--display` repeated with different displays), each exiting 2 with nothing changed. Also run once in each display configuration you have.
