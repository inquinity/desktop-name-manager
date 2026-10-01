# Feature Specification: Desktop Labels and the `dnm` Command-Line Tool

**Feature Branch**: `n/a (spec directory 001-labels-and-cli; work happens on main)`

**Created**: 2026-09-28

**Status**: Draft

**Input**: User description: "Labels and the `dnm` CLI: stamp a per-Desktop label (with automatic plain/halo/frosted style and text color from sampling the background, default fixed corner bottom-left, size, position, emoji) into a copy of that Desktop's wallpaper and set it as that Desktop's wallpaper; list Desktops; set, show, and remove labels via the CLI (`dnm`, alias `desktop-name`); removing a label restores the original image and its placement exactly; no macOS permissions required; no network or telemetry."

## Clarifications

### Session 2026-09-30

- Q: Should this version include an `undo` command for the last label change within the
  cool-down? → A: Yes. One level only: it reverses the most recent set, replace or remove on
  the current Desktop of a display while the cool-down has not expired.
- Q: Which display do the commands act on when the user does not say? → A: The main display.
  Users pick another display with `--display`, given as the display's name as macOS shows it
  (for example "Built-in Display") or a partial name that matches only one display
  (for example "Built"). `main` always works. Position keywords (here, left, right) and
  numbered displays are rejected as a rabbit hole; short monitor aliases come later with
  display roles (spec 004). A `displays` command lists the displays. The graphical app
  (spec 002) decides its target from where the user interacts.
- Q: When a label is set on a Desktop that already has one and some options are omitted, do
  the omitted options keep the old look or reset? → A: They reset to the automatic defaults
  (style and color re-analyzed, default position and size). The result of a set depends only
  on the command given and the wallpaper, never on the previous label.
- Q: Should label length be limited, and what happens past the limit? → A: Yes. A label is
  a single line of at most 30 characters (each emoji counts as one character). Line breaks
  and anything longer are rejected with a message naming the rule that was broken, and
  nothing changes. Multi-line labels are not part of this version and are a backlog item;
  starting strict is safe because a limit can be loosened later without breaking anyone.
- Q: What format do machine-readable outputs use? → A: JSON, selected with `--json`, the same
  on `list`, `show` and `displays` and designed to be piped to `jq`. The tool does not
  include or depend on `jq`.
- Q: What happens when the wallpaper image cannot be read because macOS denies access (for
  example a protected folder)? → A: The tool shows the system's permission error (text in the
  CLI; a message box in the app, spec 002), makes no change, and exits with a failure code.
  It never asks for, works around or requires the permission itself.

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
   label is replaced (not drawn on top of the old one), the original wallpaper is still the
   one recorded for restoring, and any option the user did not give uses its automatic
   default rather than the old label's value.
4. **Given** a labeled Desktop, **When** the Mac restarts or the user reorders Desktops or
   uses Show Desktop, **Then** the label is still on the same Desktop.

---

### User Story 2 - Remove a label and get the original back exactly (Priority: P1)

The user removes the label from a Desktop. Its wallpaper returns to exactly what it was
before labeling: same image, same placement (fill, fit, stretch, center or tile), same
background color. If the user removes or replaces a label by mistake, an undo command
reverses the last change for a short time afterwards.

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

4. **Given** a Desktop whose label was just removed or replaced, **When** the user runs undo
   within the cool-down, **Then** the Desktop returns to exactly what it showed before that
   change (the previous label, or the original wallpaper if it had none).
5. **Given** the cool-down has expired, or there is nothing to undo, **When** the user runs
   undo, **Then** nothing changes and the tool says why.

---

### User Story 3 - Control the look of a label (Priority: P2)

The user chooses where the label goes (a corner or another anchor position), how large it
is, its text color, and its style (plain, halo, frosted), overriding the automatic choice.
Labels are a single line and may contain emoji.

**Why this priority**: The automatic defaults cover most users, but people have strong
preferences about placement and size, and emoji labels are part of the promised
experience.

