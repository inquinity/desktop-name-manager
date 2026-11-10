# Feature Specification: `dnm cleanup --scan` (Feature F9)

**Feature Directory**: `specs/012-cleanup-scan`

**Created**: 2026-11-09

**Status**: Draft

**Target release**: 0.3.0 (roadmap F9), with quiet mode (F7, spec 011)

**Input**: User description: "Create the spec for F9: `dnm cleanup --scan`, which finds labels of deleted Desktops exactly by visiting every Desktop (Accessibility, opt-in). It was stage 2 of spec 009 (FR-011, User Story 4, SC-006, research R7), written before 0.2.0; this spec takes it over and brings it up to date with the display words (spec 008), several displays (spec 010) and quiet mode (spec 011)."

## Background

`dnm` is never told when a Desktop is deleted in Mission Control, so its label and image stay in the store. Spec 009
(0.2.1) added `dnm cleanup`, which guesses by age: a label retired, or not seen showing, for N days (default 30). It
says plainly that a Desktop not on screen might still show an image it deletes, because it cannot look at Desktops
that are not on screen.

The scan removes the guess: it visits every Desktop of every connected display, notes which labeled image each one
shows, and offers to delete the labels that no Desktop shows. It needs the Accessibility permission, as `--desktop`
does, and the person sees the Desktops slide by.

## Decisions carried over from spec 009 (maintainer, 2026-10-10)

- **No command deletes labeled images by itself**; the scan describes, asks, and asks again before deleting.
- **The scan is an inspection**: `--days` does not apply to it.
- **Labels of displays that are not connected are left alone and named**: public interfaces cannot see their
  Desktops (known issue KI-2).
- **Seen during the scan counts as seen**: every label the scan finds showing has its last-seen time updated.
- **Planned for 0.3.0**, a minor version, as a bigger concept (decided 2026-10-10).

## Clarifications

### Session 2026-11-09

- Q: Does `cleanup --scan` take display words to scan only some displays? → A: No; it always scans every connected
  display (FR-010). Display words may be added later.
- Q: What does Ctrl-C during the walk do? → A: `dnm` steps the current display back to the Desktop it started on,
  reports what was scanned, deletes nothing and exits 130; a second Ctrl-C stops at once (FR-015, User Story 3).
- Q: Does the scan show progress while it walks? → A: One line on standard error as each display starts
  (`Scanning DP1…`), on a terminal only, never with `--json`; it is a progress message, not a warning or note, so
  quiet mode does not hide it (FR-016).

## User Scenarios & Testing

### User Story 1 - Find and delete labels of deleted Desktops exactly (Priority: P1)

As a user who deletes Desktops, I want `dnm cleanup --scan` to look at every Desktop and tell me which labels no
Desktop shows, so that I can delete them knowing none is in use.

**Why this priority**: it is the feature: an exact answer instead of the age-based guess.

**Independent Test**: On a display with three Desktops, label all three, delete the second in Mission Control, run
`dnm cleanup --scan` and agree twice: the second Desktop's label is listed and deleted; the other two are not listed;
each display is back on the Desktop it started on.

**Acceptance Scenarios**:

1. **Given** Accessibility is granted, **When** the user runs `dnm cleanup --scan` on a terminal, **Then** `dnm`
   first describes what it will do (the connected displays it will visit, about how long it takes, that the Desktops
   slide and the pointer moves, and not to type meanwhile) and asks `Scan every Desktop now? [y/N]`.
2. **Given** the user answers `y`, **Then** `dnm` visits every Desktop of every connected display in turn, printing
   `Scanning <display>…` as it reaches each display, returns
   each display to the Desktop it started on and the pointer to where it was, and then lists the labels of connected
   displays that no Desktop shows (display, text, size, and when it was last seen), the total, and asks
   `Delete these N labeled images (X MB)? [y/N]`.
3. **Given** the user agrees, **Then** those images and their records are deleted, and standard output says what was
   freed.
4. **Given** the user declines either question, **Then** nothing is deleted; if the scan ran, the labels it saw still
   have their last-seen time updated.
5. **Given** every label of the connected displays shows on some Desktop, **Then** `Every label of the connected
   displays shows on a Desktop; nothing to clean up.` and nothing is asked a second time.
6. **Given** `--yes`, **Then** both questions are answered yes.

---

### User Story 2 - Know what the scan could not judge (Priority: P1)

As a user with a display that is not connected now, I want the scan to leave that display's labels alone and say so,
so that I do not lose labels I cannot see.

**Independent Test**: With labels stored for a display that is not connected, run the scan: those labels are not
listed for deletion, and the output names the display and how many labels it has.

**Acceptance Scenarios**:

1. **Given** labels of a display that is not connected, **Then** the scan does not list them for deletion, and the
   result says `Not checked: <display> is not connected (N labels).`
2. **Given** only such labels exist, **Then** nothing is visited for them, and the scan says so and deletes nothing.

---

### User Story 3 - A scan that stops changes nothing (Priority: P1)

As a user, I want a scan that cannot finish, or that I interrupt, to delete nothing and to tell me where my Desktops
are.

