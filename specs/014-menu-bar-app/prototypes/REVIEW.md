# Prototype review: the menu-bar app (spec 014)

The record of the prototype reviews FR-002 asks for. No app code is written before stage 1 is approved (Gate A, task
T011), and the app is not built past the editor before stage 2 is approved (Gate B, task T028). Each approval
records its date here, and contracts/app-ui.md is updated to match it.

- **Stage 1** is the clickable web mockups in `index.html` in this folder, published as a private claude.ai artifact.
- **Stage 2** is the runnable editor (`EditorPrototype`) over a fake wallpaper system and a temporary store.

Mockups and the prototype use only synthetic images and synthetic display names (FR-003).

## Rounds

Add one entry per review round, newest last:

- **Date**
- **Stage**: 1 or 2
- **What was shown**
- **Decisions**
- **Changes made**

### Round 1: 2026-11-15, stage 1

- **What was shown**: `index.html`, published as a private artifact at
  <https://claude.ai/artifact/KRA1BURSSodgeypy4wjQri> (version 1; version 2 after this round). It has 28 states:
  - the editor: 10 states, in two variants, with position, size and color behind "More options" or always shown;
  - the menu-bar item and menu: 6 states;
  - the hotkey panel and the welcome window;
  - Settings: 7 states (General, the hotkey already in use, New labels, and four Clean Up states);
  - About, Help > Configuration, and an app icon draft.

  The mockups can be switched between light, dark and busy synthetic wallpapers, and between Mac light and dark
  appearance.
- **Questions put to the maintainer**:
  1. Editor options: behind "More options", or always shown?
  2. Should an empty field show its sentence before anything is typed?
  3. Is "Automatic picks Frosted for this spot" the right way to show the automatic choice?
  4. A pasted line break: refuse it, as `dnm` does, or join the lines?
  5. Should the newer-store error also say "this app" instead of "this tool"?
  6. Is 24 characters the right width for the menu bar?
  7. Keep ⌃⌥⌘L as the suggested shortcut?
  8. Which welcome button is the default?
  9. Should the Clean Up age be a number field or a menu?
  10. Is the Accessibility row's wording in Configuration clear?
  11. Is the icon's direction right?