**Independent Test**: Set a label containing an emoji with an explicit corner, size,
style and color, and confirm each choice is visible in the result.

**Acceptance Scenarios**:

1. **Given** no options, **When** a label is set, **Then** it appears in the bottom-left
   corner at the default size.
2. **Given** explicit position, size, style and color, **When** a label is set, **Then** the
   result reflects each option and the tool rejects invalid values with a clear message.
3. **Given** a label containing an emoji, **When** it is set, **Then** the emoji is drawn
   without clipping or garbled characters.
4. **Given** a label over 30 characters or containing a line break, **When** it is set,
   **Then** it is rejected with a message naming the rule that was broken, and nothing
   changes.
5. **Given** a label within the limits and a very small display or a large size option,
   **When** it is set, **Then** the label is fully visible on screen and never drawn
   off-screen or clipped.

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
2. **Given** any Mac, **When** the user runs list, **Then** the output states that only labeled
   and current Desktops are shown, even when nothing is left out (so the note is always
   present, not only when Desktops are omitted).
3. **Given** a labeled Desktop, **When** the user runs show, **Then** every label property
   is printed, in both human and machine-readable forms.
4. **Given** the tool is run with `desktop-name` instead of `dnm`, **Then** behavior is
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

1. **Given** a fresh user account with no privacy permissions granted and a wallpaper in a
   normal location, **When** any command is run, **Then** the tool asks for nothing and the
   command works.
2. **Given** the current Desktop uses a dynamic, aerial or shuffling wallpaper, **When** the
   user sets a label, **Then** the tool makes no change and explains that this wallpaper
   type is not supported yet.
3. **Given** a wallpaper image macOS will not let the tool read, **When** the user sets a
   label, **Then** the system's error is shown, nothing changes, and the exit code reports
   failure.
4. **Given** any command, **When** it finishes, **Then** it has made no network connection
   and written no telemetry.

---

### Edge Cases

- The Desktop's wallpaper is a solid color rather than an image.
- The wallpaper image is very large (5K and above), very small, or has an unusual aspect
  ratio or color profile; the label stays legible and the result keeps the image quality.
- Two displays show different wallpapers; only the targeted display's current Desktop
  changes.
- A display named in `--display` is not connected, or two connected displays share a name;
  the tool lists the candidates and changes nothing.
- The label text is empty, only whitespace, or contains characters that are hard to draw;
  the tool rejects or handles it with a clear message.
- The label is exactly 30 characters; it is accepted and fully visible.
- The wallpaper image is in a location macOS refuses the tool access to; the tool reports the
  system's error, changes nothing, and does not ask for the permission.
- The disk is full or the tool's storage location is not writable; the wallpaper is left
  as it was.
- A stamp file is deleted by the user while a Desktop still uses it; `show` and `list` flag
  the missing file, setting the label again rebuilds it from the recorded original, and
  `remove` still restores the original.
- The user changes the wallpaper by hand in System Settings after labeling; the tool
  treats the new wallpaper as the new original and does not later restore an outdated one.
- Labeling the same Desktop repeatedly does not accumulate stamp files without bound.
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
- **FR-006**: Labels MUST support emoji. A label is a single line; line breaks are not
  supported in this version.
- **FR-007**: The system MUST validate label text and options and reject invalid input with a
  clear message and no change to the wallpaper. A label MUST have at least one visible
  character, contain no line break, and be at most 30 characters (each emoji counts as one
  character).
- **FR-008**: Removing a label MUST restore the Desktop's original image, placement mode and
  background color exactly as they were before the first label was applied.
- **FR-009**: Replacing a label MUST NOT change the recorded original; only the first
  labeling of an unlabeled Desktop records it. A replacement MUST apply the automatic
  default to every option the user does not give, and MUST NOT inherit values from the
  label it replaces.
- **FR-010**: The system MUST retain the information needed to restore and to list labels in
  local storage under the user's account, and MUST NOT modify the original wallpaper file.
