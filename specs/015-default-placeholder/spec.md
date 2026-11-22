# Feature Specification: Refuse the macOS 27 default-wallpaper placeholder

**Feature Directory**: `specs/015-default-placeholder`

**Created**: 2026-11-20

**Status**: Approved by the maintainer 2026-11-20

**Target release**: 0.3.1 (a fix to 0.3.0; separate from the menu-bar app, spec 014)

**Input**: Live finding of 2026-11-20 (spec 014 quickstart scenario 6). On macOS 27, a Desktop that shows an Apple
dynamic wallpaper (Golden Gate and Macintosh seen; likely all) is reported by the public wallpaper reader as
`/System/Library/CoreServices/DefaultDesktop.heic`. That file is a link to a single still picture with no dynamic
wallpaper metadata, so the check for unsupported wallpapers (FR-014 of spec 001) passes it as an ordinary still, and
`dnm set` (and the app) label that still. The person's dynamic wallpaper is replaced by a labeled still. dnm 0.3.0
has this flaw.

## Background

`dnm` decides whether it can label a Desktop from the wallpaper file macOS reports for it, the only public reader.
FR-014 refuses dynamic, aerial, catalog and shuffling wallpapers by looking at that file: a catalog entry, a folder,
a video, an image with several frames, or an image carrying dynamic wallpaper metadata. Each of these is the real
wallpaper, so looking at the file is enough.

On macOS 27 that is no longer true for Apple's dynamic wallpapers: macOS reports a fixed **stand-in** file instead of
the wallpaper itself. Observed on this Mac (macOS 27.2.1):

- The reported file is `/System/Library/CoreServices/DefaultDesktop.heic`, a link into a hidden system folder of
  default wallpapers. The picture behind it is one still image (3840 by 2160) with no dynamic wallpaper metadata.
- Nothing in the file says which wallpaper the Desktop really shows. The file alone cannot be told apart from a
  plain still.

So the check passes, and labeling sets a labeled copy of the stand-in still as the wallpaper. `dnm remove` restores
the stand-in still, not the dynamic wallpaper (the original the label recorded is the stand-in), so the person must
choose their dynamic wallpaper again in System Settings. That is a breach of the reversibility principle (V) in
practice, even though `dnm` restored exactly what macOS reported.

The fix recognizes the stand-in by **where macOS says it is**, the reported location itself, and refuses it like the
other unsupported kinds. It reads nothing new: the reported file is already opened today to classify it.

## Clarifications

### Session 2026-11-20

- Q1: Does recognizing the stand-in by comparing the reported location with the fixed path
  `/System/Library/CoreServices/DefaultDesktop.heic` stay within principle I (no undocumented system files)? No file
  is read for it: no link is followed, nothing is listed; the product only knows the path. → A: Allowed as a
  **deviation**: borderline, so the plan records it in complexity tracking as a maintainer-approved deviation from
  principle I, to be revisited on each macOS release.
- Q2: What does the refusal say? → A: "Unsupported wallpaper; macOS reports default wallpaper when dynamic or
  unsupported wallpapers are selected." Inside the shared unsupported-wallpaper message (which every unsupported
  kind uses, so it stays as is, FR-005) this becomes the reason "macOS reports the default wallpaper when dynamic or
  unsupported wallpapers are selected". No workaround in the message; it goes in the README.

### Session 2026-11-22

- Q3: Does the refusal apply before macOS 27? → A: No. Only macOS 27 and later recognize the stand-in
  (`WallpaperKind.standInLocations(onMajorVersion:)`): on macOS 26 the same file may be a wallpaper the person
  really chose, so labeling it works as in 0.3.0. The maintainer tests on macOS 26 after the 0.4.0 release, through
  `brew install`. The path comparison is not an undocumented API (it fails by not matching, not by crashing), which
  [CLAUDE.md](../../CLAUDE.md) now records.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A dynamic wallpaper is refused, not replaced (Priority: P1)

A person on macOS 27 has an Apple dynamic wallpaper (for example Golden Gate) on a Desktop and runs `dnm set Email`
(or picks a label in the app). Today their dynamic wallpaper is silently replaced by a labeled still. After this fix
the tool refuses with the unsupported-wallpaper message, changes nothing, and `dnm` exits with code 3.

**Why this priority**: it is the whole fix: the tool must never replace a wallpaper it cannot restore.

**Independent Test**: with the fake wallpaper system reporting the stand-in location, setting a label fails with the
unsupported-wallpaper error (exit code 3), sets no wallpaper, writes no stamp and records nothing.

**Acceptance Scenarios**:

1. **Given** a Desktop for which macOS reports the stand-in location, **When** the person runs `dnm set Email`,
   **Then** `dnm` prints the unsupported-wallpaper message naming the reason, exits with code 3, and the wallpaper,
   the store and the manifest are unchanged.
2. **Given** the same Desktop, **When** the person picks a label in the app, **Then** the app shows the same
   unsupported-wallpaper reason and changes nothing (the app uses the same core check; no app-specific code).

---

### User Story 2 - Every other wallpaper behaves as before (Priority: P1)

A person with an ordinary still (their own photo, or an Apple still such as `Sonoma.heic`), a catalog wallpaper, a
video, a folder, or a multi-frame image sees exactly the 0.3.0 behavior.

**Why this priority**: the fix must be narrow; widening the refusal would break labeling for wallpapers that work.

**Independent Test**: the existing classification tests pass unchanged, and a still that is not at the stand-in
location (including a copy of the stand-in picture placed elsewhere) is still labeled.

