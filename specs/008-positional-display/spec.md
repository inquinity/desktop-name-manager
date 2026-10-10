# Feature Specification: Display as a Positional Argument (Feature F8)

**Feature Directory**: `specs/008-positional-display`

**Created**: 2026-10-09 | **Revised**: 2026-10-09 (after a critical review)

**Status**: Draft (decisions below are made; short options for other flags are still being discussed)

**Target release**: 0.2.0 (it changes what two kinds of command line mean, so a minor version; every later feature moves back, see `ROADMAP.md`)

**Input**: User description: "With several monitors the display is the main selector, and I change labels on main least often. Make the display a first-class parameter: `dnm set DP1 "label..."`, `dnm set main "label2..."`. Displays have spaces, so `dnm set "LG Ultra" "My label is great"` must work. A wrong number of arguments is an error; aliases are the way to avoid quotes. A fully named `--label` is allowed. Repeating `--display` is not accepted (several displays belong to batch labeling, F3)."

## Decisions (maintainer, 2026-10-09)

1. **A lone word that is a display is refused** (`dnm set DP1`): exact `main`, display name or alias only. Decided; no further discussion.
2. **No short flag for `--display`.** `-d` is taken (it means delete in `dnm alias`, and people read it as `--desktop`); the positional form is the short form, which is the strongest argument for it.
3. **The short `-d` of `dnm alias` is removed** (done on `main` on 2026-10-09, shipped in 0.2.0), and the CLI keeps only `-h` and, later, `-q` as short options; the rule is in spec 001's CLI contract.
4. **Documentation shows the display before the label.** The order is encouraged, not required (any order works): examples read `dnm set DP1 "LabelX"` and `dnm set --display DP1 --label "LabelX"`, not `dnm set "LabelX" --display DP1`.

## Clarifications

### Session 2026-10-09

- **Q: What is the new grammar?**
  - **A**: The display is an optional first word, and the label can also be named:
    - `dnm set [<display>] <label>`: one word is the label (for the main display); two words are a display and a label.
    - `dnm set [<display>] --label <text>`: fully named; the one optional word is the display.
    - `dnm remove [<display>]`, `dnm undo [<display>]`, `dnm show [<display>]`.
    - `--display <name>` stays as an equivalent for the display word. `--desktop` and the other options are unchanged. Options may come before, between or after the words (the parser already allows this; checked 2026-10-09).
- **Q: Are all of these legitimate?**
  - **A**: Yes: `dnm set DP1 labelX`; `dnm set "LG Ultra" labelX`; `dnm set "LG Ultra" "Label X"`; `dnm set "Label X" --display "LG Ultra"`; `dnm set "LG Ultra" --label "Label X"`; `dnm set --label "Label X" --display "LG Ultra"`; `dnm set "Label X"`.
- **Q: In what order do the docs write a command?**
  - **A**: Display first, then the label, then the other options: `dnm set DP1 "LabelX"`, `dnm set --display DP1 --label "LabelX"`, `dnm set DP1 "LabelX" --desktop 2`. The README, `--help` examples and the release notes follow it; the order is a convention, not a rule.
- **Q: What does a display word accept?**
  - **A**: Exactly what `--display` accepts, through the one resolution algorithm (spec 006 FR-011, FR-019): `main`, an exact display name, an exact alias, or a unique partial display name, with the override warning. A name with spaces is quoted, as the shell requires.
- **Q: What if the display is given twice, or the label is given twice?**
  - **A**: An error, even when both name the same display: "Give the display once". That covers a word plus `--display`, and `--display` repeated. Repeating `--display` is an error from this release; before, the last one silently won (found 2026-10-09). `--label` repeated, or `--label` together with a label word, is an error too.
- **Q: What if there are too many words?**
  - **A**: An error that tells what to type, never a guess (maintainer decision): `set` takes a label, or a display and a label; with `--label` it takes at most one display; `remove`, `undo` and `show` take at most one display. The message says to quote anything with spaces and that an alias avoids quoting a display name.
- **Q: `dnm set Mail Inbox`, where `Mail` is no display?**
  - **A**: The first word is resolved as a display and the usual "no display matches" error is shown, plus the hint that a label of several words is one quoted argument. The suggested commands are quoted correctly when a word contains spaces.
- **Q: `dnm set DP1`, a lone word that is also a display?** (decision 1)
  - **A**: Refused, because it is probably a label forgotten after the display. The message gives both forms. The rule covers exactly `main`, a connected display's name, or any alias's name, ignoring case; partial names and numbers are not display references (labels are short words, and a substring rule would refuse legitimate ones), so `dnm set lg` with a display `LG Ultra HD` still labels the main display "lg". It does not apply when `--display` or `--label` is given. `dnm set --label DP1` and `dnm set main DP1` label the main display "DP1".