- **FR-011**: The system MUST provide a command to list Desktops with their labels and mark the
  current Desktop on each display, with human-readable output or JSON (FR-025). Only
  labeled Desktops and the current Desktop of each display are listed, and the output MUST
  say so: the human-readable output MUST end with a visible note that only labeled and
  current Desktops are shown, and the JSON output MUST carry the same note as a
  field, so a reader never mistakes the list for every Desktop.
- **FR-012**: The system MUST provide a command to show one label's full details.
- **FR-013**: The command-line tool (set, remove, undo, list, show, displays) MUST be invocable as both `dnm` and `desktop-name` with
  identical behavior, and MUST return distinct, documented exit codes for success, invalid
  input, unsupported wallpaper, and failure.
- **FR-014**: The system MUST decline, without changing anything, to label a Desktop that uses
  a dynamic, aerial, catalog or shuffling wallpaper, or one for which the system reports no
  wallpaper file, and MUST say why. Detection is by the wallpaper file itself.
- **FR-015**: Labeling MUST require no macOS permissions and no elevated privileges, and the
  tool MUST NOT request any. If macOS denies access to a file the tool needs (for example a
  wallpaper image in a protected folder), the tool MUST show the system's error, make no
  change, and exit with a failure code (FR-013); it MUST NOT try to work around the denial.
- **FR-016**: The system MUST NOT make network connections and MUST NOT collect telemetry.
- **FR-017**: The system MUST NOT require disabling System Integrity Protection or any other
  system security setting.
- **FR-018**: The system MUST clean up stamps that no Desktop uses, so storage does not grow
  without bound, subject to these rules:
  - it MUST never delete a stamp that any Desktop still uses;
  - it MUST keep every unused stamp for a fixed cool-down of 30 minutes so a removed or
    replaced label can still be recovered;
  - cleanup MUST happen only while a command is running, using each stamp's age. No
    background process, scheduled job or service is allowed for it;
  - it MUST delete only files the tool itself created (recognizable by name, FR-026) and
    MUST NOT delete any other file, whatever folder the store is placed in.
- **FR-019**: Setting a label MUST complete in under one second for a typical 5K wallpaper on
  an Apple-silicon Mac.
- **FR-020**: The label-rendering logic MUST be usable by later features (the app, Quick
  View) as a shared component, not only through the command line.
- **FR-021**: The tracked repository MUST NOT contain personal paths, user names, display or
  Desktop identifiers, or personal images in tests, fixtures, docs or examples.
- **FR-022**: The system MUST provide an `undo` command that reverses the most recent label
  change (set, replace or remove) on the current Desktop of a chosen display, restoring its
  exact previous state, as long as the cool-down in FR-018 has not expired for that change.
  Undo is one level only: after an undo there is nothing further to undo for that Desktop.
  Undo acts on the most recent change made on the display, and only while the display's
  current wallpaper is still the one that change produced.
  When undo is not possible (expired, nothing to undo, or the needed copy is gone), it MUST
  change nothing and say why.
- **FR-023**: Commands that act on a Desktop (set, remove, undo, show) MUST act on the current
  Desktop of the main display unless the user passes `--display`. The option MUST accept
  `main`, a display's name exactly as macOS shows it, or a case-insensitive partial name that
  matches exactly one connected display. A value that matches no display or more than one
  MUST be rejected with the candidates listed and no change made. Numbered displays and
  position keywords MUST NOT be accepted.
- **FR-024**: The system MUST provide a `displays` command that lists the connected displays
  by name and marks the main display, in human-readable form or JSON (FR-025), so users
  can see what `--display` will accept.

- **FR-025**: Commands that report information (`list`, `show`, `displays`) MUST offer a
  `--json` option that prints a single JSON document to standard output with a consistent
  structure across commands and nothing else on that stream, so it can be piped to tools such
  as `jq`. Diagnostics go to standard error. The tool MUST NOT bundle or require `jq`.

