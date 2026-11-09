# Feature Specification: Quiet Mode (Feature F7)

**Feature Directory**: `specs/011-quiet-flag`

**Created**: 2026-11-09

**Status**: Draft

**Target release**: 0.3.0 (roadmap F7)

**Input**: User description: "Quiet flag (roadmap F7, 0.3.0). A global `-q` / `--quiet` option, and `DNM_QUIET=1` in the environment, that suppresses warnings only, never results or errors, on every command, so a person who already knows about a condition is not reminded on every run. The case that prompted it: alias `DP1` for one monitor while another monitor is named `DP1`; the display's name overrides the alias, so every command naming `DP1` prints the warning, and `2>/dev/null` would hide real errors too. It also silences the cleanup nudge (spec 009: the one-line note after `set` or `remove` when cleanup could free 50 MB or more). It amends the streams rule in spec 001's CLI contract and spec 006 FR-012 (which says the override warning MUST be emitted). The `(overridden by …)` marker in `dnm alias` and the `dnm check` row stay, as information that was asked for. Shell completion (spec 007) offers the option. Out of scope: hiding results or errors, a verbose flag, a config file."

## Clarifications

### Session 2026-11-09

- Q: In quiet mode, does `dnm alias` still print its separate warning line for an overridden alias? → A: No, it is
  held back like every other warning; the `(overridden by …)` marker in the list stays (FR-007).
- Q: Does a run in quiet mode count as the cleanup nudge's weekly showing? → A: No; the nudge is held back, not used
  up, and the next run that is not quiet prints it if it is still due (FR-006, User Story 3).
- Q: Where may `-q` / `--quiet` be typed? → A: Before the command name or among the command's options, with the same
  effect; help and completion cover both (FR-001, FR-009, User Story 4).

## What `dnm` prints today

Standard output holds results. Standard error holds three kinds of text:

1. **Errors**: a command that fails says why (and, for a usage error, points at `--help`), then exits non-zero.
2. **Warnings** (`dnm: warning: ...`): today only one condition, an alias whose name is also a connected display's
   name, so the display wins and the alias is not used (spec 006). It is printed by every command that resolves that
   name (`set`, `remove`, `undo`, `show`) and by `dnm alias` when it lists such an alias.
3. **Notes** (`dnm: note: ...`): today only the cleanup nudge (spec 009), after `set` or `remove`, on a terminal,
   at most weekly.

Quiet mode is about kinds 2 and 3, which repeat something the person may already know. It never touches kind 1 or
standard output.

## User Scenarios & Testing

### User Story 1 - Silence a warning I already know about (Priority: P1)

As a user with an alias that a display's name overrides, I want to run commands without the same warning every time,
without hiding real errors, so that the output shows only what is new.

**Why this priority**: it is the case that prompted the feature; today the only way out is `2>/dev/null`, which also
hides errors.

**Independent Test**: With alias `DP1` for one display and another display named `DP1` connected, run
`dnm show DP1 -q`; it prints the label result and no warning. Run `dnm show NOPE -q`; it still prints the error and
exits 2.

**Acceptance Scenarios**:

1. **Given** an overridden alias `DP1`, **When** the user runs `dnm set DP1 "Mail" --quiet`, **Then** the display
   named `DP1` is labeled, the confirmation is printed as usual, no warning is printed, and the exit status is 0.
2. **Given** the same, **When** the user runs `dnm set DP1 "Mail"` without quiet mode, **Then** the warning is
   printed as today (quiet mode is off unless asked for).
3. **Given** quiet mode, **When** a command fails (an unknown display, a usage error, a missing permission),
   **Then** the error message, any usage hint and the exit status are exactly as without quiet mode.
4. **Given** quiet mode and `--json`, **Then** standard output is the same JSON document as without quiet mode, and
   standard error has no warning.
5. **Given** `dnm alias -q` with an overridden alias, **Then** the list still shows `(overridden by connected
   display DP1)` next to the alias, and the separate warning line is not printed.

---

### User Story 2 - Turn quiet mode on for a whole session or script (Priority: P2)

As a user who always wants quiet output, I want to set it once in my shell or script, so that I do not have to add
`-q` to every command.

**Independent Test**: `DNM_QUIET=1 dnm show DP1` behaves as `dnm show DP1 -q`; `DNM_QUIET=0 dnm show DP1` behaves as
without quiet mode.

**Acceptance Scenarios**:

1. **Given** `DNM_QUIET=1` in the environment, **When** any command runs, **Then** it behaves as if `--quiet` were
   given.
2. **Given** `DNM_QUIET` unset, empty, `0` or any value other than `1`, **Then** quiet mode is off unless `-q` or
   `--quiet` is given.
3. **Given** `DNM_QUIET=1` and `--quiet` together, **Then** quiet mode is on (no error for saying it twice).

---

### User Story 3 - No cleanup reminder while quiet (Priority: P2)

As a user who has decided to deal with old labeled images later, I want quiet mode to hold back the cleanup
reminder too, without losing it for good.

**Independent Test**: With a store that makes the nudge due, run `dnm set "Mail" -q` in a terminal: no note. Then run
`dnm set "Mail"` without quiet mode: the note appears, because the quiet run did not count as having shown it.

**Acceptance Scenarios**:

1. **Given** the cleanup nudge is due, **When** the user runs `dnm set` or `dnm remove` in quiet mode, **Then** the
   note is not printed.
2. **Given** that quiet run, **When** the user next runs `dnm set` or `dnm remove` without quiet mode, **Then** the
   note is printed if it is still due; a quiet run never counts as the weekly showing.

---

### User Story 4 - Find quiet mode where I look for options (Priority: P3)