- **Decisions** (maintainer, 2026-11-16; states 18 to 28 reviewed, the editor, menu and hotkey states not yet):
  - **No window refers to the command-line tool** (all screens): no `dnm`, no Terminal, no command or option names; a
    person may not know what Terminal is. New FR-019a.
  - **The menu-bar sample label must not be an app's name**: "Mail" beside the app's glyph read as an email app. The
    samples now use labels that cannot be mistaken for apps ("Q4 budget"), and the icon sheet shows the glyph alone.
  - **About** (26): essentials only, with links to the rest (as in a well-made Mac About window). No data folder (moved
    to Settings), no license line, no Copy button; the repository is a link; Acknowledgements is a link to a second
    page in the window; the permissions statement stays but as two approachable items, not a bullet list.
  - **Configuration** (27): displays as a vertical list, each with its aliases; no separate Aliases row; no
    Accessibility row and no Space-shortcut row (the app does not report what it does not use or cannot read); stored
    labels on their own tab; no Copy button.
  - **App icon draft** (28): acceptable, a good start.
  - **Welcome** (18): no configuration in a welcome (Open at login moved to Settings only); no "Label This Desktop"
    button. It is shown once, on the first launch for this user, and never at a login start (answer to "when is it
    shown?"). This settles question 8: there is one button.
  - **Settings, General** (19): no hotkey checkbox; there is a hotkey exactly when a shortcut is recorded. No
    explanatory text at the bottom.
  - **Settings, hotkey in use** (20): acceptable.
  - **Settings, New labels** (21): drop the line under the controls.
  - **Settings, Clean Up** (22): no reference to `dnm cleanup --scan`; no delete-all button: select the images to
    delete (one, several, or all with the header box) and Delete Selected.
  - **Clean Up states 23 to 25**: acceptable, apart from the references to the CLI.
  - **Questions 1 to 7, 9 and 11**: not yet answered. Question 10 (the Accessibility row) is moot: the row is gone.
- **Changes made** (version 2 of the artifact, same link):
  - `index.html`: the sample label is "Q4 budget" and the Clean Up samples are not app names; Welcome has one "OK"
    button; Settings General has a recorder with "Record Shortcut" when empty and × to clear it, Open at login (off by
    default) and the data folder with Show in Finder, and no hint lines; New labels has no hint line; Clean Up has a
    checkbox per row and in the header, a selection total, "Delete Selected…" (off until something is selected), a
    confirmation for the selection, and no `dnm` line; About is the essentials with two promise items, a repository
    link and an Acknowledgements page (new state 27); Configuration has two tabs, This Mac and Stored Labels (new
    state 29); no Copy buttons. 30 states in all, so states after 26 are renumbered.
  - New open questions on the page: Acknowledgements in the window or on GitHub; the name "This Mac" for the first
    Configuration tab; question 7 reworded (whether the empty recorder suggests a shortcut, since there is no hotkey by
    default).
  - `spec.md`: FR-014, FR-015, FR-016, FR-016a, FR-017a and FR-019 rewritten, FR-019a added; User Stories 4 and 5,
    the decisions and the welcome clarification updated. `contracts/app-ui.md` (Welcome, Settings, About,
    Configuration, Wording), `contracts/app-settings.md` (the hotkey keys are absent until a shortcut is recorded;
    `hotkeyEnabled` removed), `data-model.md`, `research.md` (R4, R8, R9), `quickstart.md`, `tasks.md` (T035, T036,
    T044, T047, T049, T051) and `docs/app-and-cli.md` updated to match.

### Round 2: 2026-11-19, stage 1

- **What was shown**: version 2 of the artifact (same link), with 30 states, and a proposal to merge Settings, About
  and Configuration into one window with a sidebar. The maintainer compared it with another menu-bar app's Settings
  window (a sidebar, grouped panes, an About pane with a header card and Links) and its menu-bar panel.
- **Decisions** (maintainer, 2026-11-19):
  - **The menu-bar item opens a main window, not a menu.** It labels this Desktop with the defaults, may show
    important information, shows the space used with a Clean Up button, and leads to the other windows (About,
    Settings, Configuration). Labeling with the defaults from the main window is feasible: it is the editor's Apply
    with the Create Label defaults, on the display whose menu bar was clicked, and needs no permission.
  - **Settings, Configuration and About are reached from the main window** and follow the settings layout of the
    example: one window, a sidebar, grouped panes.
  - **About** shows the about information, the version and links.
  - **Configuration** ("This Mac" renamed) shows the macOS version, Separate Spaces and the space used; Displays shows
    each display with its aliases; both use the settings layout, as do About and Labels.
  - **Settings** holds the defaults, the hotkey and Open at login. The defaults pane is named "Create Label" (the
    note about it was cut off; see the questions).
  - Where the labels in use are shown (main window, General or a Labels pane) is left to this round's proposal.
- **Changes made** (version 3 of the artifact, same link):
  - `index.html`: the menu is replaced by the main window (states 11 to 17): the Desktop line, the red message, a
    field with Label that applies the Create Label defaults (a relabel keeps the label's style), "Style and
    Preview…" for the editor, Remove Label, Undo, "Labels in use" (opens Labels), "Space used" with Clean Up…, and
    Settings…, Configuration…, About Desktop Name Manager and Quit. One Settings window with a sidebar: General (Open
    at login as a switch, Menu bar shows, the hotkey), Create Label (with a sample), Clean Up; Configuration,
    Displays, Labels; About (a header card with version and build date, Privacy, Links with GitHub and
    Acknowledgements). The labels in use get their own pane (proposed), with a count in the main window. 32 states.
  - `spec.md`: the round-2 decision; the clarifications on the quick bar and on listing labels amended; User Stories 2
    and 5; FR-001, FR-004, FR-009, FR-013 rewritten, FR-013a added, FR-014, FR-016 to FR-017 and FR-019 rewritten;
    Assumptions. `contracts/app-ui.md` (Main window, Settings window), `data-model.md` (QuickLabel), `research.md` (R2,
    R7, R8, R10), `plan.md`, `quickstart.md` (scenarios 5, 9 to 11), `tasks.md` (T033, T034, T041, T045, T049 to T051
    and the phase goals) and `docs/app-and-cli.md` updated to match.
- **Questions for round 3**:
  1. The note "Create Label … it should" was cut off: what should the Create Label pane do?
  2. Is "General" right for the pane with Open at login, the menu bar and the hotkey, with the Mac's details under
     "Configuration" (matching the menu item)? Or should the Mac's details be "General"?
  3. The labels in use: a Labels pane (proposed), the main window, or Configuration?
  4. Relabeling from the main window's field keeps the label's style. Should it take the Create Label defaults instead?
  5. Is "Style and Preview…" the right name for the way into the editor?
  6. Should the hotkey open the main window, or the editor (as now)?
  7. Aliases can only be read in the app. Should it let you add and remove them?
  8. Keep the build date in About? It needs a small change to the build stamp.
  9. Is "Labels for your Desktops, right in the wallpaper." the right tagline?
  10. Still open from round 1: questions 1 to 7, 9 and 11, and whether the acknowledgements stay in the window.

### Round 3: 2026-11-19, stage 1

- **What was shown**: version 3 of the artifact (same link), 32 states. State numbers below are version 3's.
- **Decisions** (maintainer, 2026-11-19):
  - **The menu-bar item never shows the label** (2): a label such as "Shutdown" beside an icon looks like an app. The
    item shows the icon and a fixed text, such as "DNM", "dnm" or "Label" (to be chosen). The main window names the
    label.
  - **An empty label just turns Apply off** (4), with no message.
  - **Return applies; Shift-Return and Option-Return are ignored** (5). No confirmation step: Undo is there.
  - **Invalid characters are ignored** (6): line breaks and control characters are left out as typed or pasted.
  - **No "not supported yet"** (8): it implies support that is not decided.
  - **The over-50 MB main window needs work** (14).
  - **Welcome** (19): "It lives in the menu bar, near the clock." goes; people do not talk like that.
  - **No Create Label pane** (22): labeling UI lives elsewhere; no second one.
  - **Clean Up wording** (23, 24): "Older than…" and "No old images."
  - **States 25 and later showed selected text**, which made them harder to review.
  - Asked: how do we get to the editor window? Answer: "Style and Preview…" in the main window, or the hotkey.
- **Changes made** (version 4 of the artifact, same link):
  - `index.html`: the item shows the icon and a fixed text, switchable on the page between DNM, dnm and Label; "Icon
    and text" replaces "Icon and label"; the long-label state is gone. The editor and the main window's field drop
    line breaks and control characters as typed or pasted, ignore Shift-Return and Option-Return, and say nothing
    when empty; the line-break and control-character states are gone. The unsupported wallpaper "can't be labeled".
    The main window has one storage row, "Space used" with "… in old images" under it (red with a warning symbol at
    50 MB) and Clean Up…, instead of a banner plus a second line with other numbers. The welcome says "To label a
    Desktop, click [the item] in the menu bar." The defaults for new labels are a section of General, with no
    sample; the Create Label pane is gone. Clean Up says "Older than" and "No old images." The page no longer leaves
    text selected when moving between states. 28 states.
  - `spec.md`: the round-3 decision; User Stories 2, 3 (now "Reach the app from the menu bar") and 5; Edge Cases;
    FR-008 to FR-012, FR-013a, FR-016, FR-017a; SC-004. `contracts/app-ui.md` (menu-bar item, main window, editor
    input rules and messages, welcome, General, Clean Up), `contracts/app-settings.md` and `data-model.md`
    (`iconAndText`), `research.md` (R2, R5: nothing follows Desktop switches in the background any more), `plan.md`,
    `quickstart.md` (scenarios 5 and 7), `tasks.md` (Phase 6, T047, T049, T050) and `docs/app-and-cli.md` (typed
    line breaks are dropped, not refused) updated to match.
- **Questions for round 4**:
  1. Which fixed text for the menu-bar item: DNM, dnm or Label?
  2. Is the single storage row what "needs work" (14) asked for?
  3. `dnm set` also says "not supported yet". Change the core's sentence for both, or only the app's wording?
  4. Still open from round 2: Labels pane placement, relabel keeping its style, "Style and Preview…", what the hotkey
     opens, editing aliases, the build date, the tagline; from round 1: questions 1, 3, 6 (now moot), 7, 9 and 11, and
     whether the acknowledgements stay in the window. Round 2's question 1 (Create Label) is settled: the pane is gone.

### Round 4: 2026-11-19, stage 1

- **What was shown**: version 4 of the artifact (same link), 28 states. State numbers below are version 4's.
- **Decisions** (maintainer, 2026-11-19):
  - **Unsupported wallpaper** (6): say just "Dynamic wallpapers are not supported."
  - **Acknowledgements** (27): good; they stay in the window, and follow CodexBar's level of detail.
- **Changes made** (version 5 of the artifact, same link):
  - `index.html`: the unsupported state says "Dynamic wallpapers are not supported." The acknowledgements page lists
    each shipped component as in CodexBar: a disclosure arrow, the name, the authors and the license identifier,
    expanding to the license text.
  - `spec.md` (FR-009, FR-019) and `contracts/app-ui.md` (editor messages, About) updated to match.
- **Questions for round 5**:
  1. The other unsupported reasons: "Shuffling / Aerial / Apple catalog wallpapers are not supported." follow the
     same pattern. What should a Desktop with no wallpaper file (a solid color) and an unreadable picture say?
  2. `dnm set` says "This wallpaper is not supported yet: <reason>." Drop "yet" in the core too, or only in the app?
  3. Still open: round 4's questions 1, 2 and 4, without the acknowledgements question (settled).

### Round 5: 2026-11-19, stage 1

- **Decisions** (maintainer, 2026-11-19):
  - **Drop "yet" in the core too** (round-5 question 2): `dnm set` and the app say "This wallpaper is not supported:
    <reason>." in the core's sentence; the app shows its shorter per-kind sentence.
  - **The menu-bar item's text is "DNM"** (round-4 question 1).
- **Changes made** (version 6 of the artifact, same link):
  - `DnmError.unsupportedWallpaper` drops "yet"; its test and `docs/release-notes/UNRELEASED.md` updated.
  - `index.html`: the "Menu-bar text" switch and both settled questions removed; the item shows "DNM".
  - `spec.md` (FR-010) and `contracts/app-ui.md` (menu-bar item) say "DNM".
- **Still open**: round 5's question 1 (the sentences for no wallpaper file and an unreadable picture); round 4's
  question 2 (the storage row); the round-2 questions.

### Round 6: 2026-11-19, stage 1

- **What was shown**: version 6 of the artifact (same link), 28 states. State numbers below are version 6's.
- **Decisions** (maintainer, 2026-11-19):
  - **Menu-bar text "dnm"**, lower case (replaces round 5's "DNM").
  - **An unreadable picture**: "cannot read wallpaper '<file>'" (the app shows "Cannot read wallpaper ‘Lake.heic’.").
  - **No wallpaper file**: options asked for; still open.
  - **"this app" for "this tool"** in the app's sentences (8).
  - **Relabeling keeps the label's style** (10).
  - **The storage row's placement is better** (12), with a little more space between its two lines.
  - **The hotkey recorder stays blank** (15); **General is the right name** (17); **a number field is enough** for
    the age (19); **the labels in use stay in the Labels pane** (25); **the tagline stays** (26).
  - **The Displays pane adds and removes aliases** (24): a minimal expansion, added now.
  - **No build date** (26): the easiest choice; most apps have none.
- **Changes made** (version 7 of the artifact, same link):
  - `index.html`: "dnm" in the menu bar and the welcome; more space in the storage row; a new "Unreadable wallpaper"
    state; "this app" in the error state; Displays shows aliases as tags with ×, an Add alias field with + (Return
    adds), the core's rules and sentences, and a move note; a new "Displays: alias refused" state; no build date;
    the settled questions removed. 30 states.
  - `spec.md` (decision bullet, User Story 3 scenario 6, FR-010, FR-019), `contracts/app-ui.md` (menu-bar item,
    editor messages, Displays, About), `tasks.md` (T051), `quickstart.md` (scenario 11), `research.md` (R8) and
    `docs/app-and-cli.md` (setting aliases moves to Closed) updated to match.
- **Questions for round 7**:
  1. A Desktop with no wallpaper file: which option (see the round-6 reply)?
  2. Should the core's unreadable-picture reason change to match, so `dnm set` says "cannot read wallpaper
     '<file>'" too?
  3. Still open from round 2: "Style and Preview…", what the hotkey opens; from round 1: the open items in the
     Round 1 list.

## Approvals

- **Stage 1 (Gate A)**: not yet approved.
- **Stage 2 (Gate B)**: not yet approved.
