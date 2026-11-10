---
description: "Task list for feature F7: quiet mode"
---

# Tasks: Feature F7 — Quiet Mode

**Input**: `specs/011-quiet-flag/` (spec.md, plan.md, research.md, data-model.md, contracts/cli.md, quickstart.md)

**Tests**: included (the spec's SC-001 to SC-005 ask for them).

**Rules for every task**: no test changes a real wallpaper (in-process tests and read-only commands through the
binary, each with a scratch store); the connected display's name is read at run time and never written into the
repository; synthetic names (`DP1`, `main`) in docs; build and test with `just` (`build.noindex/`). Only the `dnm`
target changes; `DesktopNameCore` is untouched.

## Phase 1: Setup

- [X] T001 Confirm the baseline on `main`: `just build`, `just test` and `just periphery` pass before any change, and quote `dnm --version`; then run `just bump minor` so `Version.xcconfig` reads 0.3.0 (F7 lands before F9, which shares the release), and commit it with the first change

## Phase 2: Foundational (blocks every story)

- [X] T002 Create `Sources/dnm/GlobalOptions.swift`: `struct GlobalOptions: ParsableArguments` with `@Flag(name: .shortAndLong, help: "Hide warnings and notes; results and errors are always shown. DNM_QUIET=1 does the same.") var quiet = false`, and a protocol `HasGlobalOptions { var global: GlobalOptions { get } }` (research R1, contracts/cli.md §1)
- [X] T003 In `Sources/dnm/Output.swift`, add the quiet setting (`nonisolated(unsafe) static var quiet = false`, documented as written once in `Dnm.main` before the command runs), `warning(_:)` printing `dnm: warning: <text>` and `note(_:)` printing `dnm: note: <text>` to standard error unless quiet (both add their own prefix, research R2), through a pure `static func shouldPrint(_ kind: Kind, quiet: Bool) -> Bool` (`Kind`: `.warning`, `.note`); `err` stays for errors and is never gated (research R2, data-model.md "Kinds of standard-error text")
- [X] T004 In `Sources/dnm/Dnm.swift`, add `@OptionGroup var global: GlobalOptions` to `Dnm` and conform it to `HasGlobalOptions`; in `main()`, after `parseAsRoot()` and before `run()`, set `Output.quiet` from the parsed command's `global.quiet` when it conforms to `HasGlobalOptions` (research R1, R2)
- [X] T005 Add `@OptionGroup var global: GlobalOptions` and `HasGlobalOptions` to all 11 subcommands in `Sources/dnm/Commands/` (`Set`, `Remove`, `Undo`, `Show`, `List`, `Displays`, `Alias`, `Cleanup`, `Prune`, `About`, `Check`); `prune` still fails with its message naming `cleanup` (contracts/cli.md §1). Done for the 10 visible commands and `dnm`; `prune` instead takes `-q` through its pass-through argument (a known flag right after its name clashed with that argument in the parser), which keeps `dnm prune -q` and `dnm -q prune` on its message
- [X] T006 [P] Create `Tests/dnmTests/QuietModeTests.swift` with in-process parse tests (`Dnm.parseAsRoot`): `-q set x`, `set -q x`, `set x -q`, `-q set -q x`, `--quiet show`, and every subcommand with `-q` parse with `global.quiet == true`; without it, `false`; a label or `--label` value that is literally `-q` after `--` stays a label (FR-001)
- [X] T007 [P] In `Tests/dnmTests/QuietModeTests.swift`, a table test of `Output.shouldPrint(_:quiet:)`: both kinds print with quiet off and do not with quiet on; the test never sets `Output.quiet` (it is process-wide and tests run in parallel); that `err` is never gated is covered by T010 and the binary tests (FR-003, FR-004)

**Checkpoint**: `just test` passes; every command accepts `-q` before or after its name; nothing is held back yet.

## Phase 3: User Story 1 — Silence a warning I already know about (P1) 🎯 MVP

**Goal**: with an overridden alias, `-q` hides the warning and nothing else.

**Independent test**: with a scratch store seeded with an alias named after the connected main display, `dnm show <name> -q` prints the result and nothing on standard error; `dnm show NOPE -q` prints its error and exits 2.

- [X] T008 [US1] In `Sources/dnm/Context.swift`, make `warn(_:)` call `Output.warning(notice)` instead of `Output.err("dnm: warning: ...")` (FR-003)
- [X] T009 [US1] In `Sources/dnm/Commands/AliasCommand.swift`, print the overridden-alias line with `Output.warning("alias \(name) is not used while a display named \(by) is connected.")`; the `(overridden by connected display …)` marker in the list on standard output is unchanged (FR-007, clarification Q1)
- [X] T010 [P] [US1] In `Tests/dnmTests/QuietModeTests.swift`, a source scan of `Sources/dnm` (like `NudgeDecisionTests.onlySetAndRemoveAskForIt`): no `Output.err` call contains `warning:` or `note:` (FR-003, spec edge case "A future warning or note")
- [X] T011 [US1] In `Tests/dnmTests/QuietModeTests.swift`, binary tests through `CLI.run`, enabled only when a display is connected: seed the scratch store's `manifest.json` with `{"schemaVersion":3,"stamps":[],"changes":[],"aliases":[{"name":"<main display name>","displayUUID":"ELSEWHERE","displayName":"Elsewhere"}]}`, the name read from `dnm displays --json` at run time; then `show <name>` warns without quiet mode; with `-q`, `--quiet` and `-q` before `show`, standard error is empty, standard output and exit status are identical; `--json` output is identical; `dnm alias` keeps the marker and, with `-q`, has no warning line (SC-001, User Story 1 scenarios 1-5)
- [X] T012 [P] [US1] In `Tests/dnmTests/QuietModeTests.swift`, error identity through the binary: for the refusals already covered by the contract tests (an unknown display, a usage error such as `dnm -q set`, an invalid label, `dnm prune`), the standard error text and exit status with `-q` equal those without it (SC-002, FR-004)
- [X] T013 [P] [US1] In `Tests/dnmTests/QuietModeTests.swift`, output identity through the binary for the read-only commands (`list`, `displays`, `show`, `check`, `about`, `alias`, each with and without `--json` where it has it): standard output with `-q` is byte-for-byte that without it (SC-003)

**Checkpoint**: User Story 1 works on its own: `-q` hides the override warning, everything else is unchanged.

## Phase 4: User Story 2 — Turn quiet mode on for a whole session or script (P2)

**Goal**: `DNM_QUIET=1` acts as `-q`; any other value does nothing.

**Independent test**: `DNM_QUIET=1 dnm show <name>` behaves as `dnm show <name> -q`; `DNM_QUIET=0` behaves as without it.

- [X] T014 [US2] In `Sources/dnm/GlobalOptions.swift`, add `static func quiet(flag: Bool, environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool`: true when `flag`, or when `environment["DNM_QUIET"] == "1"` exactly; "Any other value (unset, empty, `0`, `true`, ...) leaves quiet mode off; it is never an error" (contracts/cli.md §2, research R5); `Dnm.main` uses it to set `Output.quiet`
- [X] T015 [P] [US2] In `Tests/dnmTests/QuietModeTests.swift`, a table test of `quiet(flag:environment:)`: unset, `""`, `"0"`, `"true"`, `"yes"`, `" 1"`, `"1"`, each with the flag off and on (FR-002)
- [X] T016 [US2] In `Tests/dnmTests/QuietModeTests.swift`, extend the T011 binary test: `DNM_QUIET=1` (set in the process environment that `CLI.run` passes) hides the warning; `DNM_QUIET=0` does not; `DNM_QUIET=1` with `-q` is not an error (User Story 2 scenarios 1-3); add an `environment` parameter to `CLI.run` in `Tests/dnmTests/CLI.swift` if needed

**Checkpoint**: User Stories 1 and 2 work.

## Phase 5: User Story 3 — No cleanup reminder while quiet (P2)

**Goal**: quiet mode holds the reminder back without using it up.

**Independent test**: `Nudge.line` with quiet on returns nothing and never asks the store.

- [X] T017 [US3] In `Sources/dnm/Nudge.swift`, change `line(standardErrorIsTerminal:due:)` to `line(standardErrorIsTerminal:quiet:due:)`: when `quiet` is true, return `nil` without calling `due()`, exactly as without a terminal; the line it returns no longer starts with `dnm: note: ` (now added by `Output.note`), and `showIfDue` passes `Output.quiet` and prints with `Output.note`, so the text on screen is unchanged (FR-006, research R3, clarification Q2)
- [X] T018 [P] [US3] In `Tests/dnmTests/NudgeDecisionTests.swift`, update the existing tests to the new signature and to the line without its `dnm: note: ` prefix, and add: quiet on a terminal with a reminder due prints nothing and does not ask the store (`asked == false`); quiet off still prints the line (SC-005)

**Checkpoint**: User Stories 1 to 3 work.

## Phase 6: User Story 4 — Find quiet mode where I look for options (P3)

**Goal**: `-q, --quiet` in every help screen and in bash and zsh completion, before the command name and for every command.

**Independent test**: `dnm --help` and `dnm set --help` list `-q, --quiet`; both generated completion scripts offer it at the top level and per command.

- [X] T019 [P] [US4] In `Tests/dnmTests/QuietModeTests.swift`, through the binary: `dnm --help` and each subcommand's `--help` contain `-q, --quiet` and the text `Hide warnings and notes; results and errors are always shown. DNM_QUIET=1 does the same.` (FR-008, contracts/cli.md §1)
- [X] T020 [P] [US4] In `Tests/dnmTests/CompletionTests.swift`, for `zsh` and `bash`: the generated script offers `--quiet` and `-q` at the top level and in each subcommand's section, and the existing display completions are unchanged (FR-009, contracts/cli.md §6)

**Checkpoint**: every story works.

## Phase 7: Polish and cross-cutting

- [ ] T021 [P] `README.md`: quiet mode (`-q` / `--quiet` before or after the command name, `DNM_QUIET=1`), what it hides (warnings and notes, including the cleanup reminder) and that results and errors always show; the overridden-alias example (FR-010)
- [ ] T022 [P] `docs/release-notes/UNRELEASED.md` (bullets only): quiet mode and `DNM_QUIET=1`
- [ ] T023 [P] Amend `specs/001-labels-and-cli/contracts/cli.md` (the streams rule, as in `specs/011-quiet-flag/contracts/cli.md` §5; the short-options rule: `-q` decided by spec 011), `specs/006-display-aliases/spec.md` FR-012 ("unless quiet mode is on, spec 011"), and `specs/009-stamp-reuse-and-cleanup/spec.md` (the nudge Q&A: not in quiet mode, and a quiet run does not count) (FR-011)
- [ ] T024 `Tests/live/live-syntax.sh` (with the shell-script-expert skill, small changes only): seed the private store with an overridden alias for the main display (as T011); `set`, `remove` and `undo` on it print the warning without quiet mode and an empty standard error with `-q`, `dnm -q ...` and `DNM_QUIET=1`; labels applied and removed as without quiet mode, with `dnm list` and `dnm show` reporting the same state after a quiet run as after one without (this is the check of FR-005 for commands that change wallpapers, which the automated tests cannot run); every wallpaper restored with `dnm remove`
- [ ] T025 `just test` and `just periphery` pass (a native build first, so periphery reads a fresh index); `CommandsStayThinTests` still passes; scan the diff for personal paths, names and UUIDs (the alias in the seeded store uses the made-up identity `ELSEWHERE`, not a UUID, so the hygiene scan stays clean)
- [ ] T026 Independent review before merge (constitution VII): a code review and a security review, each by a separate agent with fresh context given only the branch's diff against `main`; findings fixed (with a fresh re-review of the fixes) or accepted by the maintainer, and recorded in this file
- [ ] T027 Quickstart by-hand scenarios 1 to 10 (no wallpaper change; scenario 10 is Tab completion in bash and zsh at the keyboard) and a live run of `Tests/live/live-syntax.sh` on the maintainer's Mac under the live-test rules (back up `Index.plist`, private `DNM_STORE_DIR`, restore with `dnm remove`), quoting `dnm --version`; record the results in this file

## Dependencies

- T001 first. T002 before T003-T005; T003 and T004 before T006-T007; T005 before T006.
- Phase 2 before every story. US1 (Phase 3) first: T008 and T009 before T011; T011 before T016.
- US2 (Phase 4) and US3 (Phase 5) are independent of each other and need only Phase 2 (T016 also needs T011).
- US4 (Phase 6) needs only Phase 2 (T002 holds the help text).
- Phase 7 after the stories it describes; T026 (review) after T025; T027 last, after the review's fixes.

## Parallel examples

- Phase 2: T006 and T007 together once T005 is done.
- Phase 3: T010, T012 and T013 alongside T011.
- After Phase 2: Phase 4 (T014-T016), Phase 5 (T017-T018) and Phase 6 (T019-T020) can proceed side by side, each in
  its own files except `QuietModeTests.swift`, which T015, T016 and T019 share (append, do not rewrite).
- Phase 7: T021, T022 and T023 together.

## Implementation strategy

1. **MVP**: Phases 1-3. `-q` hides the override warning and changes nothing else; it is useful on its own.
2. Add US2 (`DNM_QUIET`) and US3 (the reminder), then US4's help and completion checks.
3. Polish: docs, spec amendments, the live script and the live run.
4. Version: F7 ships in 0.3.0 with F9 and is built first, so T001 runs `just bump minor` (research R6).
