- **Several displays in one command.** `set`, `remove` and `undo` act on every display named, in order:
  `dnm set main "Mail" --display DP`, `dnm remove main DP`, `dnm undo main DP`. `set` takes one display word plus
  `--display`; `remove` and `undo` take any number of display words, and Tab offers displays for each.
- **Checked first, stopped plainly.** Every display is resolved (and, for `undo`, checked) before anything changes, so a
  typo changes nothing. A failure part-way stops the command; the error names the displays already changed and the
  `dnm undo` that puts them back. There is no rollback.
- **`--desktop N`** labels Desktop N of each display in turn, each returning to where it was.
- **Unchanged:** one display behaves exactly as before, and `show` still takes one display.
