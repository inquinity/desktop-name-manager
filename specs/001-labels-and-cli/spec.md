# Feature Specification: Desktop Labels and the `dnm` Command-Line Tool

**Feature Branch**: `n/a (spec directory 001-labels-and-cli; work happens on main)`

**Created**: 2026-09-28

**Status**: Draft

**Input**: User description: "Labels and the `dnm` CLI: stamp a per-Desktop label (with automatic plain/halo/frosted style and text color from sampling the background, default fixed corner bottom-left, size, position, multi-line text, emoji) into a copy of that Desktop's wallpaper and set it as that Desktop's wallpaper; list Desktops; set, show, and remove labels via the CLI (`dnm`, alias `desktop-name`); removing a label restores the original image and its placement exactly; no macOS permissions required; no network or telemetry."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Label the current Desktop (Priority: P1)

A person who uses many Desktops (Spaces) runs one command with a name for the Desktop they
are on, for example "Email" or "Project X". Within about half a second that name appears on
that Desktop's background, legible against whatever wallpaper is behind it. Other Desktops
are unchanged. The name stays with that Desktop across restarts, reordering of Desktops and
Show Desktop.

**Why this priority**: This is the whole point of the product. Everything else builds on a
label that appears on the right Desktop and stays legible.

**Independent Test**: On a Mac with several Desktops, run the set command on Desktop 2 with a
name, then visit Desktops 1, 2 and 3. Only Desktop 2 shows the label, and it is readable.

**Acceptance Scenarios**:

1. **Given** an unlabeled Desktop with a photographic wallpaper, **When** the user sets the
   label "Email", **Then** "Email" appears in the default corner, is legible, and no other
   Desktop changes.
2. **Given** a Desktop with a bright wallpaper and another with a dark wallpaper, **When**
   each is labeled with no style options, **Then** the tool picks a style and text color
   that keeps the label legible on both, and the chosen style is reported to the user.
3. **Given** a labeled Desktop, **When** the user sets a different label on it, **Then** the
   label is replaced (not drawn on top of the old one) and the original wallpaper is still
   the one recorded for restoring.
4. **Given** a labeled Desktop, **When** the Mac restarts or the user reorders Desktops or
   uses Show Desktop, **Then** the label is still on the same Desktop.

---

### User Story 2 - Remove a label and get the original back exactly (Priority: P1)

The user removes the label from a Desktop. Its wallpaper returns to exactly what it was
before labeling: same image, same placement (fill, fit, stretch, center or tile), same
background color.

**Why this priority**: The constitution requires every wallpaper change to be exactly
reversible. Users will not label their Desktops if they cannot get back to where they were.

**Independent Test**: Record a Desktop's wallpaper settings, label it, remove the label, and
compare the settings and image with the recording. They are identical.

**Acceptance Scenarios**:

1. **Given** a labeled Desktop whose wallpaper used a non-default placement, **When** the
   user removes the label, **Then** the original image and that placement are restored.
2. **Given** a Desktop that was never labeled, **When** the user runs remove, **Then**
   nothing changes and the tool says there was no label.
3. **Given** the original image file has been moved or deleted since labeling, **When** the
   user removes the label, **Then** the tool reports that it cannot restore, leaves the
   current wallpaper untouched, and explains what the user can do.

---

### User Story 3 - Control the look of a label (Priority: P2)

The user chooses where the label goes (a corner or another anchor position), how large it
is, its text color, and its style (plain, halo, frosted), overriding the automatic choice.
Labels may span several lines and may contain emoji.

**Why this priority**: The automatic defaults cover most users, but people have strong
preferences about placement and size, and multi-line and emoji labels are part of the
promised experience.

**Independent Test**: Set a two-line label containing an emoji with an explicit corner, size,
style and color, and confirm each choice is visible in the result.

**Acceptance Scenarios**:

1. **Given** no options, **When** a label is set, **Then** it appears in the bottom-left
   corner at the default size.
2. **Given** explicit position, size, style and color, **When** a label is set, **Then** the
   result reflects each option and the tool rejects invalid values with a clear message.
3. **Given** a label with a line break and an emoji, **When** it is set, **Then** both lines
   and the emoji are drawn without clipping or garbled characters.
4. **Given** an over-long label, **When** it is set, **Then** the label is shrunk or wrapped
   to fit on screen, or rejected with a message; it is never drawn off-screen.

---

### User Story 4 - See what is labeled (Priority: P2)

