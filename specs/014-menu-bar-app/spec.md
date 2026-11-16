# Feature Specification: The menu-bar app and label editor (Milestone M2)

**Feature Directory**: `specs/014-menu-bar-app`

**Created**: 2026-11-11

**Status**: Draft

**Target release**: 0.4.0 (roadmap M2)

**Input**: User description: "The menu-bar app and label editor (roadmap M2, planned for 0.4.0). A Mac app in
/Applications, running as a menu-bar app over the same core library as `dnm`. The `dnm` command-line tool remains part
of the application: it ships inside the app and the cask still puts `dnm` (and `desktop-name`) on the PATH; everything
the CLI does today keeps working, and the app and CLI share one label store and undo. In scope: a popover editor for the
Desktop on screen (concept A); the current Desktop's label in the menu bar (Icon, Icon and label, Hidden); an optional
global hotkey; Settings; About and Help > Configuration. GUI prototyping is part of this feature: before the real
build, clickable prototypes are made, reviewed and approved by the maintainer, starting from the September 2026 UI
concepts. Packaging the app is an amendment to spec 005. Out of scope: Spotlight and Shortcuts actions, re-stamping on
the next visit, multi-line labels (F5), switching Desktops from the app, Quick View (M3), groups (M4)."

## Background

Since 0.1.0, Desktops are labeled with `dnm`, which stamps the label into a copy of the Desktop's wallpaper. That
suits scripts and people at home in a terminal; it asks everyone else to remember commands, option names and quoting.
M2 adds a Mac app that does the everyday job, labeling the Desktop on screen, from the menu bar: click, type, see the
result before applying it, press Return.

The app is a second front end over the same core as `dnm`, not a replacement. The command-line tool stays part of the
product, installed with the app, and both read and write one store: a label set in the app shows in `dnm list`, and
`dnm undo` can undo it, and the other way round.

## Decisions carried over

- **Product shape** (maintainer, 2026-09-27): a full app in /Applications that runs from the menu bar; launching it
  while it already runs opens Settings, so Settings is always reachable, even with the menu-bar item hidden and the
  hotkey off.
- **Editor** (2026-09-27): concept A, a popover from the menu bar with a live preview and every option.
- **Opening the editor** (2026-09-27): the menu-bar item by default; a hotkey is optional.
- **Menu-bar item** (2026-09-27): Icon, Icon and label, or Hidden.
- **Scope, defaults and release** (2026-11-11): the scope above; Icon and label by default; the hotkey off by default,
  with ⌃⌥⌘L suggested; a Desktop with no label shows the icon only; release 0.4.0. The command-line tool remains part
  of the application. Prototyping the interface is part of this feature.
- **Open questions settled** (maintainer, 2026-11-12):
  - the prototypes come in two stages, web mockups and then a runnable prototype of the editor (FR-001);
  - the menu-bar item follows the active display (FR-012);
  - the app's label defaults apply to the app only (FR-018);
  - a list of the capabilities only one of the app and `dnm` offers is kept up to date; equivalence is the aim, not a
    rule, so it never holds back a new idea (FR-021a).
- **The new-Desktop default is not a hazard** (KI-1, as decided for `dnm`): the app documents it and never warns.

## Clarifications

### Session 2026-11-12

- Q: Should the hotkey open the full editor, or concept B's quick bar (one field and a short "labeled · Undo"
  notice)? → A: The full editor; there is one editor, and no quick bar (FR-014).
- Q: Should the menu show only the current Desktop's label, or list every stored label by display, as concept A's
  menu and `dnm list` do? → A: The current Desktop only; listing labels is Quick View's (M3) (FR-013).
- Q: After a label is applied or removed, should the app show a short notice with Undo, as concept B does? → A: No
  notice; the wallpaper and the menu-bar item show the change, and the menu offers Undo for 60 seconds (FR-013).
- Q: How should the app handle old labeled images building up? → A: A Clean Up section in Settings that lists old
  labels and deletes them after confirming, as `dnm cleanup` does; and when labeled images pass 50 MB, the app shows a
  red message (FR-016a, FR-016b).
- Q: On the first launch, should the app show a welcome window or start silently in the menu bar? → A: A welcome
  window on the first launch only, saying where the app lives, with an "Open at login" choice (ticked) and a button to
  label this Desktop (FR-017a).

