# Contract: display as a positional argument

**Feature**: F8 | **Spec**: [spec.md](../spec.md)

## 1. Syntax

```text
dnm set    [<display>] [<label>] [--label <text>] [--display <name>] [--desktop <n>] [--position <p>] [--size <s>] [--style <look>] [--color <c>]
dnm remove [<display>] [--display <name>] [--desktop <n>]
dnm undo   [<display>] [--display <name>] [--desktop <n>]
dnm show   [<display>] [--display <name>] [--desktop <n>] [--json]
```

Options may come before, between or after the words. The help shows the real grammar with a custom usage line
(`dnm set [<display>] <label>` and `dnm set [<display>] --label <text>`), not the parser's generic one.

A display word (or `--display` value) is resolved as spec 006 contract §4 says: `main`, an exact display name, an
exact alias, then the beginning of a name that one display's name starts with; a connected display's own name overrides an alias, with the same
warning. A *display reference* is `main`, the exact name of a connected display, or the exact name of any stored
alias (connected or not, overridden or not), ignoring case; partial names and digits are not display references.
The reference test and the resolution share their matchers.

## 2. How a command line is read (one function in the core)

*Words* are the arguments that are not options. *Display flag* is `--display`; *label flag* is `--label`.
Giving `--display` or `--label` more than once is always an error ("Give the display once" / "Give the label once").

### `set`

| Label flag | Words | Display flag | Reading |
|---|---|---|---|
| given | 0 | any | display = the flag, or main; label = the flag |
| given | 1 | none | display = the word; label = the flag |
| given | 1 | given | error: display given twice |
| given | 2 or more | any | error: with `--label`, `set` takes at most one display |
| none | 0 | any | error: a label is required |
| none | 1 | given | label = the word; display = the flag |
| none | 1 | none | if the word is a display reference: refuse (lone word is a display); else label = the word, display = main |
| none | 2 | given | error: display given twice |
| none | 2 | none | display = word 1; label = word 2 (if word 1 resolves to no display: error with the quoting hint) |
| none | 3 or more | any | error: too many words |

### `remove`, `undo`, `show`

| Words | Display flag | Reading |
|---|---|---|
| 0 | any | display = the flag, or main |
| 1 | none | display = the word |
| 1 | given | error: display given twice |
| 2 or more | any | error: too many words |

The function returns the resolved display (and the override warning, if any) with the label, so the command
never resolves again. A repeated `--label`, or `--label` together with a label word, is an error.

## 3. Error messages (exit 2, nothing changed, standard error)

Every word in a suggested command is quoted the way a POSIX shell would (single quotes, with `'\''` for an embedded one; a word of only letters, digits and `_ - . / : = @ % + ,` stays bare, except one that starts with `=`): `dnm set 'LG Ultra' "<label>"`. A placeholder such as `"<label>"` is in double quotes. A word that starts with a dash is read as an option, so suggestions use the `=` forms for it (`--label=-x`, `--display=-x`).

| Case | Message |
|---|---|
| Too many words for `set` (no `--label`) | `dnm: set takes a label, or a display and a label (got <n> words). Quote anything with spaces; an alias avoids quoting a display name: dnm alias lg "LG Ultra".` |
| Too many words with `--label` | `dnm: with --label, set takes at most one display (got <n> words). Quote a name with spaces, or use an alias.` |
| Too many words for `remove`, `undo`, `show` | `dnm: <command> takes at most one display (got <n> words). Quote a name with spaces, or use an alias.` |
| First of two words is no display | the resolver's message, then `To label the main display with several words, quote the whole label: dnm set '<word 1> <word 2>'.` The hint is added only when the word is no display at all; an alias of a display that is away gets the resolver's message alone. |
| A display given but empty (`dnm set "" Mail`, `--display ""`) | `dnm: The display is empty: name a display, or leave it out for the main display.` |
| Lone word is a display reference | `dnm: "<word>" is a display. To label it: dnm set <word> "<label>". To use "<word>" as the label of the main display: dnm set --label <word>.` |
| Display given twice | `dnm: Give the display once, as a word or with --display (not both, and not --display twice).` |
| Label given twice | `dnm: Give the label once, as a word or with --label (not both, and not --label twice).` |

## 4. Completion (spec 007)

The words are separate parser arguments, so the generated scripts give each its position.

| Position | Offered |
|---|---|
| first word of `set`, `remove`, `undo`, `show` | `main`, connected display names, usable aliases (as `--display`) |
| second word of `set`; `--label` | nothing |
| `--display` | unchanged |

## 5. Compatibility

Every invocation valid in 0.1.2 behaves the same, except two: a lone word that is a display reference (it used to
label the main display; now refused) and `--display` repeated (it used to use the last one silently; now an
error). Both are in the 0.2.0 release notes.