**Acceptance Scenarios**:

1. **Given** a plain still image anywhere other than the stand-in location, **When** a label is set, **Then** it is
   labeled as in 0.3.0.
2. **Given** each other unsupported kind, **When** a label is set, **Then** the reason and exit code are as in 0.3.0.

---

### Edge Cases

- **Labels already made over the stand-in (0.3.0)**: a Desktop already labeled from the stand-in shows our stamp, so
  it is reported as our file and is not re-classified. `dnm remove` still restores the stand-in still, as recorded.
  This feature does not repair those labels; the release notes tell people to choose their dynamic wallpaper again
  in System Settings after removing such a label.
- **Replacing a label whose recorded original is the stand-in**: `dnm set` on a Desktop that already shows one of our
  labels does not classify again (it renders from the recorded original). A label made over the stand-in by 0.3.0
  can therefore be relabeled. Accepted: the damage (losing the dynamic wallpaper) already happened when the first
  label was set; refusing now would not restore it.
- **A person who really wants the stand-in still**: they are refused, with the same message. System Settings on
  macOS 27 does not appear to offer it as a choice of its own (confirmed or corrected in the live check); it can be
  reached only by choosing that exact file. Workaround (README): copy the picture to another folder and choose the
  copy in System Settings; the copy is labeled like any still.
- **The stand-in reached by another path** (for example a different spelling of the same location, such as an
  extra `/` or `..`): the location is compared after the usual normalization of the reported path, without
  following links.
- **macOS moves or renames the stand-in in a later release**: the check no longer matches and the 0.3.0 behavior
  returns for those wallpapers. The live check in the quickstart catches this on each new macOS release.
- **Aerial wallpapers**: macOS 27 reports the same stand-in for an aerial (live check 2026-11-20), so aerials are
  refused by this same rule. The reason wording covers both.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When macOS reports the wallpaper of a Desktop as the system's stand-in location
  (`/System/Library/CoreServices/DefaultDesktop.heic` on macOS 27), the system MUST decline to label it, change
  nothing, and say why, as for the other unsupported kinds in FR-014 of spec 001. `dnm` MUST exit with code 3.
- **FR-002**: The reason MUST be "macOS reports the default wallpaper when dynamic or unsupported wallpapers are
  selected", shown inside the existing message, so the full line reads "This wallpaper is not supported: macOS
  reports the default wallpaper when dynamic or unsupported wallpapers are selected. Nothing was changed." (Q2)
- **FR-003**: The stand-in MUST be recognized from the location macOS reports, compared after normalizing the
  path but without following links and without opening, reading or listing anything in system folders beyond
  what the classification already opens (the reported file). The product MUST NOT read the wallpaper store or any
  other undocumented file or preference. Naming this one fixed system location in the product is a
  maintainer-approved deviation from principle I (Q1), recorded in the plan's complexity tracking.
- **FR-004**: The check MUST run before the file's contents are examined, so the outcome does not depend on what
  the stand-in picture holds.
- **FR-005**: Classification of every other wallpaper MUST be unchanged: same outcome, same reason, same exit code.
- **FR-006**: The app MUST get this behavior from the shared core check, with no app-specific detection.
- **FR-007**: The stand-in location MUST be replaceable in tests, so contract tests can exercise the refusal with
  the fake wallpaper system and a temporary file, and never touch the real wallpaper.
- **FR-008**: The README's list of unsupported wallpapers and exit code 3, and the release notes for the next
  release, MUST mention the stand-in case, including the advice for labels already made over it (Edge Cases).

### Key Entities

- **Stand-in location**: the fixed location macOS 27 reports in place of an Apple dynamic wallpaper. One known
  value; replaceable in tests.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On macOS 27, with an Apple dynamic wallpaper on the Desktop, `dnm set` leaves the wallpaper exactly as
  it was in 100% of runs and exits with code 3 (live check).
- **SC-002**: All existing classification and labeling tests pass unchanged.
- **SC-003**: New contract tests cover: the stand-in refused with exit code 3 and no change; the same picture at
  another location still labeled; the reason wording.
- **SC-004**: No new macOS permission, private interface, or read of an undocumented file or preference is added
  (security review and the existing privacy scan).

## Live check (principle VII)

Run on macOS 27 after backing up `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`, with
`DNM_STORE_DIR` set to a throwaway directory, announced as live control:

1. Choose Golden Gate (dynamic) for the current Desktop in System Settings. Run `dnm set Test`: expect the
   unsupported-wallpaper message, exit code 3, and the dynamic wallpaper still showing.
2. Repeat with Macintosh (dynamic) and, if available, an aerial wallpaper; record what macOS reports for each.
3. Choose an Apple still (for example Sonoma) and run `dnm set Test`, then `dnm remove`: labeled and restored as
   in 0.3.0.
4. In System Settings > Wallpaper, look for any choice that is the plain default still (not Golden Gate); if one
   exists, record what macOS reports for it and whether it is refused.
5. Restore with `dnm remove`; restore `Index.plist` only if needed. Quote `dnm --version`.

## Assumptions

- The stand-in location is the same on every Mac running macOS 27 (it is part of the system volume).
- System Settings on macOS 27 does not offer the stand-in still as a choice of its own. Confirmed in the live check
  (2026-11-20): the plain default still offered there is reported as its own file and is labeled normally.
- No other location is reported as a stand-in for dynamic wallpapers. If the live check finds one, it is added to
  this spec before the fix ships.
- Repairing labels already made over the stand-in by 0.3.0 is out of scope (Edge Cases).