## User Scenarios & Testing

### User Story 1 - Prototype the interface and approve it before the build (Priority: P1)

As the maintainer, I want clickable prototypes of the editor, the menu-bar item and its menu, Settings, the About and
Configuration windows, and the edge-case states, so that I can try the design, change it cheaply, and approve it before
the real app is built.

**Why this priority**: every later story builds a screen the prototype settles. Changing a prototype costs minutes;
changing a built, tested, reviewed app costs days.

**Independent Test**: open the prototypes, click through every screen and state listed in FR-001, and confirm none of
it can change the real wallpaper or the label store.

**Acceptance Scenarios**:

1. **Given** the September 2026 UI concepts, **When** the prototypes are made, **Then** they start from those concepts
   and show only what this spec builds: the styles, colors, positions and sizes `dnm set` offers, not the concepts'
   later ideas (another style, opacity, fonts, re-stamping on visit, a moving-wallpaper workaround).
2. **Given** a prototype, **When** the maintainer clicks through it, **Then** every screen and state in FR-001 can be
   reached, with realistic text, on a light and a dark wallpaper, in light and dark mode.
3. **Given** a prototype is running, **When** any control is used, **Then** the real wallpaper and the label store are
   unchanged.
4. **Given** review rounds, **When** the maintainer approves the prototypes, **Then** the approval and the decisions it
   made are recorded in this feature's folder, and the built app matches the approved design (FR-002).
5. **Given** the approved web mockups, **When** the runnable editor prototype is made, **Then** it renders labels with
   the real label rendering over sample wallpapers, so the preview's look and speed (SC-002) can be judged before the
   build.

---

### User Story 2 - Label the Desktop on screen from the menu bar (Priority: P1)

As a person with several Desktops, I want to click the app's menu-bar item, type a label, see it on my wallpaper and
apply it with Return, so that I can label a Desktop without a terminal.

**Why this priority**: it is what the app is for; without it there is no app.

**Independent Test**: with a still-image wallpaper, click the menu-bar item, choose "Label this Desktop…", type a label,
watch the preview, press Return; the Desktop shows the label and `dnm list` reports it.

**Acceptance Scenarios**:

1. **Given** a Desktop with no label, **When** the editor opens, **Then** its label field is empty and focused, the
   preview shows this Desktop's wallpaper, and the editor names the Desktop's display.
2. **Given** a typed label, **When** the text or any option changes, **Then** the preview shows the label as it would be
   applied, over this Desktop's wallpaper, without changing the wallpaper.
3. **Given** a valid label, **When** the person presses Return or clicks Apply, **Then** the Desktop shows the label,
   the editor closes, and the change is the same as `dnm set` with the same options would make (one store, one record).
4. **Given** a labeled Desktop, **When** the editor opens, **Then** the field holds the current label, selected, and the
   options show the label's current style, color, position and size.
5. **Given** a labeled Desktop, **When** the person clicks Remove Label (in the editor or the menu), **Then** the
   original wallpaper and its placement come back, as `dnm remove` does.
6. **Given** the editor is open, **When** the person presses Escape, clicks Cancel or clicks outside it, **Then**
   nothing changes.
7. **Given** a label longer than 30 characters, two lines, or nothing at all, **When** the person types it, **Then** the
   editor says why it cannot be applied, and Apply is unavailable, with the same rules as `dnm set`.
8. **Given** a change made in the app within the last 60 seconds, **When** the person chooses Undo in the menu, or runs
   `dnm undo` for that display, **Then** the change is undone; and a change made with `dnm` can be undone from the app
   within its window the same way.

---

### User Story 3 - See the current Desktop's label in the menu bar (Priority: P2)

As a person switching between Desktops, I want the menu bar to show the label of the Desktop I am on, so that I know
where I am even when windows cover the wallpaper.

**Why this priority**: the label on the wallpaper is hidden whenever windows fill the screen; the menu bar is always
visible. It is second to labeling, which it depends on.

**Independent Test**: label two Desktops, switch between them, and watch the menu-bar item follow; switch the menu-bar
mode in Settings and see it change.

**Acceptance Scenarios**:

1. **Given** the mode Icon and label (the default) and a labeled Desktop on screen, **When** the menu bar is shown,
   **Then** the item shows the app's icon and the label.