**Independent Test**: With the fake switcher, make a step fail on the second display: nothing is deleted, the first
display is back where it started, and the message says which display could not be scanned and why.

**Acceptance Scenarios**:

1. **Given** Accessibility is not granted, **When** the user runs `dnm cleanup --scan`, **Then** it stops with the
   explanation used for `--desktop` before printing anything else, and exits 1.
2. **Given** the "Move left a space" and "Move right a space" shortcuts are off, **Then** it stops with the
   explanation used for `--desktop` (nothing moved), deletes nothing, and exits 1.
3. **Given** the Desktop changes while the scan is moving (the person or another app switched), **Then** it stops,
   deletes nothing, says that it no longer knows where that display is and did not switch back, and exits 1.
4. **Given** a failure on a later display, **Then** the displays already scanned are back where they started,
   nothing is deleted, and the message names the display that failed.
5. **Given** the user presses Ctrl-C during the walk, **Then** `dnm` steps the display it is on back to the Desktop
   it started on and the pointer back, says which displays were scanned and that nothing was deleted, and exits 130.
6. **Given** a second Ctrl-C while it is stepping back, **Then** it stops at once and says that the display may be on
   another Desktop; nothing is deleted.

---

### User Story 4 - Scripts and JSON (Priority: P2)

As a user who scripts `dnm`, I want the scan to behave predictably without a terminal.

**Acceptance Scenarios**:

1. **Given** Accessibility is granted, no terminal and no `--yes`, **Then** `dnm cleanup --scan` describes what it
   would do, does not switch, deletes nothing, says to add `--yes`, and exits 0. (Without Accessibility, the
   permission check comes first, as everywhere: FR-001, exit 1.)
2. **Given** Accessibility is granted, `--json` and no `--yes`, **Then** one JSON document describes the displays the
   scan would visit; nothing is switched or deleted.
3. **Given** `--json --yes`, **Then** the scan runs, deletes, and prints one JSON document with the candidates, the
   displays not checked, and whether anything was deleted.

---

### User Story 5 - Clear options (Priority: P2)

As a user, I want options that do not apply to the scan to be refused, not ignored.

**Acceptance Scenarios**:

1. **Given** `--scan --days 7`, **Then** exit 2: `--scan looks at every Desktop, so --days does not apply.`
2. **Given** display words or `--desktop` with `cleanup`, **Then** exit 2 with the parser's usage error, as today
   (see FR-010).

### Edge Cases

- **A display where no step moves**: public interfaces cannot tell a display with one Desktop from switching
  shortcuts that are off. Treating it as one Desktop when the shortcuts are off would read only the current Desktop
  and offer labels in use for deletion, so the scan treats it as one Desktop only when a step was confirmed on some
  display in the same run (the shortcuts are on); otherwise it stops with the `--desktop` "nothing moved"
  explanation and deletes nothing (FR-017). A Mac with one display and one Desktop therefore cannot be scanned; the
  message says why, and the age-based `cleanup` still works.
- **Full-screen app Spaces** sit among the Desktops; the scan steps through them like Desktops. Their wallpaper
  rarely matters: only the set of labeled images seen counts (spec 009 research R7).
- **"Displays have separate Spaces" off**: all displays share one set of Desktops. The scan MUST still visit every
  Desktop once and report correctly; how is settled in planning and checked live.
- **A Desktop whose wallpaper has not caught up** when it is read: a missed read would report a label in use as
  unseen. The scan MUST read only after the display's wallpaper is stable (planning: the same wait `set` uses), and
  this is the main thing tested live.
- **Two Desktops showing one image** (a new Desktop copies the left-most one, KI-1, or a reused image): the label is
  seen and is not a candidate.
- **A label whose image file is missing**: it cannot show anywhere; it is listed (size 0) and its record is removed.
- **A label not in the store showing on a Desktop** (an image from another tool or a deleted store): ignored.
- **A label of a connected display that is retired** (removed, replaced or undone through `dnm`) and shows on no
  Desktop: a candidate, like any other.
- **Many Desktops**: macOS allows at most 16 per display; the description estimates the time from about two steps
  per Desktop and one second per step.
- **Quiet mode** (spec 011): the description, the questions and the per-display progress lines are not warnings or
  notes; they are printed in quiet mode.
- **Two commands at once**: the store lock serializes them; the walk happens before the deletion takes the lock, and
  the deletion re-checks that each candidate is still not showing on a current Desktop.

## Requirements

### Functional Requirements

- **FR-001**: `dnm cleanup --scan [--yes] [--json]` MUST check the Accessibility permission first, without prompting
  and with no output before the check, and stop with the explanation `--desktop` uses when it is missing (exit 1).
- **FR-002**: On a terminal, it MUST describe the walk (the connected displays, an estimated duration, that the
  Desktops slide and the pointer moves, not to type) and ask before switching; without a terminal and without
  `--yes`, and with `--json` without `--yes`, it MUST describe and exit 0 without switching. These describe-only
  runs come after the permission check of FR-001, like every scan.
