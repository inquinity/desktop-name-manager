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
- **E. A short flag `-d`** (`dnm set -d DP1 "label"`). Unambiguous and state-independent, but `-d` already means
  delete in `dnm alias` and is read as `--desktop`; the positional form is the short form anyway. Not added
  (open decision 2); another letter could be chosen later.
- **F. A named `--label`** (`dnm set DP1 --label "x"`). Added: it removes every doubt about which word is which,
  for scripts and for labels that equal a display or alias name.
- **D. Join unquoted words** (`dnm set LG Ultra my label`). Rejected by the maintainer: guessing where the display
  ends would label the wrong display; a wrong count is an error and aliases remove the need for quotes.

## R2. Parsing with swift-argument-parser

- `set` takes three positional arguments, `first: String?`, `second: String?` and `extra: [String]`, next to its
  options. Separate arguments (not one list) let the generated completion scripts supply each position (as they
  already do for `alias`), so no code of ours counts words or knows which options take a value. `extra` exists so
  that we, not the parser, report too many words, with our message. `remove`, `undo` and `show` take
  `first: String?` and `extra: [String]`. To be confirmed by a spike in the first task (optional arguments
  followed by an array, with options interleaved).
- `--display` becomes an array option (`[String]`, single values), so that a repeat is seen and refused; today a
  `String?` option keeps the last value silently (checked 2026-10-09).
- Errors are `DnmError` thrown from `run`, like every other message, not `ValidationError` from `validate()` (the
  parser adds its own "Run `dnm --help`" line to those).
- A custom `usage:` string in each `CommandConfiguration` shows the real grammar.
- `--` ends the options, so a label such as `-x` still works.

## R3. Where the interpretation lives

One function in `DesktopNameCore` (FR-005), next to the resolver, takes the words, the `--display` and `--label`
values, the connected displays and the stored aliases, and returns the resolved display (with its override
warning) and the label, or throws the errors of the contract. It resolves the display itself, once, so there is no
second lookup, no double warning and no change of the display list between a check and the real resolve. The
test for "is a display reference" is in `DisplayResolver`: exact `main`, display name or any alias name. An alias
of an absent display counts as a reference although resolution would fail for it, so the two share private
matchers (name equality, alias equality) instead of copying the rules.

## R4. Completion position

With separate positional arguments the scripts call back with `positional@0`, `positional@1` and so on (as for
`alias`), so the first word offers displays and the second offers nothing, with no counting of our own. (An
earlier idea, a helper that counts words and skips option values, would have copied knowledge the parser owns.)

## R5. Compatibility

Two things change: a lone word that is a display reference is refused, and a repeated `--display` is an error.
`--display` otherwise keeps working, so the live scripts and user scripts are unaffected; the minor version
(0.2.0) signals the change. Because positional use depends on the connected displays and stored aliases (whether
a lone word is refused), the README tells scripts to use `--display` and `--label`.