- **Q: Does positional use depend on the machine?**
  - **A**: Partly. Whether a lone word is refused depends on the connected displays and stored aliases. Scripts should use `--display` (and `--label`), which never depend on that; the README says so.
- **Q: Does Tab follow the grammar (spec 007)?**
  - **A**: Yes: the first word of `set`, `remove`, `undo` and `show` offers `main`, the connected displays and the usable aliases; the second word of `set` and `--label` offer nothing. The parser knows each word's position, so the scripts supply it (the words are separate parser arguments, not one list).
- **Q: Several displays at once (`--display DP1 --display main`)?**
  - **A**: Not in this release. It needs rules for partial failure, duplicates, `--desktop` and `show --json`; it is recorded under batch labeling (F3).
- **Q: Do other commands change?**
  - **A**: No. `alias <name> [<display>]` already takes its display as a word; `list`, `displays`, `prune`, `about` and `check` do not choose a display.

---

## User Scenarios & Testing

### User Story 1 - Label a display by naming it (Priority: P1)

As a user with several monitors, I want to name the display first, as in `dnm set DP1 "label"`, so that the common case is short.

**Independent Test**: With a display named `DP`, run `dnm set DP "Mail"`; that display's current Desktop shows the label. Also `dnm set "Built-in Retina Display" "Notes"` and `dnm set main "Notes"`.

**Acceptance Scenarios**:
1. **Given** displays `Built-in Retina Display` and `LG Ultra HD`, **When** the user runs `dnm set "LG Ultra" "My label is great"`, **Then** the unique partial name resolves to the LG display and it is labeled, the label keeping its spaces.
2. **Given** an alias `lg` for the LG display, **When** the user runs `dnm set lg "My label"`, **Then** the LG display is labeled.
3. **Given** one word, **When** the user runs `dnm set "Mail"` (and `Mail` is not `main`, a display or an alias), **Then** the main display is labeled, as today.
4. **Given** `--style`, `--position`, `--size`, `--color` and `--desktop`, **When** they are mixed with the words in any order, **Then** they apply as before.
5. **Given** a display's own name equals an alias, **When** it is the first word, **Then** the display wins and the warning for `--display` is printed.
6. **Given** `dnm set DP1 --label "Mail"`, `dnm set --label "Mail"` and `dnm set --display DP1 --label "Mail"`, **Then** the label goes to DP1, the main display and DP1 respectively.

---

### User Story 2 - Show, remove and undo by naming the display (Priority: P1)

As a user, I want `dnm show DP1`, `dnm remove DP1` and `dnm undo DP1` to work the same way.

**Independent Test**: `dnm show DP --json` prints the label details of that display; `dnm remove "LG Ultra"` removes its label.

**Acceptance Scenarios**:
1. **Given** no word, **When** the user runs `dnm show`, **Then** the main display is used, as today.
2. **Given** `dnm remove DP1` and `dnm undo DP1`, **Then** they act on that display's current Desktop (or the Desktop given with `--desktop`).
3. **Given** two words, **When** the user runs `dnm show DP1 DP2`, **Then** it exits 2 saying a command takes at most one display.

---

### User Story 3 - Clear errors, no guessing (Priority: P1)

As a user, I want a mistake in the words to be an error that tells me what to type, never a label on the wrong display.

**Independent Test**: Run each case below; each exits 2, changes nothing, and prints the hint.

**Acceptance Scenarios**:
1. **Given** `dnm set LG Ultra "label"` (an unquoted name with a space), **Then** exit 2: `set` takes a label, or a display and a label; quote anything with spaces; an alias avoids quoting.
2. **Given** `dnm set Mail Inbox` where `Mail` is no display, **Then** exit 2: no display matches `Mail`, with the quoting hint for a label.
3. **Given** `dnm set DP1` where `DP1` is a connected display, **Then** exit 2 giving both forms (with a name that has spaces quoted in the suggestion); nothing is labeled.
4. **Given** `dnm set DP1 "x" --display DP2`, `dnm show DP1 --display DP2` or `dnm show --display main --display DP`, **Then** exit 2: give the display once.
5. **Given** `dnm set "x" --label "y"`, `dnm set a b --label "y"` or `--label` twice, **Then** exit 2 saying what is wrong.
6. **Given** `dnm set` with no label, **Then** exit 2 as today.

---

### User Story 4 - Keep `--display` (Priority: P2)

