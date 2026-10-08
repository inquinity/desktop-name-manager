
## Changed

- `dnm set --desktop 1` no longer prints a note about new Desktops, and `dnm check` no longer has a
  "First Desktop" row. A new Desktop takes its wallpaper from the left-most Desktop on its display, and
  people can choose which Desktop that is, so there is nothing to warn about. The README explains the
  behavior.

## Known issues

- After the label on the left-most Desktop is removed, a new Desktop that inherited that label can report
  "No label" while still showing it (KI-3). Keep the left-most Desktop unlabeled to avoid it.
