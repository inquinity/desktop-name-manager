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

1. the label and label options (`set`);
2. every display resolved (§2);
3. for `undo`, every display has a change it can undo now (`Cannot undo: ...`, exit 1);
4. with `--desktop`, the Accessibility permission (exit 1, as today).

Checks that need Desktop N on screen (it exists; for `undo`, it still shows what the change produced) are made
[decision pending, research R4].

## 4. Output and exit status

- One line per display, as each succeeds, in order: the line a single command prints for it
  (`Labeled "Mail" on DP (...)`, `Removed the label ... from main ...`, `No label on DP.`, `Restored ... on main.`).
- `remove` on a display without a label prints `No label on <display>.` and continues; it is not a failure.
- The override warning for an alias prints once, on standard error, before the first change.
- The cleanup reminder (spec 009) is considered once, after the last display (`set` and `remove` only).
- Exit 0 when every display succeeded.
- A failure on the first display: the message and exit status of a single command; nothing changed.
- A failure on a later display: that error's exit status, and its message followed by
  `Changed before this: <names>. To put them back within 60 seconds: dnm undo <displays>.`, the displays quoted for a
  POSIX shell. Displays after it are not attempted.

## 5. Help and completion

- Usage lines as in §1; the help of `set`, `remove` and `undo` says that several displays may be named and gives an
  example with the displays before the label: `dnm set main "Mail" --display DP`, `dnm remove main DP`.
- Tab offers `main`, the connected displays and usable aliases for every display word of `remove` and `undo` and for
  every `--display` (spec 007 contract).