2. **Given** a Desktop with no label, or a Desktop whose label `dnm` does not know, **When** the menu bar is shown,
   **Then** the item shows the icon only.
3. **Given** the person switches Desktop, **When** the switch ends, **Then** the item shows the new Desktop's label
   within one second.
4. **Given** a label is set, changed or removed, in the app or with `dnm`, for the Desktop on screen, **When** the
   change ends, **Then** the item shows the new state within one second.
5. **Given** the mode Icon, **When** the menu bar is shown, **Then** the item shows the icon only, whatever the label.
6. **Given** the mode Hidden, **When** the menu bar is shown, **Then** the app has no menu-bar item, and the hotkey (if
   on) and launching the app again still work.
7. **Given** a display is connected, disconnected or rearranged, **When** the change ends, **Then** the item shows the
   label of the Desktop on the display it follows (FR-012).
8. **Given** a long label, **When** it is shown in the menu bar, **Then** it is shown whole or shortened with an
   ellipsis so the menu bar stays usable, and the menu shows it whole.

---

### User Story 4 - Open the editor with a hotkey (Priority: P3)

As a person who labels often, I want an optional keyboard shortcut that opens the editor, so that I can label a
Desktop without reaching for the menu bar, and so that I can keep the menu-bar item hidden.

**Why this priority**: a convenience over Story 2, off by default.

**Independent Test**: turn the hotkey on in Settings, press it on any Desktop, label the Desktop; turn it off and
check the shortcut no longer does anything.

**Acceptance Scenarios**:

1. **Given** a fresh install, **When** Settings opens, **Then** the hotkey is off, and turning it on suggests ⌃⌥⌘L.
2. **Given** the hotkey is on, **When** the person presses it in any app, **Then** the editor opens for the Desktop on
   screen of the active display, as from the menu bar (from the menu-bar item when it is shown; as a floating panel near
   the top of the active display when the item is hidden).
3. **Given** the person picks a shortcut another app or macOS already uses, **When** the app cannot claim it, **Then**
   Settings says so and the hotkey stays off; nothing else is changed.
4. **Given** the hotkey is on, **When** it is used, **Then** no macOS permission is asked for or needed.

---

### User Story 5 - Settings, launch at login, About and Configuration (Priority: P3)

As a person using the app daily, I want to choose how the menu-bar item looks, the hotkey, the options a new label gets,
and whether the app opens at login, and to see the app's version, acknowledgements and configuration, so that the app
fits how I work and I can check its state.

**Why this priority**: the app works with defaults; these make it comfortable and supportable.

**Independent Test**: change each setting and see its effect; quit and relaunch to see them kept; launch the app while
it runs to reach Settings; compare About and Configuration with `dnm about` and `dnm check`.

**Acceptance Scenarios**:

1. **Given** Settings, **When** the person changes the menu-bar mode, the hotkey, or the default style, color, position
   or size, **Then** the change applies at once and is kept after the app quits and the Mac restarts.
2. **Given** "Open at login" is turned on, **When** the person logs in, **Then** the app starts in the menu bar without
   opening a window.
3. **Given** the app runs with the menu-bar item hidden and the hotkey off, **When** the person launches the app again
   (from Finder, Spotlight or the Dock), **Then** Settings opens.
4. **Given** the About window, **When** it opens, **Then** it shows what `dnm about` shows: name, version and build,
   license, source link, where data is kept, the permissions statement, and the acknowledgements with their licenses.
5. **Given** Help > Configuration, **When** it opens, **Then** it shows what `dnm check` shows, as a list, with the same
   results.
6. **Given** a new label made in the editor, **When** the editor opens, **Then** its options start at the defaults
   chosen in Settings, and `dnm`'s own defaults are unchanged (FR-018).
7. **Given** old labels that `dnm cleanup` would list, **When** the person opens Clean Up in Settings, **Then** the same
   labels are listed with the space they use, and nothing is deleted until the person confirms.
8. **Given** old labeled images that Clean Up could free reach 50 MB, **When** the person opens the menu or Clean Up,
   **Then** a red message says how much space they use and points to Clean Up; after cleaning up below 50 MB, it is
   gone.
