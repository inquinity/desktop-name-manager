---

description: "Task list for spec 001: desktop labels and the dnm command-line tool"
---

# Tasks: Desktop Labels and the `dnm` Command-Line Tool

**Input**: Design documents from `/specs/001-labels-and-cli/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/cli.md](contracts/cli.md), [quickstart.md](quickstart.md)

**Tests**: Included. The constitution (principle VII) requires tests, and the plan defines them: Swift Testing with a fake wallpaper system, local-only snapshot tests, and hand-run live checks.

**Organization**: Grouped by user story, in priority order (US1, US2, US5 are P1; US3, US4 are P2).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story from spec.md (US1 to US5)
- Paths are relative to the repository root and follow the layout in plan.md

## Rules that apply to every task

- Live tasks change the real wallpaper: back up `Index.plist` first, set `DNM_STORE_DIR` to a temporary directory, restore afterwards, and run only while the user is idle (CLAUDE.md, quickstart.md).
- Never commit personal paths, user names, display or Space UUIDs, or personal images. `wallpaper-samples/` stays untracked.
- Use only public APIs. No networking framework, no private framework loading.
- Write shell scripts with the `shell-script-expert` skill, without more refactoring than the task needs.

---

## Phase 1: Setup

**Purpose**: Package, layout and test scaffolding.

- [ ] T001 Create `Package.swift` with `swift-tools-version: 6.2` (or later), `platforms: [.macOS(.v26)]`, library target `DesktopNameCore`, executable target `dnm`, test targets `DesktopNameCoreTests`, `SnapshotTests` and `dnmTests`, and `swift-argument-parser` pinned to an exact version (only the `dnm` target depends on it)
- [ ] T002 Create the directory skeleton from plan.md: `Sources/DesktopNameCore/{Model,System,Displays,Render,Store,Operations}/`, `Sources/dnm/`, `Tests/{DesktopNameCoreTests,SnapshotTests,dnmTests,live}/`, each with a placeholder file so `swift build` succeeds
- [ ] T003 [P] Add `.build/` and `.swiftpm/` to `.gitignore` if not already covered, checking `.gitignore` and `.git/info/exclude` first
- [ ] T004 [P] Create synthetic image generators (solid, gradient, noise, bright and dark, a multi-frame image) in `Tests/DesktopNameCoreTests/Support/SyntheticImages.swift` so committed tests never use personal images

**Checkpoint**: `swift build` and `swift test` run (with no real tests yet).

---

## Phase 2: Foundational (blocks all user stories)

**Purpose**: Models, system abstraction, store, cleanup and the CLI shell that every story uses.

- [ ] T005 [P] Create `Sources/DesktopNameCore/Model/Label.swift`: `Label`, `Look` (`plain`, `halo`, `frosted`), `TextColor` (`light`, `dark`, explicit), `Position` (`bottom-left` default, `bottom-right`, `top-left`, `top-right`, `bottom`, `top`), `Size` (`small`, `medium` default, `large`), and `automatic` flags; validation rule quoted from data-model.md: "One line, 1 to 30 characters after trimming; each emoji counts as one; no line breaks."
- [ ] T006 [P] Create `Sources/DesktopNameCore/Model/Stamp.swift`: `Stamp` (`id`, `label`, `original`, `displayUUID`, `geometry`, `createdAt`, `state` = `active` or `retired(at, reason)` with reason `replaced`/`removed`/`undone`, `supersededBy`), `Original` (`path`, `bookmark`, `scaling`, `clipping`, `fillColor` as an archived `NSColor`), and `ChangeRecord` (`displayUUID`, `kind` = `set`/`replace`/`remove`, `at`, `produced`, `before`), all `Codable`
- [ ] T007 [P] Create `Sources/DesktopNameCore/Model/DnmError.swift`: error cases for invalid input, unsupported wallpaper, access denied, original missing, nothing to undo, undo expired, wallpaper changed, newer manifest, and a mapping to exit codes per contracts/cli.md (`1` failure, `2` invalid input, `3` unsupported wallpaper)
- [ ] T008 Create `Sources/DesktopNameCore/System/WallpaperSystem.swift`: the `WallpaperSystem` protocol (list displays, read a display's current wallpaper URL and placement, set a wallpaper for a display) and the `Display` value (`name`, `uuid`, `isMain`, `pixelSize`, `insets`)
- [ ] T009 [P] Create the fake in `Tests/DesktopNameCoreTests/Support/FakeWallpaperSystem.swift` (in-memory displays, current files, recorded set calls) and a fake `Clock` in `Tests/DesktopNameCoreTests/Support/FakeClock.swift`
- [ ] T010 Create `Sources/DesktopNameCore/System/SystemWallpaperSystem.swift`: the real implementation over `NSWorkspace.desktopImageURL(for:)`, `desktopImageOptions(for:)`, `setDesktopImageURL(_:for:options:)`, `NSScreen.localizedName`, `CGMainDisplayID()` and the CoreGraphics display UUID (depends on T008)
- [ ] T011 [P] Create `Sources/DesktopNameCore/Store/Clock.swift`: a `Clock` protocol with a system implementation, so cleanup and undo can be tested with advanced time
- [ ] T012 Create `Sources/DesktopNameCore/Store/Store.swift` and `Sources/DesktopNameCore/Store/StoreLock.swift`: store directory `~/Library/Application Support/<bundle id>/` with `DNM_STORE_DIR` override, versioned `manifest.json` (`schemaVersion` starting at 1, written atomically), `manifest.lock` held during every read-modify-write, and a manifest with a newer `schemaVersion` treated as read-only with an error (depends on T006, T007)
- [ ] T013 Create `Sources/DesktopNameCore/Store/Cleanup.swift`: at the start of a command, under the lock, delete stamp files whose entry was retired more than the cool-down (60 minutes) ago and files with no manifest entry older than the cool-down; never delete an active stamp; no background process (depends on T011, T012)
- [ ] T014 Create `Sources/DesktopNameCore/Displays/DisplayResolver.swift`: resolve `--display` as `main`, then a case-insensitive exact name, then a unique case-insensitive partial name; no match or several matches throw invalid input listing the candidates; numbers and position keywords are not accepted (FR-023) (depends on T008)
- [ ] T015 Create the CLI shell: `Sources/dnm/Dnm.swift` (root command, `--version`), `Sources/dnm/Output.swift` (results to standard output, messages to standard error), `Sources/dnm/DisplayOption.swift` (shared `--display` option), and exit-code mapping from `DnmError` (depends on T001, T007)
- [ ] T016 [P] Test label validation in `Tests/DesktopNameCoreTests/LabelValidationTests.swift`: empty, whitespace only, 30 characters accepted, 31 rejected, a line break rejected, emoji counted as one character each
- [ ] T017 [P] Test display resolution in `Tests/DesktopNameCoreTests/DisplayResolverTests.swift`: `main`, exact name, unique partial, case-insensitivity, ambiguous and unknown values listing candidates, numbers and `left`/`right`/`here` rejected
- [ ] T018 [P] Test the store in `Tests/DesktopNameCoreTests/StoreTests.swift`: atomic write, round trip, `DNM_STORE_DIR` override, lock prevents concurrent read-modify-write, newer `schemaVersion` is read-only
- [ ] T019 [P] Test cleanup in `Tests/DesktopNameCoreTests/CleanupTests.swift` with the fake clock: nothing deleted before 60 minutes, retired stamps deleted after, active stamps never deleted, unreferenced files deleted only after the cool-down, 100 relabelings leave only active and recent stamps (SC-006)

**Checkpoint**: Foundation ready. Models, store, cleanup, display resolution and the CLI shell work and are tested without touching the real wallpaper.

---

## Phase 3: User Story 1 - Label the current Desktop (Priority: P1) 🎯 MVP

**Goal**: One command puts a legible label on the current Desktop of a display, within a second, leaving everything else unchanged.

**Independent Test**: Run `dnm set "Email"` on Desktop 2 and visit Desktops 1 to 3: only Desktop 2 shows a readable label (quickstart scenarios 1 to 3).

### Tests for User Story 1

> Write these first and confirm they fail before the implementation.

- [ ] T020 [P] [US1] Test the set operation against the fake system in `Tests/DesktopNameCoreTests/SetLabelTests.swift`: only the target display's wallpaper is set; the original is recorded on the first label only; a replacement keeps the same `Original` and does not inherit options from the label it replaces (FR-009); every set uses a new random stamp file name
- [ ] T021 [P] [US1] Test the crash-safety order in `Tests/DesktopNameCoreTests/SetLabelOrderTests.swift`: the stamp file is written, then the manifest saved, then the wallpaper set; a failure after the file write leaves only a stray file, and a failure after the manifest save leaves an active entry that was never applied
- [ ] T022 [P] [US1] Test automatic style on synthetic bright and dark backdrops in `Tests/DesktopNameCoreTests/StylePickerTests.swift`: the chosen look and text color keep contrast above the legibility threshold and are reported

### Implementation for User Story 1

- [ ] T023 [P] [US1] Port backdrop composition from `prototype/dnm-prototype.swift` (`Geometry`, `Placement`, `composeBackdrop`) to `Sources/DesktopNameCore/Render/Backdrop.swift`
- [ ] T024 [P] [US1] Port the sampler and style picker (`Sampler`, `RegionStats`, `chooseTreatment`) to `Sources/DesktopNameCore/Render/Sampler.swift` and `Sources/DesktopNameCore/Render/StylePicker.swift`, keeping plain, halo and frosted only (no "pill") and a fixed corner (no automatic position)
- [ ] T025 [P] [US1] Port layout and drawing to `Sources/DesktopNameCore/Render/Painter.swift` (SF Pro Semibold, single line, bottom-left default) and image writing to `Sources/DesktopNameCore/Render/ImageWriter.swift` (high-quality JPEG)
- [ ] T026 [US1] Create `Sources/DesktopNameCore/Render/LabelRenderer.swift` combining backdrop, sampling, style choice and painting behind one function that returns the image and the chosen treatment (depends on T023, T024, T025)
- [ ] T027 [US1] Create `Sources/DesktopNameCore/Operations/SetLabel.swift`: read the current wallpaper and placement, record the `Original` (path, bookmark, scaling, clipping, archived fill color), render, write `<random id>.jpg`, save the manifest, set the wallpaper with scale-to-fill and the original fill color, retire any replaced stamp, update the display's `ChangeRecord` (depends on T010, T012, T026)
- [ ] T028 [US1] Add `Sources/dnm/Commands/SetCommand.swift`: `dnm set <label>` with `--display`, running cleanup first and printing `Labeled "<label>" on <display> (<look>, <color> text, <position>).` (depends on T015, T027)

**Checkpoint**: Labels can be set and replaced from the command line. This is the MVP.

---

## Phase 4: User Story 2 - Remove a label and get the original back exactly; undo (Priority: P1)

**Goal**: Removing a label restores the original image, placement and fill color exactly, and a one-level undo reverses the last change within the cool-down.

**Independent Test**: Record a Desktop's wallpaper settings, label it, remove the label, compare (quickstart scenarios 5 and 6).

### Tests for User Story 2

- [ ] T029 [P] [US2] Test remove in `Tests/DesktopNameCoreTests/RemoveLabelTests.swift`: the original file, scaling, clipping and fill color are restored exactly; a Desktop with no label changes nothing and exits `0`; the stamp is retired (reason `removed`) but not deleted
- [ ] T030 [P] [US2] Test a missing original in `Tests/DesktopNameCoreTests/RemoveMissingOriginalTests.swift`: a moved original resolves through the bookmark; a deleted original reports why, changes nothing and fails with exit code `1`
- [ ] T031 [P] [US2] Test undo in `Tests/DesktopNameCoreTests/UndoLabelTests.swift` with the fake clock: undo after remove brings the label back; undo after a replacement brings the previous label back; undo after the first set restores the original; a second undo reports nothing to undo; undo after the cool-down, after the current wallpaper changed, or with the needed file gone changes nothing and says why (FR-022)

### Implementation for User Story 2

- [ ] T032 [US2] Create `Sources/DesktopNameCore/Operations/RemoveLabel.swift`: resolve the bookmark (falling back to the path), set the original image with its exact placement and fill color, retire the stamp, record the `ChangeRecord` (depends on T027)
- [ ] T033 [US2] Create `Sources/DesktopNameCore/Operations/UndoLabel.swift`: require the display's `ChangeRecord` to be within the cool-down and the current wallpaper to equal `produced`, re-apply `before` (an earlier stamp or the original), reactivate or retire stamps accordingly, then clear the record so undo is one level only (depends on T032)
- [ ] T034 [P] [US2] Add `Sources/dnm/Commands/RemoveCommand.swift` and `Sources/dnm/Commands/UndoCommand.swift` per contracts/cli.md, including the messages `No label on <display>.` and `Restored label "<label>" on <display> (<change> <n> minutes ago).` (depends on T015, T032, T033)

**Checkpoint**: Labels can be removed and undone with an exact restore.

---

## Phase 5: User Story 5 - Work safely and privately (Priority: P1)

**Goal**: No permissions requested, no network, no telemetry, originals never modified, and a clear non-destructive failure when the wallpaper is unsupported or unreadable.

**Independent Test**: Run every command with the network off and no privacy permissions; compare original file checksums before and after (quickstart scenarios 12 to 15).

### Tests for User Story 5

- [ ] T035 [P] [US5] Test unsupported-wallpaper detection in `Tests/DesktopNameCoreTests/WallpaperKindTests.swift` with synthetic files: no URL reported, a `.madesktop` file, a video, a folder, and a multi-frame image are all unsupported; a plain image is supported; `set` on each unsupported kind changes nothing and maps to exit code `3`
- [ ] T036 [P] [US5] Test access denial in `Tests/DesktopNameCoreTests/AccessDeniedTests.swift`: an unreadable wallpaper file (permissions removed) surfaces the system's error text, changes nothing and maps to exit code `1`
- [ ] T037 [P] [US5] Add a source-scan test in `Tests/DesktopNameCoreTests/PrivacyScanTests.swift` that fails if `Sources/` mentions `URLSession`, `Network`, `CFNetwork`, sockets, `dlopen` or SkyLight (research R10)
- [ ] T038 [P] [US5] Add a linked-libraries test in `Tests/dnmTests/LinkedLibrariesTests.swift` that inspects the built `dnm` binary and fails on any networking or private framework
- [ ] T039 [P] [US5] Test that original wallpaper files are byte-identical after set, replace, remove and undo, in `Tests/DesktopNameCoreTests/OriginalsUntouchedTests.swift` (SC-004)

### Implementation for User Story 5

- [ ] T040 [US5] Create `Sources/DesktopNameCore/System/WallpaperKind.swift`: classify the current wallpaper as supported or unsupported by file (no file reported, catalog `.madesktop`, video, folder, or more than one frame or dynamic metadata), with the reason for the message (FR-014)
- [ ] T041 [US5] Wire the check into `Sources/DesktopNameCore/Operations/SetLabel.swift`, before anything is written, and map unsupported kinds to exit code `3` (depends on T040)
- [ ] T042 [US5] Map read and write permission errors to `DnmError` access-denied carrying the system's error text, never prompting and never retrying with a workaround, in `Sources/DesktopNameCore/Operations/SetLabel.swift` and `Sources/DesktopNameCore/Operations/RemoveLabel.swift` (FR-015)
- [ ] T043 [P] [US5] Write the live check script `Tests/live/live-safety.sh` (use the `shell-script-expert` skill): backs up `Index.plist`, sets `DNM_STORE_DIR`, runs scenarios 12 to 15 from quickstart.md including a network-off run, and restores everything on exit

**Checkpoint**: The tool refuses cleanly, never asks for permissions, and its privacy rules are enforced by tests.

---

## Phase 6: User Story 3 - Control the look of a label (Priority: P2)

**Goal**: The user can choose position, size, text color and style; emoji render cleanly; over-limit labels are rejected.

**Independent Test**: Set a label containing an emoji with an explicit position, size, style and color and see each choice in the result (quickstart scenarios 7 and 8).

### Tests for User Story 3

- [ ] T044 [P] [US3] Test option handling in `Tests/DesktopNameCoreTests/LabelOptionsTests.swift`: explicit values override the automatic choice and are recorded as not automatic; omitted options use their defaults (bottom-left, medium, automatic style and color); invalid values are rejected with a clear message and no change
- [ ] T045 [P] [US3] Test the CLI contract for `set` options in `Tests/dnmTests/SetOptionsContractTests.swift`: accepted values per contracts/cli.md, over-30-character and line-break labels exit `2`, `--color #RRGGBB` parsing
- [ ] T046 [P] [US3] Test drawing in `Tests/DesktopNameCoreTests/PainterTests.swift` on synthetic images: an emoji label draws without clipping, a 30-character label at `large` on the smallest display stays fully on screen, a label at the limit is accepted
- [ ] T047 [P] [US3] Add the local legibility sweep in `Tests/SnapshotTests/LegibilitySweepTests.swift` over `wallpaper-samples/`, reporting skipped when the folder is absent and failing if any rendering falls below the contrast threshold (SC-002); images stay untracked

