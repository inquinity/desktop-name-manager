# Research: Display as a Positional Argument (Feature F8)

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## R1. Grammar options

- **A. `set [<display>] <label>` (chosen).** The maintainer's wish (`dnm set DP1 "label"`), with the display
  optional so that `dnm set "label"` still labels the main display. A parser cannot tell an optional first
  argument from the label by position alone, so the meaning follows the count: one word is the label, two are
  display and label. The cost is the lone-argument mistake (`dnm set DP1` meaning to label DP1 but forgetting
  the label), handled by refusing a lone word that is a display reference (FR-008).
- **B. `set <label> [<display>]`** (as `alias <name> [<display>]`). Parses unambiguously, but reads "set label on
  display", and the maintainer prefers the display first.
- **C. `set <display> <label>`, display required.** Unambiguous, but every one-monitor user types `main`.
- **D. Join unquoted words** (`dnm set LG Ultra my label`). Rejected by the maintainer: guessing where the display
  ends would label the wrong display; a wrong count is an error and aliases remove the need for quotes.

## R2. Parsing with swift-argument-parser

- `set` takes `@Argument var words: [String]` (zero or more) next to its options, because a variable count is
  what the grammar needs; the count is validated in `validate()` and interpreted by the core function. Options
  are still parsed anywhere on the line, so `--desktop 2` and `--style halo` can sit between the words.
- `remove`, `undo` and `show` take `@Argument var words: [String]` the same way (at most one is accepted), so
  that E5 can name the count instead of the parser's generic "unexpected argument".
- `--` ends the options, so a label such as `-x` still works.

## R3. Where the interpretation lives

One function in `DesktopNameCore` (FR-005), next to the resolver, takes the words, the `--display` value, the
connected displays and the stored aliases and returns the display value and the label or throws E1 to E5. The
test for "is a display reference" is `DisplayResolver` (exact `main`, display name or alias: the exact steps of
the resolution order without the partial step), so name matching stays in one file. The commands call both and
then call the resolver as today for the display itself.

## R4. Completion position

The generated scripts call back with the typed words. Counting arguments skips option values, so the helper knows
which options take a value (`--display`, `--desktop`, `--style`, `--color`, `--position`, `--size`); it is a small
pure function in the CLI with unit tests, not derived from the parser.

## R5. Compatibility

Only E3 changes existing behavior. `--display` keeps working, so the live scripts and any user script are
unaffected; the minor version (0.2.0) signals the E3 change.
