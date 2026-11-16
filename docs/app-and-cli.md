# What the app and `dnm` each offer

The app and the command-line tool (`dnm`) are two ways into the same core library and the same label store. Ideally
they offer the same capabilities. That isn't a rule, though: holding every app idea back until it also works in a
terminal, or every CLI option until it has a control, could become hard to manage and could stand in the way of new
ideas. This list makes each difference a deliberate choice instead.

**How it is kept.** A spec that adds or removes a capability in only one of the two updates this list in the same
change. Each entry says why the other one lacks it and whether it is worth adding there. When an entry is closed
(both offer it), it moves to "Closed" with the release that closed it. Reviews of each feature check the list.

Kinds of reason:

- **Inherent:** it only makes sense in one of them (a menu-bar item has no terminal form; `--json` has no window form).
- **Deliberate:** a decision to keep it to one, with its date.
- **Gap:** worth adding to the other one; it may have a backlog item or a roadmap feature.

## Only in the app

Planned by spec 014 (M2, 0.4.0); none is built yet.

| Capability | Reason | In `dnm`? |
|---|---|---|
| Live preview of the label over the wallpaper before applying it, including a small view of each style | Inherent: a terminal cannot show the image. A CLI could write a preview image to a file | Gap, small: for example `dnm set --preview <file>`. Not planned |
| The current Desktop's label always visible in the menu bar, following Desktop switches | Inherent: `dnm show` and `dnm list` answer when asked, which is the CLI equivalent | No |
| A global hotkey that opens the editor | Inherent | No |
| Label defaults chosen in Settings (style, color, position, size) | Deliberate (2026-11-12, spec 014 FR-018): the app's defaults never change `dnm`, so scripts keep behaving as documented | Gap: a `dnm` defaults file or environment variables could add it. Not planned |
| Open at login | Inherent: `dnm` does not run in the background | No |

## Only in `dnm`

| Capability | Reason | In the app? |
|---|---|---|
| Label a Desktop that is not on screen (`--desktop`, Accessibility) | Deliberate (spec 014): the app needs no permission in M2 | Gap: could come with Quick View (M3) |
| Several displays in one command (`set`, `remove`, `undo` with several displays) | Inherent to a command line; the editor labels one Desktop at a time | No |
| List every label (`dnm list`) and one label's details (`dnm show`) | Gap: the app's menu shows only the current Desktop's label | Quick View (M3) |
| Display aliases (`dnm alias`) and the list of displays (`dnm displays`) | Inherent: aliases are for typing; the app names displays as macOS does | No |
| Finding labels of deleted Desktops by visiting every Desktop (`cleanup --scan`, Accessibility) | Deliberate (spec 014): the app needs no permission in M2. Age-based cleanup is in both (spec 014 FR-016a) | Gap: could come with Quick View (M3) |
| Machine-readable output (`--json`) and quiet mode (`-q`) | Inherent | No |

## Closed

None yet.