As a user with scripts, I want `--display` to keep working.

**Acceptance Scenarios**:
1. **Given** `dnm set "Mail" --display DP1` and `dnm show --display DP1`, **Then** they behave as before.
2. **Given** the `Tests/live` scripts, which use `--display`, **Then** they need no change.

---

## Edge Cases

- **A label that equals a display or alias**: `dnm set --label "<label>"`, `dnm set main "<label>"` or `--display main`.
- **Digits**: `dnm set 2 "x"` fails as before (numbered displays are not accepted); a lone `dnm set 2` labels the main display "2".
- **A label starting with `-`**: after `--`, as today (`dnm set DP1 -- "-x"`), or `--label=-x`.
- **A display name that is also a sensible label** (`dnm set Mail Inbox` when a display is named `Mail`): the display wins; quote the label or use `--label`.
- **An alias for a display that is not connected** as the first word: the usual error ("The display aliased as ... is not connected").
- **`main` as a lone word** is a display reference: refused; `dnm set main main` and `dnm set --label main` label the main display "main". The same holds for `Main`.
- **`--desktop`** is unchanged and still needs the Accessibility permission.
- **Compatibility**: every invocation valid in 0.1.2 behaves the same, except (a) a lone word that is a display reference is now refused, and (b) repeating `--display` is now an error.

---

## Requirements

### Functional Requirements

- **FR-001**: `dnm set` MUST accept `[<display>] <label>` (one word: the label; two: display and label) and `[<display>] --label <text>`.
- **FR-002**: `dnm remove`, `dnm undo` and `dnm show` MUST accept an optional display word.
- **FR-003**: A display word MUST be resolved by the single resolution algorithm in its full mode (spec 006 FR-011, FR-019), including the override warning.
- **FR-004**: `--display` MUST remain. A display given twice in any way (word and `--display`, or `--display` repeated) MUST be an error (exit 2) even if it is the same display. A label given twice (`--label` repeated, or `--label` with a label word) MUST be an error.
- **FR-005**: How the words and flags are read (how many, which is the display, which the label, every refusal) MUST be decided in one function in the core library, used by all four commands, and MUST return the resolved display, so a display is resolved once.
- **FR-006**: Too many words MUST exit 2, change nothing, and say what the command takes, to quote anything with spaces and that an alias avoids quoting.
- **FR-007**: With two words whose first resolves to no display, the command MUST exit 2 with the resolver's message and the quoting hint; every command suggested in a message MUST quote words that contain spaces.
- **FR-008**: (decision 1) `set` with one word and neither `--display` nor `--label` MUST refuse (exit 2, nothing changed) when the word equals `main`, a connected display's name or any alias's name, exactly, ignoring case, and MUST give both forms. The test for "is a display reference" MUST be in the resolver, built from the same matchers as the resolution so the two cannot drift.
- **FR-009**: Tab MUST offer displays and usable aliases for the first word of the four commands and nothing for the second word of `set` or for `--label`; the positions MUST come from the parser's positional arguments, with no counting of option values in our code.
- **FR-010**: Help (a custom usage line showing the real grammar), the README, the release notes and the CLI contracts MUST show the new grammar; spec 001 FR-023 and its CLI contract, spec 006 FR-011 and spec 007's contract MUST be amended; the README MUST say scripts should use `--display` and `--label`.
- **FR-011**: The release notes MUST state the two changes of behavior: a lone word that is a display reference is refused, and repeating `--display` is an error.
- **FR-012**: Every example in the README, the help and the release notes MUST write the display before the label.
- **FR-013**: `dnm alias` MUST NOT accept `-d`; `--remove` is the only way. The release notes MUST say so (it is a removal of a released option).

---

## Success Criteria

- **SC-001**: A table-driven test lists every invocation in this specification (each legitimate one and each error case, in the order they appear) with its outcome, against the interpretation function; the error cases are also run against the built binary and exit 2 without changing anything.
- **SC-002**: Every `--display` invocation in the `Tests/live` scripts and the previous README behaves as before.
- **SC-003**: The commands contain no display matching or word counting of their own: a test fails if a file under `Sources/dnm/Commands` calls the resolver or compares display names.
- **SC-004**: `just test` and `just periphery` pass; in-process parse tests cover the interleaving of options and words for `set` without changing a wallpaper.

## Assumptions

- A shell passes a quoted name as one word, so the tool cannot (and does not try to) join unquoted words: a wrong count is an error (maintainer decision, 2026-10-09).
- Aliases (spec 006) are the answer to display names that are tedious to quote.
- `--display` stays indefinitely; removing it is not proposed.
