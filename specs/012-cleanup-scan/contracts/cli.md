# CLI Contract: `dnm cleanup --scan` (Feature F9)

Extends `specs/009-stamp-reuse-and-cleanup/contracts/cli.md`. `desktop-name` behaves identically.

## 1. Usage

```text
dnm cleanup --scan [--yes] [--json]
```

- Refused (exit 2, nothing else printed first):
  - `--days` with `--scan`, including an explicit `--days 30`: `dnm: --scan looks at every Desktop, so --days does not apply.`
  - display words, `--display`, `--desktop`: the parser's usage error, as for `cleanup` today.
- Help adds:

  ```text
  --scan    Visit every Desktop of every connected display (needs Accessibility; the Desktops slide by), then
            list the labels that no Desktop shows and ask before deleting them.
  ```

## 2. Order

1. Options checked (§1).
2. Accessibility checked, without prompting and with no output before it. Missing: the one-sentence message (section 4),
   exit 1.
3. Description on standard output, for example:

   ```text
   dnm will visit every Desktop of these displays, one display at a time: Built-in Display, DP1.
   It takes about 2 seconds per Desktop. The Desktops slide by and the pointer moves; do not type until it is done.
   Each display returns to the Desktop it started on.
   Scan every Desktop now? [y/N]
   ```

   With "Displays have separate Spaces" off, the first line says the displays switch together and are visited once.
4. Without a terminal and without `--yes`, or with `--json` without `--yes`: the description (or its JSON), then
   `Nothing was scanned: add --yes to scan without asking.`, exit 0.
5. The walk. On a terminal, one line on standard error as each display starts: `Scanning DP1…` (quiet mode does not
   hide it; never with `--json`).
6. The report on standard output:

   ```text
   Not on any Desktop (3 labels, 12.4 MB):
     DP1               "Mail"   4.1 MB  last seen 41 days ago
     DP1               "Notes"  4.0 MB  last seen 3 days ago
     Built-in Display  "Old"    4.3 MB  never seen
   Not checked: Studio Display is not connected (2 labels).
   Delete these 3 labeled images (12.4 MB)? [y/N]
   ```

   A display where no step moved, beside one where steps were confirmed, is counted as having one Desktop
   (FR-017) and named after the list: `Only one Desktop was found on <display> (no step moved there); if it has more,
   do not delete its labels: run the scan again.` (added after the release review, 2026-11-09)

   Nothing to delete: `Every label of the connected displays shows on a Desktop; nothing to clean up.` and no
   question.
7. Deleted: `Deleted 3 labeled images (12.4 MB).` Declined: `Nothing was deleted.`

## 3. Exit statuses

| Situation | Exit | Deleted |
|---|---|---|
| Done, deleted or declined, or nothing to delete | 0 | as answered |
| Described only (no terminal or `--json`, no `--yes`) | 0 | nothing |
| Refused option | 2 | nothing |
| Accessibility missing; shortcuts off; a step not confirmed; someone else switched; a display disconnected during the walk | 1 | nothing |
| Ctrl-C during the walk | 130 | nothing |

## 4. Failures during the walk (standard error)

- A missing permission: `cleanup --scan needs the Accessibility permission to scan Desktops.` (amended 2026-11-10;
  `dnm check` says how to grant it).
- The `--desktop` message for shortcuts that are off, ending `Nothing was deleted.`
  The "nothing moved" message is given only when no step moved on any display in the run (spec FR-017); a display
  where nothing moved, beside one where steps were confirmed, is counted as having one Desktop.
- A display that cannot be read (disconnected): `dnm could not read the wallpaper of <display> during the scan
  (<reason>). Nothing was deleted.`; a display connected or disconnected between the start and the end:
  `A display was connected or disconnected during the scan, so its Desktops were not all seen. Nothing was deleted;
  run the scan again.` (added 2026-11-09 after review)
- More than 32 steps one way: `<display> has more than 32 Desktops and full-screen apps, more than dnm can scan.
  Nothing was deleted.`
- Someone else switched, or a step that timed out moved after all: `The Desktop on <display> changed while dnm was scanning. Nothing was deleted. dnm no longer
  knows where <display> is, so it did not switch back; return to your Desktop yourself.`
- Other displays already scanned are back where they started and are named: `Scanned and returned: <displays>.`

## 5. Ctrl-C

- First: the walk stops stepping forward, the display returns to its starting Desktop and the pointer to where it
  was, then `Stopped. Scanned: <displays>. Nothing was deleted.` on standard error, exit 130; before the first
  display is finished, `Stopped before any display was scanned. Nothing was deleted.`
- Second, while returning: `Stopped; <display> may be on another Desktop. Nothing was deleted.`, exit 130 at once.
- A Ctrl-C during the last display's final step or its way back is seen after the walk: the same first-Ctrl-C
  result. If the Desktop changed by other means before the Ctrl-C, the "changed while dnm was scanning" failure is
  given instead (exit 1), since dnm cannot step back from an unknown place.
- Outside the walk (at a question), Ctrl-C ends the command as for any command; nothing is deleted.

## 6. JSON (`--json --yes`)

The spec 009 cleanup document (`days`, `candidates`, `totalBytes`, `deleted`), with `"days": null`, each
candidate's `why` `"not on any Desktop"` (the key and style of spec 009; corrected 2026-11-09 after review), and a new `"mode"` field, `"scan"` here and `"age"` in the age-based
document (an added field; nothing existing changes for `cleanup` without `--scan`), plus:

```json
{ "scanned": ["Built-in Display", "DP1"], "notChecked": [{ "display": "Studio Display", "labels": 2 }], "oneDesktop": [] }
```

`oneDesktop` (added after the release review) names the displays counted as having one Desktop.

Without `--yes`: `"scanned": []` and `"deleted": false`, with the displays that would be visited in `"wouldScan"`.

## 7. Completion

`--scan` is offered for `cleanup` (spec 007).
