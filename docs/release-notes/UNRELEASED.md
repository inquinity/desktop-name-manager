# Unreleased

<!--
Add a bullet below in the same commit as any change a dnm user would notice or want: the test for every
line is whether a reader cares. Known limitations go under a "## Known gaps" heading. At release,
scripts/compose-release-notes.sh builds <version>.md from this file; this comment and the heading above are
dropped (the same process as the sibling project).
-->

- **Quiet mode.** `-q` or `--quiet`, before or after the command name, hides warnings and notes (such as the warning
  for an alias that a display's name overrides, and the cleanup reminder); results and errors are always shown, so
  it is safer than `2>/dev/null`. `DNM_QUIET=1` turns it on for a whole shell or script. A reminder held back by
  quiet mode is not used up.
- **`dnm cleanup --scan`.** Visits every Desktop of every connected display (with the Accessibility permission, as
  `--desktop` does), then lists the labels that no Desktop shows, whatever their age, and asks before deleting them.
  Labels of displays that are not connected are left alone and named. Ctrl-C returns the display to its Desktop and
  deletes nothing (exit 130), but only while your terminal is the active app.
- **`cleanup --json`** has a new `mode` field, `"age"` or `"scan"`; nothing else changes in the age-based document.
- **Shorter Accessibility message.** When the permission is missing, `--desktop` and `cleanup --scan` now say so in
  one sentence; `dnm check` says where to turn it on.

## Known gaps

- **Ctrl-C during a scan** reaches `dnm` only while your terminal is the active app. Once the scan shows a Desktop
  without a terminal window, macOS sends the keys to the app active there. Assigning the terminal to all Desktops (its
  Dock menu, Options) should keep Ctrl-C working; not yet checked live.