The user lists their Desktops and sees which ones have labels, what the labels say, and
which Desktop is current. They can show the details of one label (text, style, position,
size, color, and whether an original is recorded for restoring). Output is readable by
people and available in a machine-readable form for scripts.

**Why this priority**: Users need to check and script their labels, and later features (the
app, Quick View) rely on the same information.

**Independent Test**: Label two Desktops, run list, and confirm both labels appear with the
current Desktop marked; run show on one and confirm its details match what was set.

**Acceptance Scenarios**:

1. **Given** two labeled Desktops, **When** the user runs list, **Then** both appear with
   their label text and the current Desktop on each display is marked.
2. **Given** a labeled Desktop, **When** the user runs show, **Then** every label property
   is printed, in both human and machine-readable forms.
3. **Given** the tool is run with `desktop-name` instead of `dnm`, **Then** behavior is
   identical.

---

### User Story 5 - Work safely and privately (Priority: P1)

The user can trust the tool: it needs no permission prompts, makes no network connections,
sends no telemetry, never modifies the original wallpaper file, and fails with a clear,
non-destructive message when it cannot do the job (for example on a dynamic wallpaper).

**Why this priority**: These are constitutional constraints (least permission, local-only,
reversible) and gate release.

**Independent Test**: Run every command with network access blocked and no privacy
permissions granted; all succeed. Compare checksums of the original wallpaper files before
and after labeling and removing; they are unchanged.

**Acceptance Scenarios**:

1. **Given** a fresh user account with no privacy permissions granted, **When** any command
   is run, **Then** no permission prompt appears and the command works.
2. **Given** the current Desktop uses a dynamic, aerial or shuffling wallpaper, **When** the
   user sets a label, **Then** the tool makes no change and explains that this wallpaper
   type is not supported yet.
3. **Given** any command, **When** it finishes, **Then** it has made no network connection
   and written no telemetry.

---

### Edge Cases

- The Desktop's wallpaper is a solid color rather than an image.
- The wallpaper image is very large (5K and above), very small, or has an unusual aspect
  ratio or color profile; the label stays legible and the result keeps the image quality.
- Two displays show different wallpapers; only the targeted display's current Desktop
  changes.
- The label text is empty, only whitespace, or contains characters that are hard to draw;
  the tool rejects or handles it with a clear message.
- The disk is full or the tool's storage location is not writable; the wallpaper is left
  as it was.
- The stamped copy is deleted by the user while a Desktop still uses it; the tool detects
  this and can re-create it.
- The user changes the wallpaper by hand in System Settings after labeling; the tool
  treats the new wallpaper as the new original and does not later restore an outdated one.
- Labeling the same Desktop repeatedly does not accumulate stamped files without bound.
- Set is run while the user is on a Desktop in a full-screen app or another situation where
  the current Desktop cannot be determined; the tool reports it and changes nothing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST let a user attach a text label to the current Desktop of a
  chosen display by producing a labeled copy of that Desktop's wallpaper and setting it as
  that Desktop's wallpaper.
- **FR-002**: Setting a label MUST change only the targeted Desktop's wallpaper and MUST NOT
  alter any other Desktop, display, or the original wallpaper file.
- **FR-003**: The label MUST persist with its Desktop across restarts, Desktop reordering
  and Show Desktop, without any background process running.
- **FR-004**: The system MUST choose a label style (plain, halo, or frosted) and a text
  color automatically by analyzing the wallpaper behind the label so the label is legible,
  and MUST report the chosen values.
- **FR-005**: The system MUST place the label in the bottom-left corner by default, and MUST
  let the user choose another position, a size, a text color and a style explicitly.
- **FR-006**: Labels MUST support multiple lines and emoji.
- **FR-007**: The system MUST validate label text and options and reject invalid input with a
  clear message and no change to the wallpaper.
- **FR-008**: Removing a label MUST restore the Desktop's original image, placement mode and
  background color exactly as they were before the first label was applied.
- **FR-009**: Replacing a label MUST NOT change the recorded original; only the first
  labeling of an unlabeled Desktop records it.
- **FR-010**: The system MUST retain the information needed to restore and to list labels in
  local storage under the user's account, and MUST NOT modify the original wallpaper file.
- **FR-011**: The system MUST provide a command to list Desktops with their labels and mark the
  current Desktop on each display, with human-readable and machine-readable output.
- **FR-012**: The system MUST provide a command to show one label's full details.
- **FR-013**: The command-line tool MUST be invocable as both `dnm` and `desktop-name` with
  identical behavior, and MUST return distinct, documented exit codes for success, invalid
  input, unsupported wallpaper, and failure.