### Implementation for User Story 3

- [ ] T048 [US3] Add `--position`, `--size`, `--style` and `--color` to `Sources/dnm/Commands/SetCommand.swift` with the values from contracts/cli.md, and pass them as explicit overrides to `Sources/DesktopNameCore/Operations/SetLabel.swift`
- [ ] T049 [US3] Make `Sources/DesktopNameCore/Render/LabelRenderer.swift` and `Sources/DesktopNameCore/Render/Painter.swift` honor explicit look, color, position and size, clamp the layout so the label never leaves the screen, and draw emoji through font fallback

**Checkpoint**: Labels can be styled by the user and the automatic choices are only defaults.

---

## Phase 7: User Story 4 - See what is labeled (Priority: P2)

**Goal**: Users can list labeled and current Desktops, show one label's details, and list displays, in text or JSON, with the scope note always present.

**Independent Test**: Label two Desktops, run `dnm list` and `dnm show` (quickstart scenarios 9 to 11).

### Tests for User Story 4

- [ ] T050 [P] [US4] Test list in `Tests/DesktopNameCoreTests/ListDesktopsTests.swift`: labeled Desktops plus the current Desktop per display, current ones marked, a labeled Desktop on a disconnected display marked `connected: false`, and no UUIDs or file paths in the output
- [ ] T051 [P] [US4] Test the JSON contract in `Tests/dnmTests/JsonContractTests.swift`: the shapes in contracts/cli.md for `list`, `show` and `displays`, exactly one JSON document on standard output, diagnostics on standard error, and the scope sentence present as `scope` and as the last line of human output even when nothing is omitted (FR-011)
- [ ] T052 [P] [US4] Test that `desktop-name` and `dnm` behave identically in `Tests/dnmTests/AliasTests.swift` by running the same binary under both names

