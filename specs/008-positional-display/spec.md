# Feature Specification: Display as a Positional Argument (Feature F8)

**Feature Directory**: `specs/008-positional-display`

**Created**: 2026-10-09

**Status**: Draft

**Target release**: 0.2.0 (a change of syntax, so a minor version; every later feature moves back, see `ROADMAP.md`)

**Input**: User description: "With several monitors the display is the main selector, and I change labels on main least often. Make the display a first-class parameter: `dnm set DP1 "label..."`, `dnm set main "label2..."`. Displays have spaces, so `dnm set "LG Ultra" "My label is great"` must work. A wrong number of arguments is an error; aliases are the way to avoid quotes."

## Clarifications

### Session 2026-10-09

- **Q: What is the new grammar?**
  - **A**: The display is an optional first argument:
    - `dnm set [<display>] <label>`: one argument is the label for the main display; two arguments are a display and a label.
    - `dnm remove [<display>]`, `dnm undo [<display>]`, `dnm show [<display>]`.
    - `--display <name>` stays, as an equivalent. `--desktop` and every other option are unchanged and may come before, between or after the arguments.
- **Q: What does `<display>` accept?**
  - **A**: Exactly what `--display` accepts today, through the one resolution algorithm (spec 006 FR-011, FR-019): `main`, an exact display name, an exact alias, or a unique partial display name; a display's own name overrides an alias, with the same warning. Names with spaces are quoted, as the shell requires: `dnm set "LG Ultra" "My label is great"`.
- **Q: What if the display is given twice (argument and `--display`)?**
  - **A**: An error (exit 2), even when both name the same display: "Give the display once, as an argument or with --display." With `--display`, `set` takes exactly one argument, the label.
- **Q: What if a wrong number of arguments is given?**
  - **A**: An error, never a guess (maintainer decision). `set` with three or more arguments: "set takes a label, or a display and a label; quote anything with spaces", with the alias tip. `remove`, `undo` and `show` with two or more arguments: "<command> takes at most one display; quote a name with spaces". The tip: an alias avoids the quotes (`dnm alias lg "LG Ultra"`, then `dnm set lg "My label"`).
- **Q: `dnm set Mail Inbox`: two arguments, but `Mail` is no display. What happens?**
  - **A**: The first argument is resolved as a display, and the usual error is shown ("No display matches ..."), plus, for `set`, the hint that a label with several words is quoted as one argument: `dnm set "Mail Inbox"`.
- **Q: `dnm set DP1`: one argument that is also a display. What happens?**
  - **A**: Refused (exit 2), because it is probably a label forgotten after the display. The message gives both forms: `dnm set DP1 "<label>"` to label that display, and `dnm set main DP1` to use it as the label. The rule applies to a lone argument that equals `main`, a connected display's name, or any alias, exactly and ignoring case; a partial name is not a display here, so `dnm set LG` is a label. It does not apply when `--display` is given (the argument is then the label).
- **Q: This changes what `dnm set DP1` does. Is that acceptable?**
  - **A**: Yes: it is why this is 0.2.0. Before, `dnm set DP1` labeled the main display "DP1". The release notes say so.
- **Q: Does Tab follow the new grammar (spec 007)?**
  - **A**: Yes. The first argument of `set`, `remove`, `undo` and `show` offers `main`, the connected displays and the usable aliases (as `--display` does); the second argument of `set` (the label) offers nothing. `set` cannot know whether a first argument will be a display or a label, so it offers displays there and the person may type a label instead.
- **Q: Do other commands change?**
  - **A**: No. `alias <name> [<display>]` already takes its display positionally; `list`, `displays`, `prune`, `about` and `check` do not choose a display.

---

## User Scenarios & Testing

### User Story 1 - Label a display by naming it (Priority: P1)

As a user with several monitors, I want to name the display first, as in `dnm set DP1 "label"`, so that the common case is short.

**Independent Test**: With a display named `DP`, run `dnm set DP "Mail"`; that display's current Desktop shows the label. Run `dnm set "Built-in Retina Display" "Notes"` and `dnm set main "Notes"`.

**Acceptance Scenarios**:
1. **Given** displays `Built-in Retina Display` and `LG Ultra HD`, **When** the user runs `dnm set "LG Ultra" "My label is great"`, **Then** the partial name resolves to the LG display and it is labeled, the label keeping its spaces.
2. **Given** an alias `lg` for the LG display, **When** the user runs `dnm set lg "My label"`, **Then** the LG display is labeled.
3. **Given** one argument, **When** the user runs `dnm set "Mail"` (and `Mail` is neither `main` nor a display nor an alias), **Then** the main display is labeled, as today.
4. **Given** the options `--style`, `--position`, `--size`, `--color` and `--desktop`, **When** they are mixed with the arguments in any order, **Then** they apply as before.
5. **Given** a display's own name equals an alias, **When** it is given as the first argument, **Then** the display wins and the same warning as for `--display` is printed.

---

### User Story 2 - Show, remove and undo by naming the display (Priority: P1)

As a user, I want `dnm show DP1`, `dnm remove DP1` and `dnm undo DP1` to work the same way.

**Independent Test**: `dnm show DP --json` prints the label details of that display; `dnm remove "LG Ultra"` removes its label.