- **FR-014**: The system MUST decline, without changing anything, to label a Desktop that uses
  a dynamic, aerial or shuffling wallpaper, and MUST say why.
- **FR-015**: Labeling MUST require no macOS permissions and no elevated privileges, and the
  tool MUST NOT prompt for any.
- **FR-016**: The system MUST NOT make network connections and MUST NOT collect telemetry.
- **FR-017**: The system MUST NOT require disabling System Integrity Protection or any other
  system security setting.
- **FR-018**: The system MUST clean up stamped copies that no Desktop uses, so storage does not
  grow without bound, subject to these rules:
  - it MUST never delete a copy that any Desktop still uses;
  - it MUST keep every unused copy for a cool-down period (default 60 minutes, and no less
    than 30) so a removed or replaced label can still be recovered;
  - cleanup MUST happen only while a command is running, using each copy's age. No
    background process, scheduled job or service is allowed for it.
- **FR-019**: Setting a label MUST complete in under one second for a typical 5K wallpaper on
  supported hardware.
- **FR-020**: The label-rendering logic MUST be usable by later features (the app, Quick
  View) as a shared component, not only through the command line.
- **FR-021**: The tracked repository MUST NOT contain personal paths, user names, display or
  Desktop identifiers, or personal images in tests, fixtures, docs or examples.

### Key Entities

- **Desktop**: One Space on one display, identified by the system and stable across
  restarts and reordering. Has a current wallpaper and at most one label.
- **Label**: The text and look for a Desktop: text (one or more lines), style, position,
  size, text color, and whether each was chosen automatically or by the user.
- **Original wallpaper record**: What the Desktop showed before its first label: the image
  reference, placement mode, and background color. Used to restore exactly.
- **Stamped wallpaper**: The labeled copy of the original image that the system currently
  shows for a labeled Desktop. Owned by this tool; safe to delete once unused.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A label appears on the current Desktop in under one second from running the
  command, for a 5K wallpaper on a supported Mac.
- **SC-002**: On the local test set of at least 20 varied wallpapers, 100% of automatically
  styled labels meet a legibility threshold, checked by an automated contrast measurement
  and a manual review of every rendering.
- **SC-003**: After label then remove, the Desktop's wallpaper settings and image are
  identical to their pre-label state in 100% of test runs, including non-default placement
  modes.
- **SC-004**: Across every command, zero permission prompts appear, zero network
  connections are made, and the original wallpaper files are byte-for-byte unchanged.
- **SC-005**: A first-time user can label a Desktop by following the README's one example,
  in under one minute, without consulting other documentation.
- **SC-006**: One hour after the last label change, the next command run leaves no stamped
  copy on disk except those a Desktop currently uses, even after 100 consecutive
  relabelings of one Desktop.

## Assumptions

- Target users are individuals on a personal Mac who use several Desktops and one or more
  displays; the tool is run from Terminal or a launcher, not by a system administrator.
- Because macOS lets an app change the wallpaper only of the Desktop currently on screen,
  this feature labels the current Desktop of a display; labeling a Desktop that is not
  current is handled by later features (Quick View and switching, spec 003).
- Decided (2026-09-28): listing shows every Desktop this tool has labeled, plus the current
  Desktop of each display, using public interfaces only. Unlabeled, non-current Desktops are
  not listed by this feature. A full Desktop list depends on reading the system's Space list
  through an optional, read-only private interface, and comes with Quick View (spec 003)
  once spike S2 proves it.
- Dynamic, aerial and shuffling wallpapers are out of scope here and refused (spec 006).
- The graphical app, menu-bar item, hotkeys and editor are out of scope (spec 002); groups,
  display roles and sites are out of scope (spec 004); packaging and release are spec 005.
- Defaults from the hand-off: bottom-left corner, multi-line labels and emoji allowed, SF Pro
  Semibold font, accent color and Mission Control "large" preset deferred.
- Removing or replacing a label does not delete its stamped copy. It stays for the cool-down
  period in FR-018, which keeps a later "undo" operation possible ("I didn't mean to clear
  that label"). An undo command is not required by this spec; the cool-down guarantees only
  that the data to build one still exists.
- Cleanup is opportunistic: it runs at the start or end of ordinary commands. If the tool is
  not run for days, old copies simply wait until the next run.
- The minimum supported macOS version follows the constitution's minimum-macOS rule (oldest
  release with no compatibility code). The plan picks the concrete version and records why.