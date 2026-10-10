# Feature Specification: Reuse of Labeled Images and `dnm cleanup` (Feature F4)

**Feature Directory**: `specs/009-stamp-reuse-and-cleanup`

**Created**: 2026-10-10

**Status**: Draft

**Target release**: stage 1 (reuse, `cleanup`, last-seen, nudge) in 0.2.1; stage 2 (`cleanup --scan`) later, see "Stages". `ROADMAP.md` has the rows.

**Input**: User description: "The common workflow is deleting a Desktop in Mission Control, not unlabeling and reusing it. `dnm` is never told, so labels and images pile up unseen. Strategies: reuse identical images; `dnm cleanup [--days N]` (default 30); `dnm cleanup --scan` (check Accessibility first, describe, ask); keep a table of images and dates; a nudge at 50 MB. No command deletes images by itself."

## Decisions made before this specification (maintainer, 2026-10-10)

- **No command deletes labeled images by itself.** An in-use label replaced by the Mac's default wallpaper, with no visible cause, is the worst failure; a store that grows is not.
- **A nudge instead**, at about 50 MB, throttled, on a terminal only.
- **Reuse** of identical labeled images is worthwhile and comes first.
- **No grace period** and **no kept record** of deleted images: wrong deletions are an annoyance, not data loss, and are attributable to the command just run.
- **The age-based cleanup says plainly** that a Desktop not currently on screen might still show one of the images it deletes. The scan is opt-in and exact.
- **`--scan` is an inspection**: `--days` does not apply to it.
- **"Last seen"** (a table of images and dates) is wanted.
- **`prune` is removed;** `cleanup` is the only name (no `clean`); `--days N` is per run with a default of 30; a stored preference is left to the app's Settings.

## Clarifications

### Session 2026-10-10

