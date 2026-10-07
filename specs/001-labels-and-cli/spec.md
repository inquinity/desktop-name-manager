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

### Session 2026-10-05 (after live use and research, see `docs/research/desktop-association.md`)

- Q: macOS gives every new Desktop a copy of the first Desktop's wallpaper (by reference to the same
  image file), and an app cannot see which Desktops share an image. How does a label relate to a
  Desktop? → A: A labeled image may be shown on any number of Desktops. Every command acts on the
  specified Desktop only and never retires or deletes a labeled image because of what it did there;
  labeled images are deleted only when the user asks (`dnm prune`).
- Q: Can a user label a Desktop other than the current one? → A: Yes, with `--desktop N` (the Desktop's
  number on that display, as Mission Control shows it), so sets of Desktops can be scripted across
  displays. It uses only public interfaces: the standard "Move left/right a space" shortcuts, which need
  the Accessibility permission as an explicit opt-in, and it returns to the Desktop it started on.
- Q: May the product read macOS's private wallpaper store or Space list? → A: No. The product uses public
  interfaces only. The research tools that do read them stay in `prototype/` and are never shipped.
  This includes undocumented system preferences (constitution 2.0.0): the tool cannot check whether the
  Desktop-switching shortcuts are on, so `check` says so and `--desktop` reports it when they fail.
- Q: How does a user see what the tool is and whether their Mac is set up for it? → A: `dnm about` (who
  the tool is, its version and build, and why it asks for any permission) and `dnm check` (this Mac's
  setup, with fixes). The app (spec 002) shows the same content in its About window and in Help >
  Configuration.

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
   within the 30-minute undo window, **Then** the Desktop returns to exactly what it showed before that
   change (the previous label, or the original wallpaper if it had none).
5. **Given** the undo window has passed, or there is nothing to undo, **When** the user runs
   undo, **Then** nothing changes and the tool says why.
6. **Given** a labeled first Desktop and a new Desktop that macOS created with a copy of its labeled
   image, **When** the user removes the label on the new Desktop, **Then** only the new Desktop returns
   to the original image, and the first Desktop keeps its label, which `show` and `remove` there still
   recognize.

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

### User Story 6 - Label a specified Desktop, to build sets across displays (Priority: P2)

The user labels Desktops other than the one they are on, by number, so that a short script can give
matching Desktops on each display the same label:

```sh
dnm set "LABEL1" --display main --desktop 2
dnm set "LABEL1" --display DP   --desktop 2
dnm set "LABEL2" --display main --desktop 3
dnm set "LABEL2" --display DP   --desktop 3
```

The tool switches that display to the Desktop, labels it, and switches back. The person sees the
Desktops slide and must not type while it runs.

**Why this priority**: It turns single labels into sets of labeled Desktops, which is how the maintainer
works, and prepares for groups (spec 004). Labeling the current Desktop (P1) works without it.

Before the first run, `dnm check` shows whether the Mac is ready for it (FR-031).

**Independent Test**: Run the four commands above on a Mac with two displays and at least three Desktops
on each. Each display ends on the Desktop it started on; visiting Desktops 2 and 3 on each display shows
the expected labels; the other Desktops are unchanged.

**Acceptance Scenarios**:

1. **Given** Accessibility is granted, **When** the user runs `set` with `--desktop 2` on a display that
   is showing Desktop 3, **Then** Desktop 2 gets the label and the display is back on Desktop 3 when the
   command ends.
2. **Given** the display has three Desktops, **When** the user asks for `--desktop 5`, **Then** nothing is
   labeled, the display is back where it started, and the tool says the display has three Desktops.
3. **Given** Accessibility is not granted, **When** the user passes `--desktop`, **Then** nothing changes
   and the tool explains how to grant the permission and why it is needed; it never prompts on its own.
4. **Given** `--desktop` is left out, **When** the command runs, **Then** it acts on the current Desktop with
   no switching and no permission. (With `--desktop`, the tool always finds its position by switching, because
   public interfaces cannot tell which Desktop is showing.)
5. **Given** `--desktop` is used with `remove`, `undo` or `show`, **When** the command runs, **Then** it
   acts on that Desktop in the same way and returns.
