
## New in this release

- **Display aliases.** `dnm alias <name> [<display>]` gives a display a short name, usable with `--display`
  in `set`, `remove`, `undo` and `show`. `dnm alias` lists them (`--json` too), `dnm alias --remove <name>`
  deletes one, `dnm displays` shows them, and `dnm check` reports them. A connected display's own name
  wins over an alias of the same name, and `dnm` says so. See the README.

## Changed

- The stored data is now format 2 (it holds the aliases). Older releases refuse it, so going back to 0.1.0
  is not supported once this release has written the store.

- `dnm set --desktop 1` no longer prints a note about new Desktops, and `dnm check` no longer has a
  "First Desktop" row. A new Desktop takes its wallpaper from the left-most Desktop on its display, and
  people can choose which Desktop that is, so there is nothing to warn about. The README explains the
  behavior.

## Known issues

- After the label on the left-most Desktop is removed, a new Desktop that inherited that label can report
  "No label" while still showing it (KI-3). Keep the left-most Desktop unlabeled to avoid it.
