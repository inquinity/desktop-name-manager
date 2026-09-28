# Desktop Name Manager

Label each macOS Desktop (Space) with what it's for, such as "Status Report" or "Mail &
Chat", right on the desktop background.

Desktop Name Manager draws the label into a copy of the Desktop's wallpaper and sets it
with the public macOS wallpaper API. From then on macOS itself keeps the label with that
Desktop, through restarts, reordering and Show Desktop. The label's style adapts to what
is behind it, so it stays readable without getting in the way.

Planned:
- a menu-bar app with a label editor;
- Quick View, to jump to a Desktop by its label;
- Desktop groups across monitors;
- matching monitors between places, such as home and work, so Desktops return to where
  they belong.

The command-line tool is `dnm`.

## Status

Early design. The specification is being written, and nothing is ready to install yet.
`prototype/` holds the proof of concept that validated the approach, and
`docs/research/` holds what testing and research found.

## License

MIT. See [LICENSE](LICENSE).