6. **Given** the user labels Desktop 1 of a display, **When** the command finishes, **Then** the tool also
   notes that macOS copies the first Desktop's wallpaper to new Desktops on that display.

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
- macOS copies the first Desktop's wallpaper (a labeled image included) to every new Desktop on that
  display, and rewrites that default when Desktops are reordered. The tool cannot prevent it; it
  documents it, notes it when `--desktop 1` is labeled, and lets the user fix a new Desktop with
  `remove` or `set` there.
- Labeled images accumulate, because the tool cannot tell whether other Desktops still show one;
  `dnm prune` lists them and deletes them only when the user confirms.
- A full-screen app occupies a Space among the Desktops: the shortcuts that `--desktop` uses step through
  it too, so the count can be off by one and the label land on the full-screen Space, where the wallpaper
  is rarely seen. Documented edge case, not handled: exit full screen first if it matters.
- The "Move left/right a space" shortcuts are turned off, or something else is bound to them: `--desktop`
  stops with a message and changes nothing.
- The display changes Desktop while a `--desktop` command runs (the person switches or creates one):
  the tool stops and reports it rather than labeling the wrong Desktop.
- Set is run while the user is on a Desktop in a full-screen app or another situation where
  the current Desktop cannot be determined; the tool reports it and changes nothing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST let a user attach a text label to a Desktop of a chosen display (the
  current one, or the one given with `--desktop`, FR-027) by producing a labeled copy of that
  Desktop's wallpaper and setting it as that Desktop's wallpaper.
