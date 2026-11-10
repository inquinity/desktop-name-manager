- **Quiet mode.** `-q` or `--quiet`, before or after the command name, hides warnings and notes (such as the warning
  for an alias that a display's name overrides, and the cleanup reminder); results and errors are always shown, so
  it is safer than `2>/dev/null`. `DNM_QUIET=1` turns it on for a whole shell or script. A reminder held back by
  quiet mode is not used up.
- **`dnm cleanup --scan`.** Visits every Desktop of every connected display (with the Accessibility permission, as
  `--desktop` does), then lists the labels that no Desktop shows, whatever their age, and asks before deleting them.
  Labels of displays that are not connected are left alone and named. Ctrl-C returns the display to its Desktop and
  deletes nothing (exit 130).
- **`cleanup --json`** has a new `mode` field, `"age"` or `"scan"`; nothing else changes in the age-based document.
