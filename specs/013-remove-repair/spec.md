# Feature Specification: `remove` repairs a misreported Desktop (Feature F6)

**Feature Directory**: `specs/013-remove-repair`

**Created**: 2026-11-09

**Status**: Closed 2026-11-11, not built: KI-3 did not reproduce in the live confirmation (FR-001; research R1)

**Target release**: none (planned for 0.3.0 on 2026-11-11, then closed the same day; maintainer)

**Input**: Roadmap F6 and the backlog entry "`remove` repairs a misreported Desktop" (2026-10-08): known issue KI-3,
a new Desktop that inherited the left-most Desktop's label can report the original wallpaper while still showing the
label. When the reported image is the original of one of our labels, `remove` could set that original again (public
`setDesktopImageURL`, with the recorded placement) so the screen catches up. Confirm the cause first.

## Background

A new Desktop starts with the left-most Desktop's wallpaper. When that is a label, the new Desktop shows the label
too (known issue KI-1, documented, not a hazard). Known issue KI-3: after the label is removed from the left-most
Desktop, the new Desktop still shows the label on screen, but macOS reports its wallpaper as the original image. So
`dnm remove` on the new Desktop says `No label on <display>.` and changes nothing, and the person is stuck with a
label they cannot remove except by the workaround (rearranging and recreating Desktops).

`remove` decides from what macOS reports (`NSWorkspace.desktopImageURL(for:)`), the only public reader. Public
interfaces cannot read what the screen draws. But in the KI-3 state what macOS reports is not arbitrary: it is the
**original** of one of our labels for this display, which `dnm` recorded when it made the label. Setting that original
again, with the placement recorded for it, is what `remove` would have done anyway, and it is harmless when the
Desktop really shows the original (the same image is set again).

The cause is not confirmed (KI-3's leading hypothesis: removing the left-most label also resets the display's
default for new Desktops, and the new Desktop's entry falls back to it). This feature confirms it first, with the
read-only research tools in `prototype/`, and the repair is built only if setting the original again makes the
screen catch up.

## Clarifications

### Session 2026-11-11

Proposed 2026-11-09 while the maintainer was away; the maintainer accepted Q1 and Q3-Q5 as proposed and chose the
short line for Q2.

- Q1: Does plain `dnm remove` repair, or only with a new option? → A: **plain `remove`**, because the person
  cannot tell a misreported Desktop from an unlabeled one, and the repair sets what is already reported (no new
  option to learn; FR-002). Alternative: `remove --repair`, which would keep plain `remove`'s "No label" unchanged.
- Q2: What does `remove` print after a repair? → A: `No label recorded; set the original wallpaper again in case a label still showed.`
  on standard output, exit 0 (FR-004). It is a
  result, not a warning, so quiet mode (spec 011) does not hide it.
- Q3: Is a repair recorded for `undo`? → A: **no**. It sets the image macOS already reports, so there is
  nothing to put back; `undo` after a repair says what it says today for the change before it (FR-006).
- Q4: Does `--desktop N` and several displays (spec 010) apply? → A: **yes**, the repair is part of `remove`
  on each display named, on Desktop N when `--desktop` is given (FR-007).
- Q5: What if the live confirmation (FR-001) shows that setting the original again does not make the screen catch
  up? → A: **stop**: KI-3 stays open with what was learned, this spec is closed as not feasible with public
  interfaces, and nothing ships (FR-001).

## User Scenarios & Testing

### User Story 1 - Remove a label that macOS no longer reports (Priority: P1)

As a person who added a Desktop while the left-most Desktop was labeled, and later removed that label, I want
`dnm remove` on the new Desktop to clear the label I still see, so that I do not have to rearrange and recreate
Desktops.

**Why this priority**: it is the feature; today the only way out is the KI-3 workaround.

**Independent Test**: Follow KI-3's steps on one display (label the left-most Desktop C, add a Desktop, remove C from
the left-most Desktop, switch to the new Desktop): `dnm remove` prints the repair line, exits 0, and the new Desktop
shows the original wallpaper on screen.

**Acceptance Scenarios**:

1. **Given** the current Desktop reports an image that is the recorded original of a label made by `dnm` for this
   display, and no label is recorded for the reported image, **When** the person runs `dnm remove`, **Then** `dnm`
   sets that original again with the placement recorded for it, prints the repair line (Q2), and exits 0.
2. **Given** a Desktop that reports an image that is not the original of any label for this display (a wallpaper
   `dnm` never labeled over), **When** the person runs `dnm remove`, **Then** `No label on <display>.` as today, and
   nothing is set.
3. **Given** the recorded original can no longer be found, **Then** `remove` says so as it does for a missing
   original today (`DnmError.originalMissing`), sets nothing, and exits 1.