- **FR-002**: Setting a label MUST change only the targeted Desktop's wallpaper and MUST NOT
  alter any other Desktop, display, or the original wallpaper file. (macOS itself copies the first
  Desktop's wallpaper to new Desktops; that is documented, FR-028.)
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
- **FR-008**: Removing a label MUST restore the targeted Desktop's original image, placement mode and
  background color exactly as they were before the first label was applied. It MUST affect only that
  Desktop: other Desktops that show the same labeled image keep it, and the tool MUST still recognize
  the label there.
- **FR-009**: Replacing a label MUST NOT change the recorded original; only the first
  labeling of an unlabeled Desktop records it. A replacement MUST apply the automatic
  default to every option the user does not give, and MUST NOT inherit values from the
  label it replaces. Setting a label on a Desktop that shows a labeled image gives that Desktop a new
  image of its own; other Desktops showing the old one keep it.
- **FR-010**: The system MUST retain the information needed to restore and to list labels in
  local storage under the user's account, and MUST NOT modify the original wallpaper file.
- **FR-011**: The system MUST provide a command to list Desktops with their labels and mark the
  current Desktop on each display, with human-readable output or JSON (FR-025). It lists the labels
  the tool has made and what each display's current Desktop shows; it cannot know which other
  Desktops show a label. The output MUST say so: the human-readable output MUST end with a visible note
  that only dnm's labels and the current Desktops are shown, and the JSON output MUST carry the same
  note as a field, so a reader never mistakes the list for every Desktop.
- **FR-012**: The system MUST provide a command to show one label's full details.
- **FR-013**: The command-line tool (set, remove, undo, list, show, displays, prune, about, check) MUST be invocable as both `dnm` and `desktop-name` with
  identical behavior, and MUST return distinct, documented exit codes for success, invalid
  input, unsupported wallpaper, and failure.
- **FR-014**: The system MUST decline, without changing anything, to label a Desktop that uses
  a dynamic, aerial, catalog or shuffling wallpaper, or one for which the system reports no
  wallpaper file, and MUST say why. Detection is by the wallpaper file itself.
- **FR-015**: Labeling the current Desktop MUST require no macOS permissions and no elevated
  privileges, and the tool MUST NOT request any. Only `--desktop` for a Desktop that is not showing
  needs a permission (Accessibility, FR-027). If macOS denies access to a file the tool needs (for example a
  wallpaper image in a protected folder), the tool MUST show the system's error, make no
  change, and exit with a failure code (FR-013); it MUST NOT try to work around the denial.
- **FR-016**: The system MUST NOT make network connections and MUST NOT collect telemetry.
- **FR-017**: The system MUST NOT require disabling System Integrity Protection or any other
  system security setting.
- **FR-018**: The system MUST keep its storage tidy without risking a wallpaper:
  - it MUST NOT delete a labeled image that was ever applied to a Desktop, except through `prune`
    (FR-029), because other Desktops may still show it;
  - it MUST delete, only while a command is running and after a fixed cool-down of 30 minutes, files
    it wrote but never applied (for example after a crash);
  - it MUST delete only files the tool itself created (recognizable by name, FR-026) and MUST NOT delete
    any other file, whatever folder the store is placed in; no background process, scheduled job or
    service is allowed.
- **FR-019**: Setting a label MUST complete in under one second for a typical 5K wallpaper on
  an Apple-silicon Mac.
- **FR-020**: The label-rendering logic MUST be usable by later features (the app, Quick
  View) as a shared component, not only through the command line.
- **FR-021**: The tracked repository MUST NOT contain personal paths, user names, display or
  Desktop identifiers, or personal images in tests, fixtures, docs or examples.
- **FR-022**: The system MUST provide an `undo` command that reverses the most recent label
  change (set, replace or remove) on a chosen display, acting on the specified Desktop (FR-027), restoring its
  exact previous state, within 30 minutes of that change (the undo window).
  Undo is one level only: after an undo there is nothing further to undo for that Desktop.
  Undo acts on the most recent change made on the display, and only while the display's
  current wallpaper is still the one that change produced.
  When undo is not possible (expired, nothing to undo, or the needed copy is gone), it MUST
  change nothing and say why.
- **FR-023**: Commands that act on a Desktop (set, remove, undo, show) MUST act on the main display
  unless the user passes `--display`, and on that display's current Desktop unless the user passes
  `--desktop` (FR-027). The option MUST accept
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
- **FR-027**: `--desktop N` MUST select the Nth Desktop of the chosen display, numbered as Mission
  Control numbers them (a full-screen app Space among them can shift the count: a documented edge case,
  not handled). The tool MUST use only public
  interfaces: it moves the pointer to that display (and back), uses the "Move left a space" and
  "Move right a space" shortcuts, and confirms each step with the system's public notification that the
  active Desktop changed. It MUST end on the Desktop it started on, also when it fails. Without `--desktop`
  there is no switching and no permission; with it, the tool needs the Accessibility permission: when it is missing, the tool MUST change nothing, say why it is needed and how to grant it,
  and MUST NOT trigger a permission prompt on its own. A Desktop number that does not exist, shortcuts
  that are off, or a step that cannot be confirmed MUST stop the command with a message, return to the
  starting Desktop and label nothing. A Desktop change made by the person during the command (more
  changes announced than steps taken) MUST stop it with a message; the position is then unknown, so the
  tool does not switch back and says so, and if the change came while labeling it says the label may be
  on another Desktop. When no step moves at all,
  the display either has a single Desktop or the shortcuts are off, which public interfaces cannot tell apart;
  the tool MUST then refuse and say both possibilities, rather than risk acting on the wrong Desktop.
- **FR-028**: The documentation MUST explain the macOS behavior that a display's first Desktop provides
  the wallpaper for new Desktops (and that reordering changes which Desktop that is), with the fix
  (`remove` or `set` on the new Desktop, or keep Desktop 1 unlabeled). When `--desktop 1` is labeled,
  the tool MUST say so in its output.
- **FR-029**: The system MUST provide `dnm prune`, which lists the labeled images that are no longer an
  active label (removed, replaced or undone through the tool), with the space they use, and deletes them
  only when the user confirms (`--yes`). It MUST warn that a Desktop still showing one of them would lose
  its wallpaper, and MUST never delete an image currently shown on any display's current Desktop.
- **FR-030**: The system MUST provide `dnm about`: the tool's name, its version as `--version` prints it
  (with the build commit for interim builds), license and source location, where it keeps its data,
  and a plain statement of permissions: labeling the current Desktop needs none; Accessibility is used
  only to switch Desktops (`--desktop`) by pressing macOS's own "Move left/right a space" shortcuts,
  because macOS offers apps no public way to switch Desktops; nothing else is typed or read; no network,
  no telemetry.
- **FR-031**: The system MUST provide `dnm check`, a configuration report using public interfaces only,
  one line per item with its state and, when something is missing, how to fix it: macOS version and
  chip; whether displays have separate Spaces; the connected displays (main marked); whether the app
  running `dnm` has Accessibility; the "Move left/right a space" shortcuts (their state cannot be read
  publicly: the report says so, says where to check them, and that `--desktop` reports it if they are
  off); a one-line reminder of the first-Desktop rule (FR-028); and the stored labels, their space and
  what `prune` could free. It MUST change nothing and MUST NOT trigger a permission prompt. `--json`
  prints the same as one document.

### Key Entities

- **Desktop**: One Space on one display. The system identifies it internally, but public interfaces do
  not expose that identity: the tool can see each display's current Desktop and its wallpaper file, and
  reach another Desktop only by its current number on that display (FR-027).
- **Label**: The text and look for a Desktop: text (one line), style, position,
  size, text color, and whether each was chosen automatically or by the user.
- **Original wallpaper record**: What the Desktop showed before its first label: the image
  reference, placement mode, and background color. Used to restore exactly.
- **Stamp**: A labeled copy of an original image, made by `set`. It may be shown on any number of
  Desktops (macOS copies the first Desktop's wallpaper to new Desktops), so it is never deleted
  automatically once applied (FR-018, FR-029).

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
- **SC-006**: No applied labeled image is ever deleted except through a confirmed `prune`, and files
  written but never applied are gone 30 minutes later, at the next command.
- **SC-007**: In 100% of test runs, undoing a removal or replacement within the undo window
  returns the Desktop to a state identical to the one before the change.
- **SC-008**: The four-command script in User Story 6 labels exactly Desktops 2 and 3 on both displays
  in 100% of live runs on macOS 26 and 27, and each display ends on the Desktop it started on. Time is set
  per step, because a command's steps grow with the number of Desktops: each `--desktop` command finishes
  within **2.5 s plus 1.25 s per Desktop step** (a step is one switch: the walk left to Desktop 1, the walk to
  the target, and the walk back). Measured and recalibrated as described in `docs/research/timings.md`.

## Assumptions

- Target users are individuals on a personal Mac who use several Desktops and one or more
  displays; the tool is run from Terminal or a launcher, not by a system administrator.
- macOS lets an app change the wallpaper only of the Desktop currently on screen, so `--desktop` switches
  to the Desktop first (FR-027). Quick View and switching by label (spec 003) build on the same
  mechanism.
- Decided (2026-09-28): listing shows every Desktop this tool has labeled, plus the current
  Desktop of each display, using public interfaces only. Unlabeled, non-current Desktops are
  not listed by this feature. Public interfaces cannot list every Desktop, so the list output always
  carries a caveat saying so (FR-011); a full list is in the backlog's full-featured build idea.
- Backlog candidate (not in any current spec): multi-line labels.
- Dynamic, aerial and shuffling wallpapers are out of scope here and refused (spec 006).
- The graphical app, menu-bar item, hotkeys and editor are out of scope (spec 002); groups,
  display roles and sites are out of scope (spec 004); packaging and release are spec 005.
- Defaults from the hand-off: bottom-left corner, single-line labels (30 characters) and emoji allowed, SF Pro
  Semibold font, accent color and Mission Control "large" preset deferred.
- Removing or replacing a label does not delete its stamp, which is what makes the one-level undo in
  FR-022 possible ("I didn't mean to clear that label"); the undo window itself is 30 minutes.
- How macOS ties Desktops to wallpapers is documented in `docs/research/desktop-association.md`
  (observed on macOS 27.0.1, and reported the same on 26.7): each Desktop has its own entry; each
  display's default for new Desktops mirrors its first Desktop; new Desktops copy that image at creation;
  switching writes nothing.
- Known limitation (FR-022): undo acts on the most recent change made on the display, and only while the
  specified Desktop still shows what that change produced; it cannot tell apart Desktops that show the
  same image.
- Intel Macs are deferred, not excluded. The code has no architecture dependency, and macOS 26
  is, to my knowledge, the last release that supports Intel Macs. Correct behavior on
  Apple silicon comes first. Intel support (a universal build) and testing on the
  maintainer's 2019 16-inch MacBook Pro (which, to my knowledge, is on macOS 26's support list)
  are revisited at packaging (spec 005). A universal test build passed the main live checks on that
  Mac on macOS 26.7 (2026-10-06, see review-notes.md); Intel support is still not claimed until spec 005
  decides on a universal release build.
- Cleanup is opportunistic: it runs at the start or end of ordinary commands. If the tool is
  not run for days, old copies simply wait until the next run.
- The minimum supported macOS version follows the constitution's minimum-macOS rule (oldest
  release with no compatibility code). The plan picks the concrete version and records why.