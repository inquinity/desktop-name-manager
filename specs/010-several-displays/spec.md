# Feature Specification: Several Displays in One Command (Feature F3)

**Feature Directory**: `specs/010-several-displays`

**Created**: 2026-11-06

**Status**: Draft

**Target release**: 0.2.2 (roadmap F3, first part: several displays; several Desktops of one display and a label
file, `dnm apply` (F10), are later)

**Input**: User description: "Several displays in one command (roadmap F3, 0.2.2). `set`, `remove` and `undo` act on every display named: the display word and every `--display` value together name the displays (a union, as decided 2026-10-12 in spec 008), and naming the same display more than once is one display. `show` stays one display (its `--json` prints one document) and keeps refusing two different displays with "Multiple displays for a single command are not currently supported." `--desktop N` means Desktop N of each named display. Every display is resolved before anything changes, so a typo or unknown display changes nothing. Then displays are changed in order; at the first failure the command stops, names the displays already changed, and exits with an error (maintainer decision 2026-11-06: stop, no rollback). Undo stays per display with its own 60-second window; `dnm undo main DP` undoes each named display; no new stored data. Amends spec 008 FR-004, which refuses two different displays. Out of scope: several Desktops of one display in one command, and a label file (`dnm apply`, F10)."

## Decisions (maintainer, 2026-11-06)

1. **Scope:** several displays only. Several Desktops of one display in one command, and a list or file of labels
   (`dnm apply`, F10, recorded in the backlog), are later.
2. **A failure part-way stops the command** and names the displays already changed; nothing is rolled back (each
   changed display can be put back with `dnm undo`, within its window).
3. **Undo stays per display**, with its own 60-second window; no record of a "batch" is stored.

## Clarifications

### Session 2026-11-06

- **Q: May `remove` and `undo` take several display words, as in `dnm undo main DP`?**
  - **A**: Yes, `remove` and `undo` only (maintainer). `set` keeps at most one display word plus `--display`, because
    its last word is the label. `show` keeps at most one display (FR-002).
- **Q: With `--desktop`, are the checks that need Desktop N on screen made before any display changes?**
  - **A**: No: they are made when each display is reached (maintainer, after planning; research R4). Public interfaces
    cannot count a display's Desktops or read a Desktop that is not showing without stepping there, about a second a
    step, so a checking pass would double the switching. Resolution, the Accessibility permission and each display's
    undo record are still checked first; a display without Desktop N, or whose Desktop N no longer shows what the
    change produced, fails when it is reached, and the part-way rule (FR-006) applies.

## User Scenarios & Testing

### User Story 1 - Label several displays at once (Priority: P1)

As a user with several monitors, I want to give the same label to several displays in one command, so that
setting up a project across my screens is one line, not one per display.

**Why this priority**: it is the feature; the other stories make it safe.

**Independent Test**: With two displays connected, `main` and `DP`, run `dnm set main "Mail" --display DP`; the
current Desktop of each display shows "Mail", and the output has one confirmation line per display.

**Acceptance Scenarios**:

1. **Given** displays `main` and `DP`, **When** the user runs `dnm set main "Mail" --display DP`, **Then** both
   displays' current Desktops show "Mail", one confirmation line per display, in the order the displays were named,
   exit 0.
2. **Given** `dnm set "Mail" --display main --display DP` (no display word), **Then** the same result.
3. **Given** the same display named twice (`dnm set DP "Mail" --display DP`), **Then** it is labeled once, as today.
4. **Given** style, position, size and color options, **Then** every named display gets the same options, and each
   display's automatic choices (style and text color from its own wallpaper) are made for that display.
5. **Given** a label that already shows on one of the displays, **Then** that display is reported the way a single
   `set` reports it today, and the others are labeled.

---

### User Story 2 - Remove or undo on several displays (Priority: P1)

As a user, I want `remove` and `undo` to take several displays the same way, so that I can clear or take back a
change I made across my screens.

**Independent Test**: After User Story 1, run `dnm remove main DP`; both displays show their original wallpapers.
Within 60 seconds of a `set` on both, `dnm undo main DP` puts both back.

**Acceptance Scenarios**:

1. **Given** labels on `main` and `DP`, **When** the user runs `dnm remove main DP` (or `dnm remove main --display
   DP`, or `dnm remove --display main --display DP`), **Then** both are removed and each original wallpaper is back,
   one line per display.