- **Q: What happens today when a Desktop is deleted?**
  - **A**: Nothing tells `dnm`. The label stays active forever, shows in `dnm list` as a labeled Desktop that does not exist, is counted by `dnm check`, and its image (about 2 to 6 MB, a JPEG at the display's size) stays on disk. `prune` only handled labels removed, replaced or undone through `dnm`.
- **Q: What may `dnm cleanup` delete (without `--scan`)?**
  - **A**: A labeled image and its record, when it is not showing on any display's current Desktop, it is not needed by an undo (the 30-minute window), and either (a) the label was retired (removed, replaced or undone) at least N days ago, or (b) the label has not been seen on a Desktop for at least N days. Case (b) is how labels of deleted Desktops are found without the scan; it can also catch a Desktop that is alive but rarely visited, which is why the command lists every label with its last-seen age and says so before asking.
- **Q: What does "seen" mean, and who records it?**
  - **A**: A label is seen when its image is the wallpaper of some display's current Desktop at the moment something looks. Commands that already write (`set`, `remove`, `undo`, `cleanup`) record the images showing on all displays' current Desktops; a new label is seen at creation; the scan records every Desktop it visits; the menu-bar app will record every Desktop switch (spec 002). Read-only commands (`list`, `show`, `displays`, `check`, `about`) change nothing, so they record nothing. A label never seen counts from its creation date.
- **Q: When is an image reused?**
  - **A**: When `set` is asked for the same thing as an existing label on the same display: same original wallpaper (same file, size and modification time, same placement), same text, same requested options (an option left out is "automatic" and keys as such, since automatic choices follow the original), same display (identity and size), and the same version of the renderer. The existing image is used again instead of rendering a new one: an active one (the label of a Desktop you deleted) or a retired one (revived). The key is recorded on each label; labels from earlier versions have none and are not reused.
- **Q: Does reuse across different displays happen?**
  - **A**: No. `list` shows a label under its display, so the display's identity is part of the key. Deleting a Desktop and labeling its replacement on the same display is the case it serves.
- **Q: Can reuse make `cleanup` delete an image in use?**
  - **A**: It makes a known situation a little more common: two Desktops showing one image, after which `remove` on one retires the label while the other still shows it. That situation exists today (new Desktops copy the left-most one) and is covered by the plain warning and by the scan.
- **Q: What is the nudge?**
  - **A**: After `set`, `remove` or `undo`, on a terminal, when `cleanup` could free at least 50 MB (using the default 30 days), `dnm` prints one line to standard error. At most once every 7 days unless the amount has doubled; reset by a cleanup; never in scripts (standard error not a terminal); never for `show`, `list` or any `--json` output. It names the amount and the labels and says what to run.
- **Q: What does the housekeeping pass cost?**
  - **A**: Estimating what could be freed is one file-size lookup per label and no display calls beyond what the command already makes; a test holds it under 50 ms for 1,000 labels. It deletes nothing.
- **Q: What does `--scan` do?** (stage 2)
  - **A**: It first checks that Accessibility is granted (never prompting) and stops with the usual explanation if not. Then it describes what it will do (which displays, roughly how long, that the screen slides and the pointer moves, not to type) and asks. Then it visits every Desktop of every connected display, as `--desktop` does, reading which labeled image each shows; it returns each display to where it started. Labels of connected displays whose image shows on no Desktop are the result; labels of displays that are not connected are left alone and named. It lists them with their sizes and asks again before deleting. `--yes` answers both questions.
- **Q: What if `cleanup` is run without a terminal and without `--yes`?**
  - **A**: It describes what it would delete and exits 0 without deleting, saying to add `--yes`.
- **Q: What does the old `prune` do now?**
  - **A**: It is gone. Typing it gets an error that names `cleanup`, so a script that uses it fails loudly with the way forward.
- **Q: The automatic per-command tidying is called "Cleanup" in specs 001 and 005. Does that clash?**
  - **A**: Yes. In documents and code it is renamed "housekeeping" (stray files that were never applied, undo records past the window). It still deletes no applied image.

---

## User Scenarios & Testing

### User Story 1 - Clear out old labels (Priority: P1)

As a user who deletes Desktops, I want one command that finds the labeled images I no longer need, tells me what it found, and removes them when I agree.

**Independent Test**: With a store holding a label retired 40 days ago, a label not seen for 40 days and a label seen today, run `dnm cleanup`: the first two are listed with their ages and sizes and a plain warning, and are removed when confirmed; the third is untouched.

**Acceptance Scenarios**:
1. **Given** labels as above, **When** the user runs `dnm cleanup` on a terminal, **Then** it lists the two old labels with display, text, why ("removed 40 days ago", "not seen for 40 days"), size and the total, says that a Desktop not currently on screen might still show one of these images, and asks `Delete these 2 labeled images (3.8 MB)? [y/N]`.
2. **Given** the user answers `y` (or passes `--yes`), **Then** the images and records are deleted, standard output says what was freed, and `dnm check` no longer counts them.
3. **Given** `--days 7`, **Then** a label retired 10 days ago and one not seen for 10 days are also listed; `--days 0` lists every label no current Desktop shows.
4. **Given** a label changed or removed within the last 30 minutes (inside the undo window), **Then** it is never listed, whatever `--days` says.
5. **Given** the label's image is the wallpaper of a display's current Desktop, **Then** it is never listed.
6. **Given** no terminal and no `--yes`, **Then** the same description is printed, nothing is deleted, and the exit code is 0.
7. **Given** nothing qualifies, **Then** `Nothing to clean up (no labeled image is older than 30 days).`
8. **Given** `--json`, **Then** one JSON document lists the candidates and whether anything was deleted, and nothing is asked.

---

### User Story 2 - Reuse identical images (Priority: P1)

As a user who deletes and recreates Desktops, I want labeling a new Desktop the way an old one was labeled to reuse its image, so the store stops growing.

**Independent Test**: Label a Desktop "Mail" (halo, bottom-left), simulate it being deleted, label another Desktop of the same display "Mail" with the same options: the store still holds one image, and the second `set` is faster.

**Acceptance Scenarios**:
1. **Given** an active or retired label with the same key, **When** `set` is asked for the same thing, **Then** no new image is written, the existing label is (re)activated, the display shows that image, and the confirmation line is the usual one.
2. **Given** a different text, option, original wallpaper (or the same file changed), display, display size, or renderer version, **Then** a new image is made.
3. **Given** the image file of the matching label is missing, **Then** a new image is made.
4. **Given** the Desktop shows a label and `set` asks for the identical label again, **Then** nothing is retired and the same image is applied.
5. **Given** `undo` after a reused `set`, **Then** it restores exactly what the Desktop showed before.

---

### User Story 3 - Be told when it has piled up (Priority: P2)

As a user who does not think about storage, I want a short note when a lot could be freed.

**Acceptance Scenarios**:
1. **Given** `cleanup` could free 62 MB across 14 labels, **When** the user runs `dnm set` on a terminal, **Then** one line goes to standard error after the usual output: `dnm: note: about 62 MB (14 labels) of old labeled images could be freed: run dnm cleanup.`
2. **Given** it was shown 3 days ago and the amount has not doubled, **Then** it is not shown again; after 7 days, or when the amount doubles, it is.
3. **Given** under 50 MB, a script (standard error not a terminal), `show`, `list` or `--json`, **Then** it is never shown.
4. **Given** `dnm cleanup` ran, **Then** the nudge is reset.

---

### User Story 4 - Find labels of deleted Desktops exactly (Priority: P2, stage 2)

As a user who wants to be sure, I want `dnm cleanup --scan` to look at every Desktop and tell me which labels no Desktop shows.

**Acceptance Scenarios**:
1. **Given** Accessibility is not granted, **When** the user runs `dnm cleanup --scan`, **Then** it stops with the explanation used for `--desktop` and describes nothing else first.
2. **Given** it is granted, **Then** `dnm` describes what it will do, asks, and on `y` visits every Desktop of every connected display, returns each display to where it started, and prints the labels that no Desktop shows (and the displays it could not look at because they are not connected).
3. **Given** the user agrees to delete them, **Then** images and records are deleted; labels seen during the scan have their last-seen date updated.
4. **Given** `--scan --days 7`, **Then** exit 2: `--scan` looks at every Desktop, so `--days` does not apply.

---

## Edge Cases

- **A Desktop that still uses an image the command deletes** (not on screen, created as a copy): it shows macOS's default wallpaper until the user picks another or labels it again. Accepted and stated in the description.
- **Displays not connected**: their labels qualify by age as any other, but `--scan` leaves them alone and names them (public interfaces cannot see them; KI-2).
- **Unreadable, damaged or newer store**: an error, nothing deleted; `check` and the nudge say nothing rather than guess.
- **Standard error closed or redirected**: no nudge.
- **A missing image file** with a record: listed (size 0), and its record is removed.
- **`--days` not a whole number, or negative**: exit 2.
- **A very large store**: the housekeeping estimate looks at every label; the cost is the file-size lookups and is tested.
- **Interrupting `--scan`** (Ctrl-C): the display may be left on a Desktop other than where it started, as with `--desktop`; nothing is deleted before the second question.
- **`--yes` with `--json`**: allowed; deletes, then prints the document.
- **Two commands at once**: the store lock serializes them, as everywhere.

---

## Requirements

### Functional Requirements

- **FR-001**: `dnm cleanup [--days N] [--yes] [--json]` MUST list, describe and (on agreement) delete the candidates of the clarification above, replacing `dnm prune`, which MUST be removed; typing `prune` MUST give an error that names `cleanup`.
- **FR-002**: `--days` MUST default to 30, accept 0 or more, and apply to retired labels (age since retired) and to labels not seen (age since last seen, or since creation if never seen). A label inside the undo window, or showing on any display's current Desktop, MUST NOT be a candidate.
- **FR-003**: Before deleting, the command MUST describe each candidate (display, text, why, size), the total, and plainly say that a Desktop not currently on screen might still show one of these images; it MUST then ask on a terminal, or require `--yes`, and otherwise delete nothing and exit 0.
- **FR-004**: Deleting MUST remove the image file and the label's record, and the nudge state, and MUST be one locked change.
- **FR-005**: Each label MUST record when it was last seen; `set`, `remove`, `undo` and `cleanup` MUST record the images showing on all displays' current Desktops; read-only commands MUST NOT write.
- **FR-006**: `set` MUST reuse an existing image of the same key (FR-007) when its file exists, reactivating a retired label, instead of rendering; otherwise it MUST render as today. The key MUST be recorded on each new label.
- **FR-007**: The key MUST cover: the original file (path, size, modification time) and its placement, the label text, the requested options (automatic stays automatic), the display's identity and pixel size, scale and insets, and a version number of the renderer that MUST change whenever rendering output changes.
- **FR-008**: After `set`, `remove` or `undo`, when stderr is a terminal and cleanup (default days) could free at least 50 MB, `dnm` MUST print the nudge, subject to the throttle (at most weekly unless the amount doubled; reset by `cleanup`); it MUST NOT print for any other command or for `--json`.
- **FR-009**: The housekeeping pass MUST NOT delete any applied labeled image, MUST add no more than 50 ms for 1,000 labels (tested), and MUST NOT call the display system beyond what its command already does.
- **FR-010**: `dnm check`'s stored-labels row MUST report what `cleanup` could free.
- **FR-011** (stage 2): `dnm cleanup --scan` MUST check Accessibility first (never prompting, no output before the check), describe, ask, then visit every Desktop of every connected display with the same stepping as `--desktop`, restoring each display's Desktop; MUST find labels of connected displays whose image shows on no Desktop; MUST leave labels of absent displays alone and name them; MUST ask again before deleting; MUST reject `--days`.
- **FR-012**: The automatic per-command tidying MUST be named "housekeeping" in code and documents, and the documents (specs 001 and 005, README, contracts) MUST be updated for `cleanup`, the removal of `prune`, reuse, last-seen and the nudge.
- **FR-013**: Shell completion (spec 007) MUST offer `cleanup` and its options; the README MUST say what cleanup may break and what the scan adds.

---

## Success Criteria

- **SC-001**: Relabeling a replacement Desktop the way its predecessor was labeled adds no file to the store, and the second `set` makes no render.
- **SC-002**: `cleanup` never lists or deletes a label that shows on a current Desktop or is inside the undo window, in every test.
- **SC-003**: A store with 1,000 labels is estimated in under 50 ms by the housekeeping pass.
- **SC-004**: The nudge appears exactly in the situations of User Story 3 and never otherwise (table-driven test over terminal or not, size, last shown, doubling, command).
- **SC-005**: Every deletion is preceded by a description and an answer (terminal) or `--yes`.
- **SC-006** (stage 2): After a scan on this Mac in each display configuration the maintainer has, the labels it reports match the Desktops actually present, checked by hand once.
- **SC-007**: `just test` and `just periphery` pass.

## Stages

1. **Stage 1 (0.2.1):** reuse, `cleanup` (age and not-seen), last-seen from the commands, the nudge, removal of `prune`, the renaming to housekeeping.
2. **Stage 2 (to be placed on the roadmap):** `cleanup --scan`, and last-seen from the scan; the navigator learns to visit every Desktop; timings and live tests.
3. **Later (the app, spec 002):** last-seen from every Desktop switch; a stored `--days` preference.

## Assumptions

- Stamps keep being JPEG at quality 0.92 at the display's size; the nudge threshold of 50 MB is 8 to 25 labels.
- Rendering the same request from the same original is deterministic enough that "same key" means "same image"; the renderer version guards changes.
- macOS keeps reporting a missing file's path as a Desktop's wallpaper; not needed for this design (no kept record), noted for the stage 2 live test.
