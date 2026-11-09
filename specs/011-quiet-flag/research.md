# Research: Quiet Mode (Feature F7)

## R1. Accepting `-q` before and after the command name

- **Decision**: one `ParsableArguments` type, `GlobalOptions`, holding `@Flag(name: .shortAndLong) var quiet`,
  included with `@OptionGroup` in the root command (`Dnm`) and in every subcommand.
- **Rationale**: `swift-argument-parser` 1.8.2 merges the values of the same option group across the command stack.
  A probe built against the project's own checkout (2026-11-09) gave `quiet=true` for `-q sub a`, `sub -q a`,
  `sub a -q`, `-q sub -q a` and `--quiet sub a`, and `quiet=false` for `sub a`. The root's and each subcommand's help
  list `-q, --quiet`, and the generated zsh and bash completion scripts offer it at both levels.
- **Alternatives considered**: `@ParentCommand` in each subcommand (works for `dnm -q set`, but hides the option
  from the subcommand's help and does not accept it after the command name); reading `CommandLine.arguments` for
  `-q` (wrong for a label or value that is literally `-q`, and bypasses the parser's errors).

## R2. One place that decides whether a warning or note is printed

- **Decision**: `Output` gains `warning(_:)` and `note(_:)` (prefixes `dnm: warning: ` and `dnm: note: `) and a
  `quiet` setting, set once in `Dnm.main` after parsing and before the command runs. Every warning and note goes
  through them; `Output.err` stays for errors only. `Context.warn`, the `dnm alias` warning loop and `Nudge` call
  the new functions.
- **Rationale**: the spec makes "warning" and "note" kinds of standard-error text that quiet mode holds back as a
  class (FR-003, and the edge case for future warnings). One gate, plus a test that no `dnm: warning:` or `dnm: note:`
  text is written through `Output.err`, keeps a later warning from escaping quiet mode.
- **How quiet is read**: the root command and each subcommand conform to a small protocol exposing `global`;
  `Dnm.main` reads it from the parsed command (`parseAsRoot()` returns the leaf command, whose option group holds the
  merged value). The environment check (`DNM_QUIET` exactly `1`) is a pure function taking the environment, like
  `Store.defaultDirectory(environment:)`, so it is unit-tested without changing the process environment.
- **Concurrency**: the CLI is single-threaded and sets the value once before any output; the setting is a
  `nonisolated(unsafe) static var` (or a `MainActor` value) documented as written once. Tests of the gate pass the
  mode in rather than flip the global.
- **Alternatives considered**: passing quiet through `Context` (the alias warning and parse-time paths have no
  `Context`, and every new caller would have to remember it); suppressing in each command (repeats the rule).

## R3. The nudge in quiet mode

- **Decision**: `Nudge.line` takes `quiet` beside `standardErrorIsTerminal`; when quiet, it returns `nil` without
  calling `due()`, exactly as it does without a terminal.
- **Rationale**: `due()` is `labeler.nudgeIfDue()`, which records the showing; not calling it is what keeps a
  quiet run from counting (FR-006, SC-005). The existing test "without a terminal the store is not even asked" is
  the model for the new one.

## R4. Help and completion

- **Decision**: no hand-written completion change. The release script generates the zsh and bash scripts from the
  binary (`--generate-completion-script`), so the option appears wherever the parser accepts it. `CompletionTests`
  gains checks that both scripts offer `--quiet` and `-q` at the top level and for each subcommand, and that a
  leading `-q` does not stop subcommand completion. `CompletionTests` reads the generated script text and does not
  run a shell, so the leading-`-q` case is checked by hand at the keyboard in the quickstart (bash and zsh).
- **Help text**: "Hide warnings and notes; results and errors are always shown. DNM_QUIET=1 does the same."

## R5. `DNM_QUIET` values

- **Decision**: on only when the value is exactly `1` (spec Assumptions). Unset, empty, `0`, `true` and anything
  else leave quiet mode off, silently.
- **Rationale**: an environment that sets `DNM_QUIET=0` must not turn it on; accepting more spellings invites
  disagreement about which ones count.

## R6. Version

- **Decision**: F7 is planned for 0.3.0 with F9. `Version.xcconfig` reads 0.2.3 after the 0.2.2 release; `just bump
  minor` moves it to 0.3.0 when the first 0.3.0 feature lands. Not part of this feature's tasks unless F7 is first.