**Acceptance Scenarios**:
1. **Given** no argument, **When** the user runs `dnm show`, **Then** the main display is used, as today.
2. **Given** `dnm remove DP1` and `dnm undo DP1`, **Then** they act on that display's current Desktop (or the Desktop given with `--desktop`).
3. **Given** two arguments, **When** the user runs `dnm show DP1 DP2`, **Then** it exits 2 saying a command takes at most one display.

---

### User Story 3 - Clear errors, no guessing (Priority: P1)

As a user, I want a mistake in the arguments to be an error that tells me what to type, never a label on the wrong display.

**Independent Test**: Run each error case below; each exits 2, changes nothing and prints the hint.

**Acceptance Scenarios**:
1. **Given** `dnm set LG Ultra "label"` (an unquoted name with a space), **Then** exit 2: "set takes a label, or a display and a label; quote anything with spaces", with the alias tip.
2. **Given** `dnm set Mail Inbox` where `Mail` is no display, **Then** exit 2: no display matches `Mail`, with the quoting hint for a label.
3. **Given** `dnm set DP1` where `DP1` is a connected display, **Then** exit 2 giving both explicit forms; nothing is labeled.
4. **Given** `dnm set DP1 "x" --display DP2` or `dnm show DP1 --display DP2`, **Then** exit 2: give the display once.
5. **Given** `dnm set` with no label, **Then** exit 2 as today (a label is required).

---

### User Story 4 - Keep `--display` (Priority: P2)

As a user with scripts, I want `--display` to keep working.

**Acceptance Scenarios**:
1. **Given** `dnm set "Mail" --display DP1`, **Then** it behaves as before.
2. **Given** `dnm show --display DP1`, **Then** it behaves as before.
3. **Given** the `Tests/live` scripts, which use `--display`, **Then** they need no change.

---

## Edge Cases

- **A label that equals a display or alias** is written with the explicit form `dnm set main "<label>"` or `dnm set --display main "<label>"`.
- **Digits**: `dnm set 2 "x"` fails as before (numbered displays are not accepted); a lone `dnm set 2` labels the main display "2" (a number is not a display).
- **A label starting with `-`**: after `--`, as today (`dnm set -- "-x"`, or with a display `dnm set DP1 -- "-x"`).
- **A display name that is also a sensible label** (`dnm set Mail Inbox` when a display is named `Mail`): the display wins; quote the label (`dnm set "Mail Inbox"`) or use `--display`.
- **An alias for a display that is not connected** as the first argument: the usual error ("The display aliased as ... is not connected").
- **`main` as a lone argument** is a display reference: `dnm set main` is refused; `dnm set main main` labels the main display "main".
- **`--desktop`** is unchanged and still needs the Accessibility permission.

---

## Requirements

### Functional Requirements

- **FR-001**: `dnm set` MUST accept `[<display>] <label>`: one argument is the label (for the main display, or the one given with `--display`); two arguments are a display and a label.
- **FR-002**: `dnm remove`, `dnm undo` and `dnm show` MUST accept an optional `<display>` argument.
- **FR-003**: A display argument MUST be resolved by the single resolution algorithm in its full mode (spec 006 FR-011, FR-019), including the override warning. No command may interpret a display argument itself.
- **FR-004**: `--display` MUST remain, with its present behavior. Giving the display both ways MUST be an error (exit 2) even if both name the same display.
- **FR-005**: The interpretation of the arguments (how many, which is the display, which is the label, the refusals) MUST live in one function in the core library, used by `set`, `remove`, `undo` and `show`, and unit-tested there.
- **FR-006**: `set` with three or more arguments, and `remove`, `undo` or `show` with two or more, MUST exit 2, change nothing, and say to quote anything with spaces and to use an alias.
- **FR-007**: `set` with two arguments whose first does not resolve MUST exit 2 with the resolver's error plus the hint that a label of several words is one quoted argument.
- **FR-008**: `set` with one argument and without `--display` MUST refuse (exit 2, nothing changed) when that argument equals `main`, a connected display's name, or any alias's name, exactly and ignoring case, and MUST name both explicit forms. Partial names and numbers are not references here. The test for "is a display reference" MUST be in the resolver, not in the command.
- **FR-009**: Tab (spec 007) MUST offer displays and usable aliases for the first argument of `set`, `remove`, `undo` and `show`, and nothing for the second argument of `set`.
- **FR-010**: Command help, the README, the release notes and the CLI contracts MUST show the new grammar; spec 001 FR-023 and its CLI contract, and spec 006 FR-011, MUST say the display may be given as an argument.
- **FR-011**: The release notes MUST say that `dnm set <word>` where the word is `main`, a display or an alias is now refused where it used to label the main display.

---

## Success Criteria

- **SC-001**: Every example in this specification behaves as written, and every error case exits 2 and changes nothing.
- **SC-002**: Every existing `--display` invocation (the live scripts, the README before this change) behaves as before.
- **SC-003**: The display is interpreted in exactly one place (the argument function and the resolver); the commands contain no matching or counting of their own.
- **SC-004**: `just test` and `just periphery` pass; the contract tests cover each error case against the built binary without changing a wallpaper.

## Assumptions

- A shell passes a quoted name as one argument, so the tool cannot (and does not try to) join unquoted words: a wrong count is an error (maintainer decision, 2026-10-09).
- Aliases (spec 006) are the answer to display names that are tedious to quote.
- `--display` stays indefinitely; removing it is not proposed.
