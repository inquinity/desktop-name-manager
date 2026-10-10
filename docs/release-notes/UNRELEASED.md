
- **The display comes first.** `dnm set DP1 "Mail"`, `dnm set "LG Ultra" "My label is great"`, `dnm set main "Notes"`,
  and `dnm show DP1`, `dnm remove DP1`, `dnm undo DP1`. One word to `set` is still the label for the main display.
  `--label` names the label outright (`dnm set DP1 --label "Mail"`), and `--display` still works. Too many
  words, or a display given twice, is an error that says what to type; an alias avoids quoting a display name.
  Tab completes the display word. See the README.
- **Changed:** a lone word that is `main`, a display's name or an alias is now refused by `dnm set` (it used to
  label the main display with that word), because it is probably a label forgotten after the display; write
  `dnm set --label <word>` for the label. Repeating `--display` is now an error (the last one used to win silently).
  A part of a display's name must now be its beginning: `LG Ultra` finds `LG Ultra HD`, but `Ultra` or `HD` no longer do
  (they used to match anywhere in the name); use an alias for those.
- **Removed:** the short option `-d` of `dnm alias`. Use `dnm alias --remove <name>`. The tool now has no short
  options except `-h`.