- **FR-026**: Every file the tool writes into its store MUST be named `<id>.dnm.<ext>`, where
  `<id>` is a random identifier and `<ext>` is the image format's extension, so the tool can
  tell its own files from any other file. The tool MUST recognize its files by this name
  pattern together with its manifest, never by the image format alone.

### Key Entities

- **Desktop**: One Space on one display, identified by the system and stable across
  restarts and reordering. Has a current wallpaper and at most one label.
- **Label**: The text and look for a Desktop: text (one line), style, position,
  size, text color, and whether each was chosen automatically or by the user.
- **Original wallpaper record**: What the Desktop showed before its first label: the image
  reference, placement mode, and background color. Used to restore exactly.
- **Stamp**: The labeled copy of the original image that the system currently shows for a
  labeled Desktop. Owned by this tool; safe to delete once unused.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A label appears on the current Desktop in under one second from running the
  command, for a 5K wallpaper on a supported Mac.
- **SC-002**: On the local test set of at least 20 varied wallpapers, 100% of automatically
  styled labels are legible, where legible means that in the finished image the label's text
  has a contrast ratio of at least 3:1 (the WCAG threshold for large text) against the pixels
  directly behind it, for at least 95% of those pixels, after any halo or frosted backing.
  This is checked by an automated measurement and a manual review of every rendering.
- **SC-003**: After label then remove, the Desktop's wallpaper settings and image are
  identical to their pre-label state in 100% of test runs, including non-default placement
  modes.
- **SC-004**: Across every command on wallpapers in normal locations, the tool requests no permissions, zero network
  connections are made, and the original wallpaper files are byte-for-byte unchanged.
- **SC-005**: A first-time user can label a Desktop by following the README's one example,
  in under one minute, without consulting other documentation.
- **SC-006**: Thirty minutes after the last label change, the next command run leaves no stamp
  on disk except those still active or retired within the cool-down, even after 100
  consecutive relabelings of one Desktop.
- **SC-007**: In 100% of test runs, undoing a removal or replacement within the cool-down
  returns the Desktop to a state identical to the one before the change.

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
  once spike S2 proves it. Because of this gap, the list output always carries a caveat
  saying so (FR-011).
- Backlog candidate (not in any current spec): multi-line labels.
- Dynamic, aerial and shuffling wallpapers are out of scope here and refused (spec 006).
- The graphical app, menu-bar item, hotkeys and editor are out of scope (spec 002); groups,
  display roles and sites are out of scope (spec 004); packaging and release are spec 005.
- Defaults from the hand-off: bottom-left corner, single-line labels (30 characters) and emoji allowed, SF Pro
  Semibold font, accent color and Mission Control "large" preset deferred.
- Removing or replacing a label does not delete its stamp. It stays for the cool-down
  period in FR-018, which is what makes the one-level undo in FR-022 possible ("I didn't
  mean to clear that label").
- A Desktop is recognized by the wallpaper file it currently shows; macOS keeps that file
  with its Space across restarts and reordering. This feature reads no Space identifiers.
  Because it cannot see Desktops that are not current, a stamp counts as in use while it is
  the active stamp of a label, and a wallpaper changed by hand in System Settings leaves its
  old stamp on disk.
- Known limitation (FR-022), to revisit later: if two Desktops on one display show the
  identical image, undo cannot tell them apart and acts on the most recent change.
- Intel Macs are deferred, not excluded. The code has no architecture dependency, and macOS 26
  is, to my knowledge, the last release that supports Intel Macs. Correct behavior on
  Apple silicon comes first. Intel support (a universal build) and testing on the
  maintainer's 2019 16-inch MacBook Pro (which, to my knowledge, is on macOS 26's support list)
  are revisited at packaging (spec 005). Until it is tested, Intel support is
  not claimed.
- Cleanup is opportunistic: it runs at the start or end of ordinary commands. If the tool is
  not run for days, old copies simply wait until the next run.
- The minimum supported macOS version follows the constitution's minimum-macOS rule (oldest
  release with no compatibility code). The plan picks the concrete version and records why.