- **FR-003**: It MUST visit every Desktop of every connected display, using only what `--desktop` uses (the two
  switching shortcuts and the public notice that the Desktop changed), reading each Desktop's wallpaper only once it
  is stable, and MUST return each display to the Desktop it started on and the pointer to where it was.
- **FR-004**: The candidates MUST be exactly the labels of connected displays whose image was shown by no Desktop
  during the walk; labels of displays that are not connected MUST NOT be candidates and MUST be named with their
  count.
- **FR-005**: Before deleting, it MUST list each candidate (display, text, size, last seen) and the total, and ask
  again (or require `--yes`); the age-based plain warning of spec 009 does not apply, since every Desktop was seen.
- **FR-006**: Every label seen during the walk MUST have its last-seen time updated, whether or not anything is
  deleted.
- **FR-007**: Deleting MUST remove the images and records in one locked change, re-checking first that none is
  showing on a display's current Desktop, and MUST reset the cleanup nudge (spec 009 FR-004).
- **FR-008**: Any failure during the walk (permission, shortcuts off, an unexpected Desktop change, a step not
  confirmed) MUST delete nothing, MUST return the displays already scanned to where they started when their position
  is known, and MUST say which display failed and whether it was returned.
- **FR-009**: `--days` with `--scan` MUST be refused (exit 2) with `--scan looks at every Desktop, so --days does not
  apply.`
- **FR-010**: `dnm cleanup --scan` MUST always scan every connected display and MUST NOT take display words or
  `--display` (the parser's usage error, exit 2, as for `cleanup` today). Scanning only some displays may be added
  later without changing this behavior (maintainer, 2026-11-09).
- **FR-011**: `--json` with `--yes` MUST print one JSON document with the candidates, the displays not checked, the
  displays scanned and whether anything was deleted.
- **FR-012**: Shell completion (spec 007) MUST offer `--scan`; `--help` for `cleanup` MUST describe it, the
  permission it needs and what the person will see.
- **FR-013**: The README MUST describe the scan and when to prefer it over the age-based cleanup; the cleanup nudge
  (spec 009) MAY mention `--scan`.
- **FR-014**: Spec 009 MUST point to this spec for stage 2 (its FR-011, User Story 4, SC-006 and tasks T020-T026 are
  replaced by this spec).
- **FR-015**: A Ctrl-C during the walk MUST NOT end the process at once: `dnm` MUST step the display it is on back to
  the Desktop it started on and restore the pointer, report the displays already scanned, delete nothing, and exit
  130. A second Ctrl-C MUST stop at once, saying the display may be on another Desktop. `--desktop` is unchanged.
  Found live 2026-11-10 (known issue KI-4): a Ctrl-C from the keyboard reaches `dnm` only while the terminal window
  running it is in front; once the walk shows a Desktop without that window, macOS brings another window forward. The help,
  README and the walk's description say so; a way to stop from any app is on the backlog (maintainer, 2026-11-10).
- **FR-016**: As the walk reaches each display, `dnm` MUST print one progress line to standard error,
  `Scanning <display>…`, only when standard error is a terminal and never with `--json`. It is a progress message
  (spec 011's kinds: neither a warning nor a note), so quiet mode MUST NOT hide it.
- **FR-017**: When no step moves on a display, the scan MUST treat it as having one Desktop only if a step was
  confirmed on some display in the same run (decided after every display has been walked, so the order of displays
  does not matter); otherwise it MUST stop with the `--desktop` "nothing moved" explanation, delete nothing and exit
  1. With "Displays have separate Spaces" off, the single walk is the run.

### Key Entities

- **Scan result**: per connected display, the labeled images seen on its Desktops; the labels of connected displays
  not seen (the candidates); the displays not connected and how many labels each has.
- **Label record** (existing, spec 009): gains no field; its last-seen time is updated by the scan.

## Success Criteria

### Measurable Outcomes

- **SC-001**: On the maintainer's Mac, in each display configuration they have (one display; two displays), after
  deleting one labeled Desktop the scan reports exactly that label, checked by hand once per configuration.
- **SC-002**: In every automated test, a label shown on any Desktop of a connected display is never a candidate, and
  a label of a display that is not connected is never deleted.
- **SC-003**: In every automated failure case (permission, shortcuts off, an unexpected change, a failed step on a
  later display, an interrupt), nothing is deleted and every display whose position is known is back where it started.
- **SC-004**: A scan of 3 Desktops on each of 2 displays completes in under 20 seconds on the maintainer's Mac.
- **SC-005**: Every deletion is preceded by both questions answered yes, or by `--yes`.
- **SC-006**: `just test` and `just periphery` pass.

## Assumptions

- Stepping and confirmation work as for `--desktop` today (about a second per step on the slowest display measured;
  `docs/research/timings.md`).
- Rendering, reuse and the age-based `cleanup` are unchanged; the scan adds a mode to the same command.
- The menu-bar app (M2) will record last-seen on every Desktop switch; the scan stays useful for a one-off exact
  check.
- No new stored data: the manifest stays format 3.