4. **Given** a Desktop that shows one of our labels (the normal case), **Then** `remove` behaves exactly as today.

---

### User Story 2 - Nothing else changes (Priority: P1)

As a person who scripts `dnm`, I want the repair to change nothing beyond what it sets.

**Acceptance Scenarios**:

1. **Given** a repair, **Then** the store is unchanged apart from each label's last-seen time where its image is
   seen showing (spec 009), no change is recorded for `undo` (Q3), and no labeled image is created or deleted.
2. **Given** a Desktop with no store yet (nothing ever labeled), **Then** `remove` says `No label on <display>.`, sets
   nothing and does not create the store, as today.
3. **Given** `--json` is not part of `remove`, **Then** nothing changes there.

### Edge Cases

- **Two labels with the same original** (one wallpaper labeled on several Desktops): the reported image matches
  both; the placement of the most recently made label is used. Placements of one original rarely differ; if they
  do, the most recent is what the person last chose.
- **The original is reported but its placement differs from the recorded one**: the recorded placement is used, as
  `remove` does today; it is what the Desktop had before it was labeled (research R2).
- **An unlabeled Desktop that shows the same original as a label** (the common case, since people label their
  normal wallpaper): `remove` there also sets the original again and prints the repair line. Setting the same image
  is harmless; the line says "in case", so it is not a false claim (Q2).
- **Interaction with `cleanup --scan` (spec 012)**: in the KI-3 state the scan reads the original for the new
  Desktop, so the label it still shows on screen is not "seen" and may be offered for deletion. After a repair the
  screen matches what is reported, so the scan is right again. The plan adds a sentence to KI-3 and to the README's
  scan section.
- **Quiet mode**: the repair line is a result and is printed in quiet mode.
- **Several displays** (spec 010): each display named is checked and repaired independently. A repaired display is
  not counted as changed in the part-way message: what macOS reports for it is unchanged, and there is nothing to
  undo.

## Requirements

### Functional Requirements

- **FR-001**: Before any product change, the cause of KI-3 MUST be confirmed live with the read-only research tools
  in `prototype/` (never shipped), and it MUST be shown that setting the reported original again with
  `setDesktopImageURL` makes the screen show the original. If it does not, the feature stops (Q5) and KI-3 is updated
  with what was learned.
- **FR-002**: When `remove` finds no label for the image reported on the Desktop, and that image is the recorded
  original of a label made for this display, `remove` MUST set that original again with its recorded placement and
  fill color, using the same public interface as every other change.
- **FR-003**: The match MUST compare the reported file with the recorded original as `remove` finds originals today
  (bookmark first, then path, resolved; spec 001 FR-008), and MUST consider only labels whose `displayUUID` is this
  display.
- **FR-004**: After a repair `remove` MUST print the repair line on standard output and exit 0; without a match it
  MUST print `No label on <display>.` and exit 0, as today.
- **FR-005**: A repair MUST NOT create, retire or delete a label, and MUST NOT record a change for `undo`; it MAY mark
  as seen the labels whose images show on current Desktops, as `remove` does today.
- **FR-006**: `undo` MUST behave after a repair as it would have before it.
- **FR-007**: The repair MUST apply to `remove` with `--desktop N` and on several displays (spec 010), each display
  independently.
- **FR-008**: The README's KI-3 mention, known issue KI-3 itself, and `remove --help` MUST say that `remove` repairs
  this case; KI-3's status becomes "mitigated" with the version.
- **FR-009**: Public interfaces only (constitution I): no read of `Index.plist` or any private interface in the
  product; the research step may use them in `prototype/` only.

### Key Entities

- **Label record** (existing, spec 001): its `original` (path, bookmark, placement) and `displayUUID` are read; no
  field is added.

## Success Criteria

### Measurable Outcomes

- **SC-001**: On the maintainer's Mac, after KI-3's steps, `dnm remove` on the new Desktop leaves it showing the
  original wallpaper on screen, checked by hand once (and recorded with `dnm --version`).
- **SC-002**: In every automated test, a Desktop whose reported image is not the original of a label of this display
  is never set by `remove`.
- **SC-003**: In every automated test, a repair leaves the manifest identical apart from last-seen times.
- **SC-004**: `just test` and `just periphery` pass.

## Assumptions

- KI-3 is reproducible on macOS 27 with KI-3's steps (it was found on 0.1.0 and has not been retested since).
- `setDesktopImageURL` with the URL macOS already reports still applies it (if macOS skips a set of the same URL,
  research R1 decides between setting a labeled image first or stopping per Q5).
- No new stored data: the manifest stays format 3.