2. **Given** one of the named displays has no label, **Then** that display reports "No label on ..." as a single
   `remove` does today, and the others are removed; this is not a failure.
3. **Given** a `set` on both displays less than 60 seconds ago, **When** the user runs `dnm undo main DP`, **Then** each display gets back what it showed before, one line per display.
4. **Given** one named display has nothing to undo (or its window has passed), **Then** the command changes nothing
   on any display and says which display cannot be undone and why (exit 1); the user can undo the others by naming
   only them.

---

### User Story 3 - A mistake changes nothing (Priority: P1)

As a user, I want a typo in any display name, or any invalid option, to stop the command before any display changes,
so that I never end up with half my screens changed by a command that was wrong from the start.

**Independent Test**: Run `dnm set main "Mail" --display NoSuchDisplay`; it exits 2, as a single command with that
display does today, prints the resolver's message for `NoSuchDisplay`, and `main` is unchanged.

**Acceptance Scenarios**:

1. **Given** one named display matches nothing, is ambiguous, or is an alias of a display that is not connected,
   **Then** the command fails with the same message a single command gives for that display, and no display changes.
2. **Given** an invalid label or option (for example a label of 31 characters), **Then** the command fails as a
   single command does, before any display is resolved or changed.
3. **Given** two different displays for `show` (`dnm show main --display DP`), **Then** it still exits 2 with
   "Multiple displays for a single command are not currently supported."

---

### User Story 4 - A failure part-way says what changed (Priority: P2)

As a user, I want to know exactly which displays were changed when something fails after the first display, so
that I can undo them or finish the rest by hand.

**Independent Test**: With the fake wallpaper system (no real wallpaper), make the second of three displays fail to
set its wallpaper; the first is labeled, the third is not touched, and the error names the display that failed and
the display already changed.

**Acceptance Scenarios**:

1. **Given** three named displays and a failure on the second (for example macOS refuses the wallpaper, or that
   display's original wallpaper can no longer be found), **Then** the first display stays changed, the third is not
   attempted, the command exits 1, and the message names the failed display, its error, the displays already changed,
   and that `dnm undo` with those displays puts them back.
2. **Given** a failure on the first display, **Then** nothing changed, and the message is the one a single command
   gives.

---

### User Story 5 - Several displays with `--desktop` (Priority: P3)

As a user who labels Desktops that are not on screen, I want `--desktop N` with several displays to mean Desktop N
of each display.

**Independent Test**: With Accessibility granted and at least two Desktops on each of two displays, run
`dnm set main "Notes" --display DP --desktop 2`; Desktop 2 of each display shows "Notes", and each display returns
to the Desktop it was on.

**Acceptance Scenarios**:

1. **Given** `--desktop 2` and two displays, **Then** each display is switched to its Desktop 2, labeled, and
   returned, one display after the other, as a single `--desktop` command does today.
2. **Given** the second display has fewer than N Desktops, **Then** the first display is labeled, the command stops
   at the second with the message a single command gives, and the part-way rule (User Story 4) applies; a failure on
   the first display changes nothing.
3. **Given** Accessibility is not granted, **Then** the command fails before anything changes, as today.

---

## Edge Cases

- **Order**: displays are changed in the order they were named: the display words first, then each `--display` value
  in the order given; a repeated display keeps its first place.
- **Two names for one display** (`main` and the built-in display's name, or an alias and its display's name) are one
  display, as naming the same display twice is.
- **An alias overridden by a display's name** prints the override warning once for that name, as today, and the
  command continues.
- **One display named** (any of the forms that work today) behaves exactly as in 0.2.1: same output, same exit
  status, same errors.
- **The cleanup reminder** (spec 009) is considered once, after the whole command, never once per display.
- **A display disconnected during the command**: it fails as a single command would at that point, and the
  part-way rule (User Story 4) applies.
- **Two displays showing the same image** (macOS copies a Desktop's wallpaper to new Desktops): each display is
  labeled from its own current wallpaper; reuse (spec 009) works per display, since a labeled image belongs to one
  display.
- **Exit status**: 0 when every display succeeded (including "No label on ..." for `remove`); otherwise the status a
  single command gives for the error that stopped it.
- **How several displays are written**: `remove` and `undo` take any number of display words (`dnm undo main DP`);
  `set` takes at most one display word, because its last word is the label (spec 008: too many words is an error,
  never a guess), and further displays with `--display`. An unquoted name with a space (`dnm remove LG Ultra`) is two
  words: each must resolve on its own, or the command fails before anything changes (FR-003).

---

## Requirements

### Functional Requirements

- **FR-001**: `dnm set`, `dnm remove` and `dnm undo` MUST act on every display named. The display word and every
  `--display` value together name the displays; naming the same display more than once (by the same or a different
  name) MUST count as that one display. `remove` and `undo` MUST accept any number of display words; `set` MUST accept
  at most one display word (its last word is the label) and further displays with `--display`. This amends spec 008
  FR-002, FR-004 and FR-006 for these three commands.
- **FR-002**: `dnm show` MUST keep refusing two or more different displays (exit 2) with "Multiple displays for a
  single command are not currently supported."; spec 008 FR-004 still applies to it.
- **FR-003**: Before changing any display, the command MUST validate the label and options, resolve every named
  display with the single resolution algorithm (spec 006), and, for `undo`, check that each display has a change it
  can undo (with `--desktop`, as far as FR-004 allows); any failure MUST change nothing and give the message a single
  command gives.
- **FR-004**: With `--desktop N`, before changing any display the command MUST check the Accessibility permission (as
  today) and, for `undo`, that each display has an undo record within its window. Desktop N of each display is then
  changed in turn, each display returning to the Desktop it was on. Checks that need Desktop N on screen (that it
  exists; for `undo`, that it still shows what the change produced) MUST be made when that display is reached, and a
  failure there follows FR-006 (Clarifications, 2026-11-06).
- **FR-005**: Displays MUST be changed in the order named: the display words in order, then each `--display` value in
  order, duplicates removed, keeping the first.
- **FR-006**: At the first failure while changing displays, the command MUST stop, MUST NOT attempt the remaining
  displays, MUST leave the displays already changed as they are, and MUST exit with the failing error's status. The
  message MUST name the failed display and its error, every display already changed, and the `dnm undo` command (with
  those displays) that puts them back.
- **FR-007**: The output MUST be one line per display, the line a single command prints for that display today, in
  the order the displays were changed.
- **FR-008**: Each display's change MUST be recorded and undone exactly as a single command's is today: one undo
  record per display, with its own 60-second window. No new stored data and no change to the stored data's format.
- **FR-009**: With exactly one display named, every command MUST behave exactly as in 0.2.1 (output, exit status and
  errors).
- **FR-010**: How the words and flags are read MUST stay in the one interpretation function in the core library
  (spec 008 FR-005), which now returns the resolved displays in order; the commands contain no display matching of
  their own.
- **FR-011**: The cleanup reminder (spec 009) MUST be considered at most once per command, after every display.
- **FR-012**: Tab (spec 007) MUST keep offering displays and usable aliases for every `--display`, including a
  repeated one, and for every display word of `remove` and `undo`.
- **FR-013**: The help of `set`, `remove` and `undo`, the README, the CLI contracts and the release notes MUST
  describe several displays, with an example that writes the displays before the label; spec 008's FR-004 and
  clarification, and the README's statement that two displays are not supported, MUST be amended.

## Success Criteria

- **SC-001**: A table-driven test lists every invocation in this specification (legitimate ones and errors, in the
  order they appear) with the displays it resolves to, in order, against the interpretation function.
- **SC-002**: With the fake wallpaper system, tests show that every refusal in User Stories 2 to 5 changes no display
  and no stored data, and that a failure on the second of three displays leaves exactly the first changed.
- **SC-003**: Every command line that works in 0.2.1 with one display gives the same output and exit status (the
  existing positional syntax suite passes unchanged, except the cases that expected the "Multiple displays" refusal
  for `set`, `remove` and `undo`).
- **SC-004**: A live check labels, removes and undoes on every connected display in one command each, and returns
  every wallpaper to its original, on the maintainer's Mac with two or more displays, before 0.2.2 is released.
- **SC-005**: `just test` and `just periphery` pass.

## Assumptions

- Labeling several displays is the common case for this feature (a project name on every screen); different labels
  per display stay one command per display until a label file (F10) exists.
- `--desktop` with several displays is rare; it keeps today's Accessibility rules and switching behavior per display.
- Changing one display at a time in order is fast enough (a single `set` takes about a second); no parallel changes.
- The live scripts' existing checks that two displays are refused for `set`, `remove` and `undo` change to checks
  that both are changed; the `show` refusal check stays.
