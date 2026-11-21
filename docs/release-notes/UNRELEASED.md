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
