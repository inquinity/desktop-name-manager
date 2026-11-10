- **Quiet mode.** `-q` or `--quiet`, before or after the command name, hides warnings and notes (such as the warning
  for an alias that a display's name overrides, and the cleanup reminder); results and errors are always shown, so
  it is safer than `2>/dev/null`. `DNM_QUIET=1` turns it on for a whole shell or script. A reminder held back by
  quiet mode is not used up.
