# Contract: display as a positional argument

**Feature**: F8 | **Spec**: [spec.md](../spec.md)

## 1. Syntax

```text
dnm set    [<display>] <label> [--display <name>] [--desktop <n>] [--position <p>] [--size <s>] [--style <look>] [--color <c>]
dnm remove [<display>] [--display <name>] [--desktop <n>]
dnm undo   [<display>] [--display <name>] [--desktop <n>]
dnm show   [<display>] [--display <name>] [--desktop <n>] [--json]
```

Options may come before, between or after the arguments. A display argument is resolved exactly as `--display`
is (spec 006 contract §4): `main`, an exact display name, an exact alias, then a unique partial name; a
connected display's own name overrides an alias, with the same warning.

## 2. Interpretation (one function in the core)

Let *words* be the arguments without options, and *flag* the value of `--display`, if given.

| Command | Words | Flag | Result |
|---|---|---|---|
| `set` | 0 | any | error: a label is required (as today) |
| `set` | 1 | given | label = the word, display = flag |
| `set` | 1 | none | if the word is a display reference: refuse (§3 E3); else label = the word, display = main |
| `set` | 2 | given | error E4 |
| `set` | 2 | none | display = word 1, label = word 2; if word 1 does not resolve: error E2 |
| `set` | 3 or more | any | error E1 |
| `remove`, `undo`, `show` | 0 | any | display = flag, else main |
| `remove`, `undo`, `show` | 1 | none | display = the word |
| `remove`, `undo`, `show` | 1 | given | error E4 |
| `remove`, `undo`, `show` | 2 or more | any | error E5 |

A *display reference* is `main`, the exact name of a connected display, or the exact name of any stored
alias (connected or not, overridden or not), compared ignoring case. Partial names and digits are not display
references.

## 3. Errors (exit 2, nothing changed, to standard error)

| | Case | Message |
|---|---|---|
| E1 | `set` with 3 or more words | `dnm: set takes a label, or a display and a label (got <n> arguments). Quote anything with spaces; an alias avoids quoting a display name: dnm alias lg "LG Ultra".` |
| E2 | `set`, 2 words, the first resolves to no display | the resolver's message, then `To label the main display with several words, quote the whole label: dnm set "<word1> <word2>".` |
| E3 | `set`, 1 word, a display reference, no flag | `dnm: "<word>" is a display. To label it: dnm set <word> "<label>". To use "<word>" as the label of the main display: dnm set main <word>.` |
| E4 | display given as an argument and with `--display` | `dnm: Give the display once, as an argument or with --display.` |
| E5 | `remove`, `undo` or `show` with 2 or more words | `dnm: <command> takes at most one display (got <n> arguments). Quote a name with spaces, or use an alias.` |

## 4. Completion (spec 007)

| Position | Offered |
|---|---|
| first argument of `set`, `remove`, `undo`, `show` | `main`, connected display names, usable aliases (as `--display`) |
| second argument of `set` | nothing |
| `--display` | unchanged |

The position counts arguments, not option values (`--style plain` is no argument).

## 5. Compatibility

`--display` is unchanged. The one behavior that changes is E3: `dnm set <word>` where the word is `main`, a
display or an alias used to label the main display with that word and is now refused (0.2.0).
