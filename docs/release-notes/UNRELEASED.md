# Unreleased

<!--
Add a bullet below in the same commit as any change a dnm user would notice or want: the test for every
line is whether a reader cares. Known limitations go under a "## Known gaps" heading. At release,
scripts/compose-release-notes.sh builds <version>.md from this file; this comment and the heading above are
dropped (the same process as the sibling project).
-->

- **First release.** Label each Desktop by stamping its name into a copy of the wallpaper: `set`,
  `remove`, `undo`, `show`, `list`, `displays`, `prune`, `about` and `check`, with `--display` to pick a
  display and `--desktop` to pick a Desktop by number.
- Public macOS interfaces only; no network access and no telemetry. Labeling the Desktop on screen needs no
  permission.

## Known gaps

- Apple silicon only; Intel Macs are refused for now.
- Dynamic, aerial and shuffling wallpapers are not supported (exit 3).
- `--desktop` needs the Accessibility permission for the terminal app, which then applies to everything run
  in it; a full-screen app among the Desktops can shift the count.
- macOS copies a display's first Desktop's wallpaper to new Desktops, and Desktops of a display arrangement
  that is not connected are invisible to `dnm`.