9. **Given** the app has never run for this user, **When** it is launched, **Then** a welcome window says it lives in
   the menu bar and offers "Open at login" (ticked) and "Label this Desktop"; when the person continues, the choice is
   applied, and the window never shows again.

### Edge Cases

- **A wallpaper the app will not label** (dynamic, aerial or video, several images, shuffle, a color, none): the editor
  opens, says why in one sentence, as `dnm set` does, offers no Apply, and changes nothing.
- **A label `dnm` made with options the editor lacks**: none exist; the editor offers exactly `dnm set`'s options
  (FR-006). If the CLI gains an option later, the editor keeps the label's value of it when only the text changes.
- **The original image is gone** (moved or deleted since the label was set): Remove Label behaves as `dnm remove` does
  for the same case and says what happened; the app offers no new recovery in M2.
- **Two front ends at once**: a label changed with `dnm` while the editor is open: the editor, when applied, works from
  the store as it is then (as two `dnm` commands in a row would), and the menu-bar item shows the result.
- **The store's format is newer than the app** (a later `dnm` wrote it): the app says so and changes nothing, as `dnm`
  does.
- **Separate Spaces is off** (one Desktop across displays): labeling works for the main display as `dnm` does; the
  menu-bar item follows the main display.
- **A full-screen app is in front**: the menu-bar item shows the label of the Desktop under it if macOS reports one,
  else the icon only; the editor labels the Desktop behind the full-screen app only if `dnm set` would.
- **Several displays**: the editor labels the Desktop on screen of the display it was opened on; the menu-bar item
  follows the active display (FR-012).
- **Labeling takes longer than usual** (a very large wallpaper): the editor shows that it is working and cannot be
  applied twice.
- **The first launch is at login** (Open at login set by a previous install, the app's settings kept): the welcome
  window is not shown again; it is per user, once.
- **Launching a second copy** of the app: the running one opens Settings; there is never a second menu-bar item.
- **The app is not running**: `dnm` works as it does today; the app picks up every change the next time it starts.
- **Moved to the Trash while running**: no special handling; out of scope.

## Requirements

### Functional Requirements

**Prototyping**

- **FR-001**: Before the app is built, the feature MUST produce clickable prototypes covering: the editor (empty,
  labeled, typing, an invalid label, a wallpaper that cannot be labeled, working, an error), the menu-bar item in each
  mode with and without a label, the menu (with and without the over-50 MB message), the hotkey panel, Settings
  (including Clean Up with old labels, with none, and while confirming), the welcome window, About, Help >
  Configuration, and the undo offer. They MUST come in two stages: first clickable web mockups of every screen and
  state, to settle the layout and wording; then a runnable Mac prototype of the editor alone, on sample wallpapers, to
  check the preview's look and speed with the real label rendering.
- **FR-002**: The maintainer MUST approve the prototypes before the build starts; the approval, its date and the design
  decisions made in review MUST be recorded in this feature's folder; the built app MUST match the approved design, and
  a later change to the design MUST be approved the same way. Each stage is approved on its own: the web mockups
  before the editor prototype is made, the editor prototype before the app is built.
- **FR-003**: Prototypes MUST NOT change the real wallpaper, the label store or any macOS setting, and MUST NOT contain
  personal images, paths, or display or Desktop identifiers (constitution VIII).

**The editor**

- **FR-004**: The app MUST offer an editor for the Desktop on screen of one display, opened from the menu-bar item's
  menu or the hotkey, holding: the label field, a live preview, the style choices, the color, position and size, and
  Apply, Cancel and Remove Label.
- **FR-005**: The preview MUST show this Desktop's wallpaper with the label as it would be applied, and MUST follow
  every change to the text or options without changing the wallpaper.
- **FR-006**: The editor MUST offer the same choices as `dnm set`: style automatic (chosen from the wallpaper), plain,
  halo or frosted; color automatic, light, dark or a chosen color; the six positions; small, medium or large. Each style
  choice MUST show what that style looks like over this wallpaper.
- **FR-007**: Applying, removing and undoing MUST behave exactly as `dnm set`, `dnm remove` and `dnm undo` do for the
  same Desktop and options: the same checks, refusals, stored records, undo window and results, and the same image for
  the same label, options and wallpaper.
- **FR-008**: The editor MUST check the label as typed with `dnm set`'s rules (one line, 1 to 30 characters, emoji
  allowed) and MUST say in one sentence why a label cannot be applied.