As a user, I want `-q` / `--quiet` to show up in help and in shell completion like any other option.

**Independent Test**: `dnm set --help` lists `-q, --quiet`; typing `dnm set --q` and pressing Tab completes
`--quiet` in bash and zsh.

**Acceptance Scenarios**:

1. **Given** any command's `--help`, **Then** it lists `-q, --quiet` with a one-line description that says it hides
   warnings and notes, never results or errors, and mentions `DNM_QUIET=1`.
2. **Given** bash or zsh completion installed (spec 007), **Then** `--quiet` and `-q` are offered for every command
   and before the command name, and `dnm -q se` then Tab still completes `set`.
3. **Given** `dnm --help`, **Then** it lists `-q, --quiet` as an option that may come before the command.

### Edge Cases

- **A command with nothing to warn about**: quiet mode changes nothing in its output.
- **Read-only commands** (`list`, `show`, `displays`, `check`, `about`): accept quiet mode, so it can be set once for
  everything; results on standard output are unchanged.
- **`dnm check`**: its row about an overridden alias is a result that was asked for, so it stays.
- **`dnm cleanup`**: its description of what it would delete, including the plain statement that a Desktop not on
  screen might still show an image, is part of the result and the question, not a warning; it stays. Its questions
  and its answer to a run with no terminal and no `--yes` stay too.
- **Several displays (spec 010)**: a command naming several displays prints no warning for any of them; a failure
  part-way prints the same message, with the displays already changed and the undo, as without quiet mode.
- **`--desktop`**: the explanation when the Accessibility permission is missing, and any failure while switching,
  are errors; they stay.
- **`--version` and `--help`**: unchanged by quiet mode, and accept it without error.
- **The removed `prune` command**: its message naming `cleanup` is an error (exit 2), so it stays.
- **A future warning or note**: covered by quiet mode from the start; a new kind of standard-error text has to say
  in its spec which of the three kinds it is.

## Requirements

### Functional Requirements

- **FR-001**: Every `dnm` command, and `desktop-name`, MUST accept `-q` and `--quiet` (decided here, as spec 001's
  CLI contract requires for a new short option: `-q` is the near-universal convention for quiet, means the same in
  every command, and is typed at the keyboard). It MUST be accepted both before the command name (`dnm -q set
  "Mail"`) and among the command's own options (`dnm set -q "Mail"`, `dnm set "Mail" -q`), with the same effect;
  giving it in both places is not an error.
- **FR-002**: Quiet mode MUST be on when `-q` or `--quiet` is given, or when the environment variable `DNM_QUIET` is
  exactly `1`; otherwise it MUST be off. Giving both is not an error.
- **FR-003**: In quiet mode, `dnm` MUST NOT print warnings (`dnm: warning: ...`) or notes (`dnm: note: ...`).
- **FR-004**: Quiet mode MUST NOT change standard output (including `--json` documents), any error message or usage
  hint, any question asked before a change, or any exit status.
- **FR-005**: Quiet mode MUST NOT change what a command does: the same labels, wallpapers, stored records and undo
  records as without it.
- **FR-006**: A cleanup nudge held back by quiet mode MUST NOT count as shown: the next run that is not quiet, and
  for which the nudge is due, prints it.
- **FR-007**: `dnm alias` MUST still mark an overridden alias in its list, and `dnm check` MUST still report it; only
  the separate warning line is held back.
- **FR-008**: Each command's help MUST list `-q, --quiet` and say that it hides warnings and notes but never results
  or errors, and that `DNM_QUIET=1` does the same.
- **FR-009**: Shell completion for bash and zsh (spec 007) MUST offer `-q` and `--quiet` for every command and
  before the command name, and completion of the command name and its arguments MUST work the same after a leading
  `-q`.
- **FR-010**: The README MUST describe quiet mode and `DNM_QUIET`, and say that errors are always printed.
- **FR-011** (amendments): Spec 001's CLI contract streams rule MUST say that warnings and notes on standard error
  are held back in quiet mode, and its short-options rule MUST record `-q` as decided. Spec 006 FR-012 MUST say the
  override warning is printed unless quiet mode is on. Spec 009's nudge rules MUST add quiet mode to the cases where
  the nudge is not printed and not counted.

### Key Entities

- **Quiet mode**: a per-run setting, from the command line or the environment; nothing is stored.
- **Standard-error text kinds**: error, warning, note. Quiet mode holds back warnings and notes only.

## Success Criteria

### Measurable Outcomes

- **SC-001**: With an overridden alias, a command in quiet mode prints nothing on standard error when it succeeds,
  checked for `set`, `remove`, `undo`, `show` and `alias`.
- **SC-002**: For every error case covered by the existing contract tests, the message and exit status in quiet mode
  are identical to those without it.
- **SC-003**: For every command, standard output in quiet mode is byte-for-byte identical to standard output without
  it, for the same inputs and state.
- **SC-004**: A user who has an overridden alias can drop `2>/dev/null` from their commands and still see every
  error.
- **SC-005**: After a quiet run with the nudge due, the next run that is not quiet shows the nudge.

## Assumptions

- `DNM_QUIET` accepts only `1` as "on", so `DNM_QUIET=0` or an empty value cannot turn it on by surprise. No other
  spellings (`true`, `yes`) are accepted; there is no "off" override for an environment that sets it, since
  `DNM_QUIET= dnm ...` or `unset DNM_QUIET` already does that.
- No setting is stored: a config file is out of scope, and the app (M2) has its own interface.
- No verbose mode is added, and quiet mode never hides results or errors.
- Spec 009's nudge already never prints when standard error is not a terminal; quiet mode adds one more case and
  changes nothing else about it.
