# Contract: the app's screens, windows and messages (spec 014)

What the person sees and can do. Layout and visual details are settled by the prototypes (FR-001, FR-002); this
contract fixes the content, the behavior and the wording rules the prototypes and the build must both follow. Text in
quotes is the proposed wording; the approved prototype may change wording, and `prototypes/REVIEW.md` records it.

## Menu-bar item (FR-010 to FR-012)

| Mode | The item |
|---|---|
| Icon and text (default) | icon + "dnm" (prototype review round 6) |
| Icon | icon |
| Hidden | no item |

The item never shows the Desktop's label (prototype review round 3, 2026-11-19): a label beside an icon reads as an
app's name. It does not change with Desktop switches. Its accessibility label is "Desktop Name Manager".

## Main window (FR-013, FR-013a, FR-016b)

A panel under the menu-bar item (an `NSPopover`, research R2), opened by clicking the item. In order; items in
brackets appear only when their condition holds.

1. The Desktop it is about: the display's name, small, and under it the label in full, or "No label".
2. The label field, placeholder "Label this Desktop", focused; it holds the current label, selected, or is empty. Beside
   it "Label" (default, Return), off while the text is invalid or unchanged. One sentence under it when the text is
   too long (the editor's sentence); the field follows the editor's input rules. A Desktop with no label gets the
   defaults for new labels from General; a labeled Desktop keeps its label's style and gets the new text. On success the main window closes.
3. "Style and Preview…": opens the editor in the same panel.
4. [labeled] "Remove Label"
5. [undo available] "Undo <Label|Remove> on <display>" (`checkUndo` passes; 60-second window)
6. "Labels in use" with "<n> on <m> displays ›": opens the Labels pane.
7. One storage row: "Space used: <size>" and under it "<size> in old images", with "Clean Up…" (opens the Clean Up
   pane). When FR-016b holds, the second line is red, with a warning symbol ("⚠︎ 63.4 MB in old images"); there is no
   separate banner.
8. separator
9. "Settings…" ⌘, (opens the Settings window at General)
10. "Configuration…" (at Configuration)
11. "About Desktop Name Manager" (at About)
12. "Quit" ⌘Q

The hotkey opens the same main window for the active display (FR-012, FR-014): under the item when it is shown, else
as a floating panel near the top of that display. It only opens (not a toggle): pressing it while the main window is
open for the active display leaves the window as it is and gives it the keyboard; a window open for another display
moves to the active one.

The main window never lists other Desktops' labels (the Labels pane does). It opens on the display whose menu bar was
clicked and labels that display's Desktop on screen.

## Editor (FR-004 to FR-009)

Opened from the main window's "Style and Preview…" (in the same panel; Cancel returns to the main window), for the
Desktop on screen of one display.

- Header: "Label this Desktop" and the display's name.
- Label field: focused; holds the current label, selected, or is empty.
- Preview: this Desktop's wallpaper with the label as it would be applied (research R6).
- Style: Automatic (with the choice it makes, for example "Automatic: frosted"), Plain, Halo, Frosted; each shown as a
  small render over this wallpaper.
- Color: Automatic, Light, Dark, Custom (a color well; stored as `#RRGGBB`).
- Position: the six positions, as a small grid (top-left, top, top-right, bottom-left, bottom, bottom-right).
- Size: Small, Medium, Large.
- Buttons: [labeled] "Remove Label", "Cancel", "Apply" (default, Return).
- Escape, Cancel and a click outside close it with no change (no confirmation).

Color, position and size are always shown; there is no "More options" fold (prototype review round 9).

### Editor messages (FR-008, FR-009)

Input rules (prototype review round 3): line breaks and control characters (including tabs and text-direction marks)
typed or pasted are left out of the text, so they never need a message; Return applies; Shift-Return and Option-Return
do nothing; an empty field turns Apply off with no message. Applying asks for no confirmation; Undo is offered.

One sentence, under the field, shown instead of enabling Apply. The core's own sentences are used where they exist
(`LabelText`, `DnmError`), so the app and `dnm` say the same thing, except where the app's wording differs:

| Case | Message |
|---|---|
| Empty | none (Apply off) |
| Too long | "A label can have at most 30 characters; this one has N." |
| Unsupported wallpaper | One sentence naming the kind, with no reason clause and no "yet" (no Apply): "Dynamic wallpapers are not supported." Likewise "Shuffling wallpapers…", "Aerial wallpapers…" and "Apple catalog wallpapers are not supported." A file that is not a readable picture: "Cannot read wallpaper ‘<file name>’." No wallpaper file (a solid color, a full-screen app's Space, or a type with no file): "This Desktop has no wallpaper picture to label." The core has the same two sentences, followed by "Nothing was changed." (`DnmError.unreadableWallpaper`, `.noWallpaperFile`) |
| Original missing (Remove) | the core's `originalMissing` sentence |
| Store newer than the app | the core's `newerManifest` sentence, with "this app" for "this tool" and "Update the app." for "Update the tool." |
| A stamp from another store | the core's sentence, with "this app" for "this tool" and "then try again" for "then run again" |
| Any other failure | the core's sentence; the Desktop is left as it was |

A sentence from the core that names a `dnm` option or command is shown with the app's wording for the same action; the
list of such substitutions is part of the tasks and is tested.

## Welcome window (FR-017a)

Shown once: on the first launch for this user, never at a login start, and never again once dismissed. Content: the
app icon and name; what the app does in one sentence; how to start ("To label a Desktop, click <the item> in the menu
bar.", with the item drawn as it looks in the menu bar);
one button, "OK" (default, Return). Closing the window counts as OK. It holds no settings and no actions; Open at login
is in Settings only.

## Settings window (FR-015, FR-016, FR-016a, FR-019)

One window with a sidebar, as in System Settings: the sidebar lists the panes with an icon each, and the pane on the
right has its title at the top and its controls in grouped, rounded sections, a title on the left of each row and
its control or value on the right. No explanatory lines under rows, except the two promises in About.

Sidebar, in order (a gap between groups): General, Clean Up; Configuration, Displays, Labels; About.

The main window's Settings… opens it at General, Configuration… at Configuration, About Desktop Name Manager at About,
"Labels in use" at Labels, and Clean Up… at Clean Up. Launching the app again while it runs opens it at General
(FR-017). It shows the Dock icon while open.

- **General**:
  - System: "Open at login" (a switch, off by default); "Menu bar shows" (Icon and text / Icon / Nothing (hidden)).
  - Hotkey: "Open the main window" with a shortcut recorder, empty by default ("Record Shortcut"), with a clear button (×)
    once a shortcut is recorded; there is a hotkey exactly when a shortcut is recorded, so there is no on/off switch.
    A one-line error when it cannot be claimed: "Another app is using this shortcut. Choose another."
  - New Labels: Style, Color, Position and Size, used for new labels from the main window and the editor. No sample:
    the editor is where a label is seen before it is applied.
- **Clean Up**: the red message when FR-016b holds; Space: "Labeled images use" with the size, and "Older than N days"; Old labeled images: the list with a checkbox each and one in the header to select all, their display,
  reason and size; under it the count and size of the selection (or of the whole list when nothing is selected) and
  "Delete Selected…", off until something is selected; a confirmation sheet naming the count and size. With nothing
  old: "No old images."
- **Configuration**: This Mac: macOS (version and chip), Separate Spaces (on or off, with a symbol), Displays (the
  count; opens Displays). Storage: Labels in use (count and size; opens Labels), Old labeled images (size, with Clean
  Up…), Data folder (the path, shortened with `~`, with Show in Finder). Only what the app can read: no Accessibility
  row (the app does not use it) and no Space-shortcut row (macOS offers no public way to read it).
- **Displays**: one row per display: its name, "Main display" under the main one, and on the right its aliases as
  tags, each with × to remove it, then a small "Add alias" field with +; Return adds. Adding and removing use the
  core's alias operations (`setAlias`, `removeAlias`), so the rules and sentences are `dnm alias`'s: letters,
  numbers, hyphens and underscores, at most 30, not "main", not only digits ("An alias cannot be only digits.", without
  the core's `--display` clause), not a connected display's name. A refusal is one red line under the row; an alias
  already on another display moves, and the row says "<alias> moved here from <display>." No confirmation: removing an
  alias is undone by adding it again.
- **Labels**: the labels in use, with their display and size, and their count and total under them.
- **About**: a header card with the app icon, "Desktop Name Manager", "Version 0.4.0 (34)", and the one-line
  tagline "Labels for your Desktops, right in the wallpaper." (no build date); Privacy: "Needs no permissions" and "Never connects", each with a check
  symbol and one line; Links: "GitHub ↗" (the source repository) and "Acknowledgements ›", which turns the pane to the
  acknowledgements with a back button. As in CodexBar: one row per third-party component shipped in the app bundle
  (transitive ones included), each with a disclosure arrow, its name, its authors, and its license identifier on the
  right (for example "Apache-2.0"); the arrow shows the full license text from the bundle's `Licenses/`, which
  scrolls. No links in the rows. No Updates section (the app
  never connects), no license line, no Copy button.

## Wording (FR-019a)

No window or message names the command-line tool, Terminal, or a `dnm` command or option. Where a core sentence
names one, the app shows its own wording for the same action (see Editor messages).

## Keyboard and VoiceOver (FR-027)

Every control reachable with Tab; Return applies; Escape cancels; the preview's accessibility value describes it; the
red message is text plus a symbol.
