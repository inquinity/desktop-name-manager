# Unreleased

<!--
Add a bullet below in the same commit as any change a dnm user would notice or want: the test for every
line is whether a reader cares. Known limitations go under a "## Known gaps" heading. At release,
scripts/compose-release-notes.sh builds <version>.md from this file; this comment and the heading above are
dropped (the same process as the sibling project).
-->

- The message for a wallpaper `dnm` cannot label no longer says "not supported yet": it says "This wallpaper is
  not supported: <reason>.", since support for them is not decided. A Desktop with no wallpaper file now says "This
  Desktop has no wallpaper picture to label.", and a file that is not a readable picture says "Cannot read wallpaper
  '<file>'." Both still exit with status 3.
- On macOS 27, labeling a Desktop that shows an Apple dynamic wallpaper (Golden Gate, Macintosh and others)
  is now refused with exit code 3 and the message "macOS reports the default wallpaper when dynamic or
  unsupported wallpapers are selected". 0.3.0 labeled the default still picture macOS reports for these
  wallpapers and so replaced the dynamic wallpaper. If 0.3.0 labeled such a Desktop, `dnm remove` restores
  that still, not the dynamic wallpaper: choose your wallpaper again in System Settings > Wallpaper.

- New: the Desktop Name Manager app, a menu-bar app that labels the Desktop on screen. Click its menu-bar item (or
  press an optional hotkey) to type a label and apply it, or open the editor for a live preview with the style,
  color, position and size options. It also removes and undoes labels, lists the labels in use, cleans up old
  labeled images, and manages display aliases. It needs no permission and never connects to the network. It uses
  the same labels as `dnm`, so each reads what the other made. The release now installs the app; `dnm` and
  `desktop-name` are still installed and unchanged (they run from inside the app).
- The app labels only the Desktop on screen. To label a Desktop that is not showing, or every Desktop at once,
  keep using `dnm --desktop` and `dnm cleanup --scan` (see `docs/app-and-cli.md`).