### Implementation for User Story 4

- [ ] T053 [P] [US4] Create `Sources/DesktopNameCore/Operations/ListDesktops.swift` returning labeled Desktops and each connected display's current Desktop (depends on T012, T010)
- [ ] T054 [P] [US4] Create `Sources/DesktopNameCore/Operations/ShowLabel.swift` returning a label's text, look, color, position, size, automatic flags, `createdAt` and whether an original is recorded
- [ ] T055 [US4] Add `Sources/dnm/Commands/ListCommand.swift`, `Sources/dnm/Commands/ShowCommand.swift` and `Sources/dnm/Commands/DisplaysCommand.swift` with human and `--json` output per contracts/cli.md, ending human `list` output with `Only labeled and current Desktops are shown.` (depends on T015, T053, T054, T014)

**Checkpoint**: All five stories work independently.

---

## Phase 8: Polish and cross-cutting

**Purpose**: Documentation, live checks, performance and review gates.

- [ ] T056 [P] Update `README.md` with one end-to-end example a first-time user can follow in under a minute (SC-005) and a note on the "Show on all Spaces" setting (research open item)
- [ ] T057 [P] Update `CLAUDE.md` with the build and test commands (`swift build`, `swift test`) and the `DNM_STORE_DIR` rule for live tests
- [ ] T058 [P] Write the remaining live scripts `Tests/live/live-label.sh` (quickstart scenarios 1 to 11 and 16) with the `Index.plist` backup, a private store directory and restore on exit, using the `shell-script-expert` skill
- [ ] T059 Check the timing budget: `time .build/release/dnm set "Timing"` is under 1 s on a 5K display (SC-001, FR-019); record the result in the review notes
- [ ] T060 Run the full quickstart on macOS 26 and on macOS 27 and record the results, which is the evidence for the minimum-version decision in research R3
- [ ] T061 Run a code review of all changes, then a security review (permissions, private interfaces, network, file access, the `swift-argument-parser` dependency and the build), and record both in `specs/001-labels-and-cli/review-notes.md` without personal paths or identifiers; resolve findings or have them explicitly accepted before any release