- **FR-009**: Every message the editor or menu shows MUST be a short sentence in plain words, and an error MUST leave
  the Desktop as it was.

**The menu-bar item and menu**

- **FR-010**: The app MUST show a menu-bar item in one of three modes chosen in Settings: Icon and label (default),
  Icon, or Hidden; with no label known for the Desktop it follows, the item MUST show the icon only.
- **FR-011**: The item MUST follow Desktop switches, label changes from either front end, and display changes, showing
  the new state within one second.
- **FR-012**: With several displays, the menu-bar item MUST show the label of the active display (the display with the
  frontmost window), and MUST follow it as the person moves between displays.
- **FR-013**: The menu MUST hold: the Desktop it is about (its display, and its label or "No label"), Label this
  Desktop… (with the hotkey shown when on), Remove Label (only with a label), Undo (only within an undo window),
  Settings…, About, Help > Configuration, and Quit. Applying or removing a label MUST NOT show a separate notice; the
  wallpaper and the menu-bar item are the confirmation. The menu MUST NOT list other Desktops' labels; that is Quick
  View's job (M3).

**Hotkey**

- **FR-014**: The app MUST offer one optional global hotkey that opens the editor, off by default, suggesting ⌃⌥⌘L when
  turned on, changeable in Settings; when the menu-bar item is hidden, the editor MUST open as a floating panel near the
  top of the active display. The hotkey opens the same editor as the menu; the app has no second, smaller labeling
  screen.
- **FR-015**: If the chosen shortcut cannot be claimed, the app MUST say so in Settings and leave the hotkey off.

**Settings and app life**

- **FR-016**: Settings MUST hold the menu-bar mode, the hotkey, the defaults for a new label (style, color, position,
  size) and Open at login (off until the person chooses it, in the welcome window or here), and MUST keep every choice
  across quits and restarts.
- **FR-016a**: Settings MUST include a Clean Up section that shows how much space labeled images use, lists the old
  labels `dnm cleanup` would list (with the same rules as spec 009, for an age the person can change, 30 days by
  default as `dnm cleanup --days`), and deletes them only after the
  person confirms, re-checking the list before deleting, as `dnm cleanup` does. It MUST NOT delete anything by itself.
  Finding labels by visiting every Desktop (`cleanup --scan`) stays in `dnm`, since it needs Accessibility.
- **FR-016b**: When the old labeled images Clean Up could free reach 50 MB (the threshold of `dnm`'s nudge, spec
  009; labels in use are not counted, since Clean Up cannot free them), the app MUST show a red message in the menu and
  in the Clean Up section, saying how much space they use and pointing to Clean Up. The
  message MUST say it in words as well, so it does not depend on color alone, and MUST go away once the images are
  under the threshold.
- **FR-017**: Launching the app while it runs MUST open Settings; only one copy MUST run.
- **FR-017a**: On its first launch only, the app MUST show a welcome window that says the app lives in the menu bar,
  offers "Open at login" (ticked, applied only when the person continues), and offers to label this Desktop (opening
  the editor). It MUST NOT show again, whatever the person chose; closing it counts as continuing with the choice shown.
- **FR-018**: The app's label defaults MUST apply to labels made in the app only; `dnm`'s defaults, options and output
  MUST NOT change, so scripts keep behaving exactly as documented.
- **FR-019**: The About window MUST show the content of `dnm about`, and Help > Configuration the content of `dnm
  check`, each from the same source, so the two never disagree. Each window MUST offer to copy its content as the
  text `dnm` prints, for support requests.

**The command-line tool and the shared store**

- **FR-020**: `dnm` (and `desktop-name`) MUST remain part of the application, installed with it, and every command,
  option, output and exit status MUST work as in 0.3.0, whether or not the app is installed or running.
- **FR-021**: The app and `dnm` MUST share one label store and one undo record: a change from either MUST be seen by the
  other, and neither MUST lose or corrupt the other's records when both act at about the same time.
- **FR-021a**: The list of capabilities that only one of the two offers, `docs/app-and-cli.md`, MUST be updated by this
  feature and by every later spec that adds a capability to only one of them, giving the reason and whether the
  other should gain it. Functional equivalence is the aim, not a rule: a capability may stay in one of them by
  decision.
