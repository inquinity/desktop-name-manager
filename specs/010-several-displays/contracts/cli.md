# Contract: several displays in one command

**Feature**: F3 (first part) | **Spec**: [spec.md](../spec.md) | Amends
[spec 008's contract](../../008-positional-display/contracts/cli.md) §1 and §2 for `set`, `remove` and `undo`.

## 1. Syntax

```text
dnm set    [<display>] <label> [--display <name>]... [--desktop <n>] [label options]
dnm set    [<display>] --label <text> [--display <name>]... [--desktop <n>] [label options]
dnm remove [<display> ...] [--display <name>]... [--desktop <n>]
dnm undo   [<display> ...] [--display <name>]... [--desktop <n>]
dnm show   [<display>] [--display <name>] [--desktop <n>] [--json]          (unchanged: one display)
```

Every display word and `--display` value is resolved as spec 006 contract §4 says. The rules of spec 008 §2 for
`set` (one word is the label; two are a display and a label; a lone word that is a display reference is refused;
three or more words are an error) are unchanged; only the "two different displays" refusal is lifted for `set`,
`remove` and `undo`. `show` keeps it.

## 2. Which displays, in which order

1. The display words, in order, then each `--display` value, in order.
2. A display named more than once, by the same or a different name (`main` and its name; an alias and its
   display's name), is one display, at its first place.
3. No display named: the main display, as today.

| Command line | Displays, in order |
|---|---|
| `dnm set main "Mail" --display DP` | main, DP |
| `dnm set "Mail" --display DP --display main` | DP, main |
| `dnm set DP "Mail" --display DP` | DP |
| `dnm remove main DP` | main, DP |
| `dnm remove DP --display main --display DP` | DP, main |
| `dnm undo` | main |
| `dnm show main --display DP` | refused, exit 2: "Multiple displays for a single command are not currently supported." |
| `dnm remove main NoSuch` | refused, exit 2: the resolver's message for `NoSuch`; nothing changed |
| `dnm set main DP "Mail"` | refused, exit 2: three words (spec 008); nothing changed |

## 3. Before anything changes

In this order, each failure ending the command with nothing changed and the message a single command gives:

1. the label options (`set`);
2. every display resolved (§2);
3. the label itself (`set`). The order is 0.2.1's, so a single command reports the same error first (amended
   2026-11-09 after the 0.2.2 code review, which found the label listed before the displays);
4. for `undo`, every display has a change it can undo now (`Cannot undo: ...`, exit 1);
5. with `--desktop`, the Accessibility permission (exit 1, as today).

With `--desktop`, item 4 checks each display's undo record and window only; the checks that need Desktop N on
screen (it exists; for `undo`, it still shows what the change produced) are made when that display is reached, and a
failure there is a part-way failure (§4). Research R4.

## 4. Output and exit status

- One line per display, as each change is made (on Desktop N, with `--desktop`), in order: the line a single command prints for it
  (`Labeled "Mail" on DP (...)`, `Removed the label ... from main ...`, `No label on DP.`, `Restored ... on main.`).
- `remove` on a display without a label prints `No label on <display>.` and continues; it is not a failure.
- The override warning for an alias prints once, on standard error, before the first change.
- The cleanup reminder (spec 009) is considered once, after the last display (`set` and `remove` only).
- Exit 0 when every display succeeded.
- A failure on the first display: the message and exit status of a single command; nothing changed.
- A failure on a later display when nothing was changed before it (`remove` found no label): that error's exit
  status and message, prefixed `On <display>: ` as below, with no "Changed" sentence (amended 2026-11-09).
- A failure on a later display, or on any display after its own change was made (with `--desktop`, a step back that
  macOS did not confirm, or a Desktop switch while dnm worked): that error's exit status, and its message (prefixed
  `On <display>: ` when it does not name the display as a whole word; "Nothing was changed." becomes "Nothing was changed on <display>.") followed by
  `Changed before this: <names>. To put them back within 60 seconds: dnm undo <displays>.` ("it" for one display;
  `Changed: <names>.` when the failing display was changed too, and it is then in the command), the displays by the
  words that named them (by display name where a word has a control or bidirectional character), quoted for a POSIX
  shell, with `--desktop N` when it was given. A "run `dnm undo` if needed" in the error becomes "run the undo below if
needed", since a bare `dnm undo` means main (amended 2026-11-09). Displays
  after it are not attempted. A display that `remove` found without a label is not named. `undo` names the displays
  it changed and suggests no command: an undo cannot be undone.

## 5. Help and completion

- Usage lines as in §1; the help of `set`, `remove` and `undo` says that several displays may be named and gives an
  example with the displays before the label: `dnm set main "Mail" --display DP`, `dnm remove main DP`.
- Tab offers `main`, the connected displays and usable aliases for every display word of `remove` and `undo` and for
  every `--display` (spec 007 contract).