---

## Dependencies and execution order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup and blocks every user story.
- **US1 (Phase 3)**: depends on Phase 2. It is the MVP.
- **US2 (Phase 4)**: depends on US1's `SetLabel` (T027), since removing and undoing act on stamps it creates.
- **US5 (Phase 5)**: depends on US1 (it changes `SetLabel.swift`) and on US2 for the remove-side access checks.
- **US3 (Phase 6)**: depends on US1 (it extends `SetCommand.swift`, `LabelRenderer.swift` and `Painter.swift`).
- **US4 (Phase 7)**: depends on Phase 2 and on US1 for labels to list; it is otherwise independent of US2, US3 and US5.
- **Polish (Phase 8)**: after the stories you want in the release.

### Within each story

- Tests first, and confirm they fail.
- Models, then rendering, then operations, then commands.
- Tasks touching the same file run in order: `SetLabel.swift` (T027, T041, T042, T048), `SetCommand.swift` (T028, T048), `LabelRenderer.swift` and `Painter.swift` (T026, T025, T049), `RemoveLabel.swift` (T032, T042).

### Parallel opportunities

- Setup: T003 and T004 together.
- Foundational: T005, T006, T007, T011 together; later T016 to T019 together once their targets exist.
- US1: T020 to T022 together; T023, T024, T025 together.
- US2: T029 to T031 together; T034 can start once T032 and T033 exist.
- US5: T035 to T039 together, and T043 alongside the implementation tasks.
- US3 and US4 can proceed in parallel after US1 (US4 touches different files).

### Parallel example: User Story 1

```text
# Tests together:
T020 SetLabelTests, T021 SetLabelOrderTests, T022 StylePickerTests

# Render ports together:
T023 Backdrop.swift, T024 Sampler.swift + StylePicker.swift, T025 Painter.swift + ImageWriter.swift
```

---

## Implementation strategy

### MVP first (User Story 1 only)

1. Phase 1 (Setup) and Phase 2 (Foundational).
2. Phase 3 (US1).
3. **Stop and validate**: run quickstart scenarios 1 to 3 on macOS 26 and 27, backing up and restoring the wallpaper store.

### Incremental delivery

1. Foundation, then US1: labels can be set.
2. US2: labels can be removed and undone with an exact restore, which makes it safe to use daily.
3. US5: refusal and privacy rules are enforced before anyone else runs it.
4. US3 and US4: styling and visibility.
5. Polish, the live runs on 26 and 27, then the code and security reviews. The release itself is spec 005.

---

## Notes

- 61 tasks. The prototype in `prototype/` is reference only; port its algorithms, do not import it.
- Live tasks (T043, T058, T059, T060) touch the real wallpaper: follow the rules at the top.
- Commit after each task or logical group, with signed Conventional Commits.