- **FR-022**: The app MUST read and write the store in the same format as `dnm` 0.3.0 (format 3) unless a new format is
  specified with its migration; an older `dnm` MUST keep reading a store the app has written.

**Constraints**

- **FR-023**: The app MUST use public, documented macOS interfaces only, and MUST need no macOS permission for anything
  in this spec (no Accessibility, no Input Monitoring, no Screen Recording, no Full Disk Access).
- **FR-024**: The app MUST NOT make network connections and MUST NOT collect telemetry, analytics or crash reports.
- **FR-025**: The app MUST NOT require disabling System Integrity Protection or any other security setting.
- **FR-026**: Labeling from the app MUST complete in the same time `dnm set` takes for the same wallpaper (spec 001
  FR-019: under one second for a typical 5K wallpaper on Apple silicon).
- **FR-027**: The app MUST work with VoiceOver and the keyboard alone: every control labeled, the editor usable without
  a pointer (Tab, Return, Escape), and the preview described in words.
- **FR-028**: App Store compatibility stays a goal: the plan MUST record as a known gap that a sandboxed app could not
  share `dnm`'s store or set wallpapers outside its container as this design does; resolving it is left to the App
  Store readiness work in the backlog.

### Key Entities

- **App settings**: the menu-bar mode, the hotkey (on or off, and its keys), the defaults for a new label (style,
  color, position, size), the Clean Up age, and whether the welcome window was shown. Belong to the app, kept per
  user; not part of the label store. Open at login is shown with them but not stored: macOS's login-item status is
  read each time.
- **Label store** (existing, spec 001 and 009): each Desktop's label, options, original image and labeled image, the
  last-seen record, and the undo record. Shared by the app and `dnm`; unchanged in format by this spec.
- **Editor draft**: the text and options being edited, with the preview made from them. Never stored; Cancel drops it.
- **Prototype**: the clickable design and its review record (rounds, decisions, approval date). Kept in this feature's
  folder; never shipped.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A person who has never used the app labels the Desktop on screen in under 15 seconds from clicking the
  menu-bar item, without reading help.
- **SC-002**: The preview reflects a change to the text or an option within a quarter of a second for a typical 5K
  wallpaper on Apple silicon.
- **SC-003**: For 100% of labels in the test set, the image applied from the app is identical to the one `dnm set` makes
  with the same text, options and wallpaper.
- **SC-004**: The menu-bar item shows the right label within one second of a Desktop switch, on two displays, over 20
  switches with no wrong or stale label.
- **SC-005**: Every `dnm` contract test from 0.3.0 passes unchanged with the app installed and running.
- **SC-006**: Running the app and labeling with it asks for no macOS permission on a fresh account.
- **SC-007**: The maintainer approves the prototypes before the first build task starts, and the review finds every
  state in FR-001 reachable.
- **SC-008**: The app sends nothing over the network during a full live test (checked with the network monitor of the
  live checks).

## Assumptions

- The app needs the same macOS as `dnm` (26 or later, Apple silicon); the plan records the minimum and the reasons, as
  the constitution asks.
- The app runs from the menu bar without a Dock icon, and shows one only while a window (the welcome window,
  Settings, About, Configuration) is open.
- Labeling Desktops other than the one on screen, and switching Desktops, stay with `dnm --desktop`; the app needs no
  Accessibility permission in M2.
- Restyling or relabeling other Desktops after a change of defaults is out of scope: a change of defaults affects new
  labels only.
- The "Show on all Spaces" wallpaper setting and the new-Desktop default (KI-1) are handled as `dnm` handles them; the
  September concept's warning is not built.
- The September concepts' extra ideas (a fourth "Pill" style, opacity, fonts, re-stamping on visit, a moving-wallpaper
  workaround, keeping a copy of originals, labels remembered by Desktop) are not part of M2.
- Packaging (the app with `dnm` inside it in the cask, the cask linking `dnm` and `desktop-name`, signing and
  notarizing the app) is specified by an amendment to spec 005, planned alongside this spec.
- Tests use the fake wallpaper system and a temporary store, as `dnm`'s tests do; live checks follow the project's
  live-test rules (back up `Index.plist`, private store, labels removed after).
- Text is English only in M2.
