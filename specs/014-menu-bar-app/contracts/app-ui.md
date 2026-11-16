# Contract: the app's screens, menu and messages (spec 014)

What the person sees and can do. Layout and visual details are settled by the prototypes (FR-001, FR-002); this
contract fixes the content, the behavior and the wording rules the prototypes and the build must both follow. Text in
quotes is the proposed wording; the approved prototype may change wording, and `prototypes/REVIEW.md` records it.

## Menu-bar item (FR-010 to FR-012)

| Mode | Desktop with a label | Desktop without a label (or a label this store does not know) |
|---|---|---|
| Icon and label (default) | icon + label (shortened to 24 characters with "…") | icon |
| Icon | icon | icon |
| Hidden | no item | no item |

It follows the active display (research R5). Its accessibility label is "Desktop Name Manager: <label>" or
"Desktop Name Manager: no label".

## Menu (FR-013, FR-016b)

In order; items in brackets appear only when their condition holds.

1. "<Display name> · <label>" or "<Display name> · No label" (disabled, informational; the label in full)
2. [red] "⚠︎ Old labeled images use <size>. Clean Up…" (when FR-016b holds; opens Settings at Clean Up)
3. separator
4. "Label this Desktop…" (shows the hotkey when it is on)
5. [labeled] "Remove Label"
6. [undo available] "Undo <Label|Remove> on <display>" (`checkUndo` passes; 60-second window)
7. separator
8. "Settings…" ⌘,
9. "About Desktop Name Manager"
10. "Help" ▸ "Configuration…"
11. separator
12. "Quit Desktop Name Manager" ⌘Q

The menu never lists other Desktops' labels (clarification 2026-11-12).

## Editor (FR-004 to FR-009)

Opened from the menu, from the hotkey, or from the welcome window, for the Desktop on screen of one display.

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

Whether position, size and color sit behind a "More options" fold, as in concept A, is decided in prototype review.

### Editor messages (FR-008, FR-009)

One sentence, under the field, shown instead of enabling Apply. The core's own sentences are used where they exist
(`LabelText`, `DnmError`), so the app and `dnm` say the same thing:

| Case | Message |
|---|---|
| Empty | "A label needs at least one visible character." |
| Line break | "A label must be a single line (no line breaks)." |
| Control characters | "A label cannot contain control characters (such as escape, tab or text-direction marks)." |
| Too long | "A label can have at most 30 characters; this one has N." |
| Unsupported wallpaper | "This wallpaper is not supported yet: <reason>. Nothing was changed." (no Apply) |
| Original missing (Remove) | the core's `originalMissing` sentence |
| Store newer than the app | the core's `newerManifest` sentence, with "Update the app." for "Update the tool." |
| A stamp from another store | the core's sentence, with "then try again" for "then run again" |
| Any other failure | the core's sentence; the Desktop is left as it was |

A sentence from the core that names a `dnm` option or command is shown with the app's wording for the same action; the
list of such substitutions is part of the tasks and is tested.

## Welcome window (FR-017a)

First launch only (per user). Content: what the app does in one sentence; where it lives ("in the menu bar, near the
clock"); "Open at login" checkbox, ticked; buttons "Label This Desktop" (opens the editor) and "Done". Closing the
window counts as Done. Either way the login choice is applied and the window never shows again.

## Settings (FR-015, FR-016, FR-016a)

Sections:

- **General**: Menu bar shows (Icon and label / Icon / Hidden); Hotkey (off/on, the recorder, and a one-line error when
  it cannot be claimed: "Another app is using this shortcut. Choose another."); Open at login.
- **New labels**: default style, color, position and size, with a line: "These apply to labels made in the app;
  `dnm` keeps its own defaults."
- **Clean Up**: space used by labeled images; the list of old labels with their display, reason, date and size (as
  `dnm cleanup` lists them); the age ("Older than N days"); "Delete N Labels…" with a confirmation naming the count and
  size; the red message when FR-016b holds; a line saying that finding labels of deleted Desktops by visiting each one
  is `dnm cleanup --scan`.

Launching the app again while it runs opens Settings (FR-017).

## About and Help > Configuration (FR-019)

About: the content of `dnm about` (name, version line, license, source link, data folder, permissions statement,
acknowledgements with license links). Configuration: the rows of `dnm check` with their state symbol; the
Accessibility row explains that it concerns the app running `dnm`, and that this app does not use the permission
(research R8). Both have a "Copy" button that copies the text as `dnm` prints it.

## Keyboard and VoiceOver (FR-027)

Every control reachable with Tab; Return applies; Escape cancels; the preview's accessibility value describes it; the
red message is text plus a symbol.
