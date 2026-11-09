# Implementation Plan: Feature F7 — Quiet Mode

**Branch**: `011-quiet-flag` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/011-quiet-flag/spec.md`

## Summary

A `-q` / `--quiet` flag, accepted before the command name and among every command's options, and `DNM_QUIET=1`,
hold back warnings and notes on standard error and nothing else. One option group shared by the root command and
every subcommand (research R1); one gate in `Output` for warnings and notes, set once before the command runs (R2);
the cleanup nudge is not asked for at all when quiet, so it is not used up (R3). Help and completion come from the
parser (R4). No stored data, dependency, interface or permission changes.

## Technical Context

**Language/Version**: Swift 6.4

**Primary Dependencies**: `swift-argument-parser` 1.8.2 (no change)

**Storage**: none; the manifest (format 3) is unchanged

**Testing**: Swift Testing; in-process tests in `dnmTests` (the gate, the environment rule, the nudge decision,
parsing at both positions), binary tests through `CLI.run` (standard output identical with and without quiet mode,
errors identical, help text, generated completion scripts), the live script `Tests/live/live-syntax.sh`

**Target Platform**: macOS 26 or later, Apple silicon (minimum unchanged: the feature uses only the argument parser
and standard error, nothing newer than macOS 26)

**Project Type**: CLI over a shared core library (the app, M2, later)

**Performance Goals**: none new (one environment read and one flag per run)

**Constraints**: public interfaces only; no network; results, errors, questions and exit statuses unchanged
(FR-004); behavior unchanged (FR-005)

**Scale/Scope**: 11 subcommands plus the root; two warning sites and one note site today

## Constitution Check

| Principle | Result |
|---|---|
| I. Public APIs only | Pass: no system interface involved |
| II. Never require SIP changes | Pass |
| III. Least permission | Pass: no permission involved |
| IV. Local-only | Pass: no network, no telemetry |
| V. Reversible changes | Pass: quiet mode changes no state; the undo suggestion in errors is kept (FR-004) |
| VI. Distributable via Homebrew | Pass: completion files are still generated from the binary by the release script |
| VII. Tested | Pass: gate, environment and nudge unit tests; output-identity and error-identity tests through the binary; a live check |
| VIII. Public-repo hygiene | Pass: tests use synthetic names or the connected display's name at run time, never recorded |

No violations; Complexity Tracking is empty. Re-checked after Phase 1: unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/011-quiet-flag/
├── plan.md              # this file
├── research.md          # R1-R6
├── data-model.md        # no stored data; the per-run setting and the kinds of standard-error text
├── quickstart.md        # automated and live validation
├── contracts/cli.md     # the option, the environment variable, what is held back and what is not
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
Sources/dnm/GlobalOptions.swift             # New: the -q/--quiet option group; quiet(environment:) rule; protocol for commands
Sources/dnm/Dnm.swift                       # root includes GlobalOptions; main sets Output's mode after parsing
Sources/dnm/Output.swift                    # warning(_:) and note(_:), held back in quiet mode; err stays for errors
Sources/dnm/Context.swift                   # warn(_:) uses Output.warning
Sources/dnm/Nudge.swift                     # line(standardErrorIsTerminal:quiet:due:); quiet means due() is not called
Sources/dnm/Commands/*.swift                # every subcommand includes GlobalOptions; AliasCommand uses Output.warning
Tests/dnmTests/QuietModeTests.swift         # New: environment rule, gate, parsing at both positions, every subcommand accepts it
Tests/dnmTests/NudgeDecisionTests.swift     # quiet: no line, store not asked
Tests/dnmTests/CompletionTests.swift        # both scripts offer -q/--quiet at the top level and per subcommand
Tests/dnmTests/*                            # binary: stdout identical and errors identical with and without quiet mode; help text
Tests/live/live-syntax.sh                   # an overridden alias: warning without -q, none with -q and DNM_QUIET=1
README.md, docs/release-notes/UNRELEASED.md, specs/001 (contracts/cli.md: streams, short options), specs/006
(FR-012), specs/009 (nudge rules)
```

**Structure Decision**: the existing single package; one new source file and one new test file, both in the `dnm`
target (quiet mode is a command-line matter; the core library is untouched).

## Phases

1. **Option and rule**: `GlobalOptions` (help text from research R4); `quiet(environment:)` (R5); a protocol so
   `Dnm.main` reads the merged value from the parsed command; `Output.warning` and `Output.note` with the mode set
   once in `Dnm.main` before `run()`. Unit tests for the rule and the gate; parse tests for `dnm -q set`, `dnm set
   -q`, `dnm set "x" -q`, `dnm -q set -q`, and `-q` with `--help`, `--version` and `--json`.
2. **Every command**: `@OptionGroup var global: GlobalOptions` in all 11 subcommands (including `prune`, which still
   fails with its message); `Context.warn`, the alias warning loop and `Nudge` go through the gate; a test that no
   `dnm: warning:` or `dnm: note:` text is written with `Output.err` (source scan, like `onlySetAndRemoveAskForIt`).
   The `CommandsStayThinTests` tripwire still passes.
3. **Nudge**: `Nudge.line` gains `quiet`; tests that a quiet run neither prints nor asks the store (SC-005).
4. **Binary tests**: for the read-only commands and every refusal already covered by the contract tests, standard
   output and the error text and exit status are identical with `-q`, `--quiet`, `DNM_QUIET=1`, and without
   (SC-002, SC-003); with the scratch store's manifest seeded with an alias named after the connected main display
   and bound to a made-up identity (`dnm alias` refuses that name while the display is connected, but loading does
   not re-check it; checked 2026-11-09), `dnm show <name>` prints the warning without quiet mode and nothing on
   standard error with it, and `dnm alias` keeps the marker and drops the warning line (SC-001). The display name is
   read at run time and never written into the repository.
5. **Help, completion, docs**: help text; completion tests; README (quiet mode, `DNM_QUIET`, errors always shown);
   release notes; the amendments to specs 001, 006 and 009 (FR-011).
6. **Live**: `Tests/live/live-syntax.sh` gains the overridden-alias checks with a seeded store, for `set`, `remove`
   and `undo`; the leading `-q` Tab completion checked by hand in bash and zsh (quickstart).
7. **Release gates** for 0.3.0, with F9, as for earlier releases.

## Complexity Tracking

None.
