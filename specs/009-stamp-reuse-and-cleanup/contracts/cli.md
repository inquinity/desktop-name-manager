# Contract: `dnm cleanup`, reuse and the nudge

**Feature**: F4 | **Spec**: [spec.md](../spec.md)

## 1. Syntax

```text
dnm cleanup [--days <n>] [--yes] [--json]
dnm cleanup --scan [--yes] [--json]          (stage 2)
```

`prune` no longer exists. `dnm prune` prints `dnm: prune was replaced by cleanup: run dnm cleanup (see dnm cleanup --help).` and exits 2.

## 2. `dnm cleanup` (without `--scan`)

Selection: spec `data-model.md` §4. `--days` is a whole number of 0 or more (default 30); anything else exits 2.

Terminal, something to delete:

```text
Old labeled images that no Desktop is known to show (30 days):
  "Mail"     DP                       removed 45 days ago       3.1 MB
  "Projects" Built-in Retina Display  not seen for 52 days     1.9 MB
2 images, 5.0 MB in all.
A Desktop that is not on screen now might still show one of these; it would fall back to the Mac's default
wallpaper until you choose another or label it again. "dnm cleanup --scan" checks every Desktop first.
Delete these 2 labeled images (5.0 MB)? [y/N]
```

- `y` or `yes` (any case) deletes; anything else (including Enter) deletes nothing and exits 0.
- Afterwards: `Deleted 2 labeled images, freeing 5.0 MB.`
- Not a terminal, without `--yes`: the same description, then `Nothing was deleted: add --yes to delete these.`, exit 0. With `--yes`: no question.
- Nothing qualifies: `Nothing to clean up (no labeled image is older than 30 days).` (the number follows `--days`).
- `--json` (nothing is asked; add `--yes` to delete):

```json
{
  "days": 30,
  "candidates": [
    { "label": "Mail", "display": "DP", "why": "removed", "since": "2026-08-26T10:00:00Z", "bytes": 3250000 },
    { "label": "Projects", "display": "Built-in Retina Display", "why": "not seen", "since": "2026-08-19T10:00:00Z", "bytes": 1990000 }
  ],
  "totalBytes": 5240000,
  "deleted": false
}
```

`why` is one of `removed`, `replaced`, `undone`, `not seen`. Exit codes: `0` success or nothing deleted by choice; `1` store failure (not writable, damaged, newer); `2` invalid input.

## 3. `dnm cleanup --scan` (stage 2)

Order: (1) check Accessibility for the app running `dnm`; if not granted, print the `--desktop` explanation (System Settings path for the macOS version) and exit 1, before anything else; (2) describe and ask:

```text
This will look at every Desktop on 2 displays (Built-in Retina Display, DP): about 40 seconds. The screen
will slide between Desktops, the pointer will move, and each display ends on the Desktop it started on.
Don't type while it runs. Continue? [y/N]
```

(3) visit; (4) list the labels of connected displays whose image shows on no Desktop, name displays that could not be looked at (not connected), and ask `Delete these ... ? [y/N]`. `--days` exits 2: `--scan looks at every Desktop, so --days does not apply.` `--yes` answers both questions. Exit codes as above; `1` also when the navigator cannot confirm a step (as for `--desktop`).

## 4. Reuse

No new syntax. `dnm set` output is unchanged. A reused image is not re-rendered, so repeated labeling of the same thing is faster.

## 5. The nudge

Standard error, one line, after `set` or `remove` completes (never after `undo`: the person is fixing a mistake), when stderr is a terminal and cleanup could free at least 50 MB at the default days, at most every 7 days (sooner if the amount at least doubled since it was shown), reset by `cleanup`:

```text
dnm: note: about 62 MB (14 labels) of old labeled images could be freed: run dnm cleanup.
```

Stage 2 adds: `... run dnm cleanup, or dnm cleanup --scan to check every Desktop first.`

## 6. `dnm check`

The stored-labels row: `N active labels, M labeled images using X. cleanup could free Y.` (or `Nothing to clean up.`).
