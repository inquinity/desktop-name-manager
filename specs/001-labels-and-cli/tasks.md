---

description: "Task list for spec 001: desktop labels and the dnm command-line tool"
---

# Tasks: Desktop Labels and the `dnm` Command-Line Tool

**Input**: Design documents from `/specs/001-labels-and-cli/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/cli.md](contracts/cli.md), [quickstart.md](quickstart.md)

**Tests**: Included. The constitution (principle VII) requires tests, and the plan defines them: Swift Testing with a fake wallpaper system, local-only snapshot tests, and hand-run live checks.

**Organization**: Grouped by user story in priority order (US1, US2, US5 are P1; US3, US4 are P2). The MVP is US1 plus US2, so that no live run changes a wallpaper without a way back.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story from spec.md (US1 to US5)
- Paths are relative to the repository root and follow the layout in plan.md

## Rules that apply to every task

- Live tasks change the real wallpaper: back up `Index.plist` first, set `DNM_STORE_DIR` to a temporary directory, restore afterwards, and run only while the user is idle (CLAUDE.md, quickstart.md).
- Never commit personal paths, user names, display or Space UUIDs, or personal images. `wallpaper-samples/` stays untracked.
- Use only public APIs. No networking framework, no private framework loading.
- Write shell scripts with the `shell-script-expert` skill, without more refactoring than the task needs.
- Review tasks (marked "Review") are required by the constitution: independent review before merge. Record each in `specs/001-labels-and-cli/review-notes.md`.

---

## Phase 1: Setup

**Purpose**: Package, layout and test scaffolding.

- [x] T001 Create `Package.swift` with `swift-tools-version: 6.2` (or later), `platforms: [.macOS(.v26)]`, library target `DesktopNameCore`, executable target `dnm`, test targets `DesktopNameCoreTests`, `SnapshotTests` and `dnmTests`, and `swift-argument-parser` pinned to an exact version (only the `dnm` target depends on it); the dependency is added with T018 instead, because resolving it needs a network fetch that needs the maintainer's approval, and the core and its tests do not need it
- [x] T002 Create the directory skeleton from plan.md: `Sources/DesktopNameCore/{Model,System,Displays,Render,Store,Operations}/`, `Sources/dnm/`, `Tests/{DesktopNameCoreTests,SnapshotTests,dnmTests,live}/`, each with a placeholder file so `swift build` succeeds
- [x] T003 [P] Add `.build/` and `.swiftpm/` to `.gitignore` if not already covered, checking `.gitignore` and `.git/info/exclude` first
- [x] T004 [P] Create synthetic image generators (solid, gradient, noise, bright and dark, a multi-frame image) in `Tests/DesktopNameCoreTests/Support/SyntheticImages.swift` so committed tests never use personal images
- [x] T005 [P] Create `specs/001-labels-and-cli/review-notes.md` with the review modes to be used before merge and before release (code review, security review, automated gates) and a section per review; the modes are confirmed with the maintainer before the first review

**Checkpoint**: `swift build` and `swift test` run (with no real tests yet), locally and in CI.

---

## Phase 2: Foundational (blocks all user stories)

**Purpose**: Models, system abstraction, store, cleanup and the CLI shell that every story uses.

- [ ] T006 [P] Create the CI workflow `.github/workflows/ci.yml` and `.github/dependabot.yml`: on push and pull request, build and test on a macOS runner with `swift build` and `swift test`; read-only `contents` permission, no secrets, no signing or notarization; any third-party action pinned by commit SHA (or call `swift` directly instead); Dependabot for the Swift package and GitHub Actions ecosystems; first check which macOS and Xcode versions the runner offers against the macOS 26 minimum; snapshot tests report skipped there; independent security review of the workflow before it is merged (it is shared infrastructure) and a separate approval before it is pushed
- [x] T007 [P] Add Periphery (unused-code detection) as a quality gate: create `.periphery.yml` (SwiftPM project, retain the public API of `DesktopNameCore` because the later app uses it, retain `Codable` properties, exclude the test targets from the report) and `scripts/periphery.sh` (use the `shell-script-expert` skill) that builds and runs `periphery scan` and exits non-zero on any finding; run it at every story review and in CI once T006 lands; the tool is installed with Homebrew, and the install needs the maintainer's approval first
- [x] T008 [P] Create `Sources/DesktopNameCore/Model/Label.swift`: `Label`, `Look` (`plain`, `halo`, `frosted`), `TextColor` (`light`, `dark`, explicit), `Position` (`bottom-left` default, `bottom-right`, `top-left`, `top-right`, `bottom`, `top`), `Size` (`small`, `medium` default, `large`), and `automatic` flags; validation rule quoted from data-model.md: "One line, 1 to 30 characters after trimming; each emoji counts as one; no line breaks."
- [x] T009 [P] Create `Sources/DesktopNameCore/Model/Stamp.swift`: `Stamp` (`id` as a UUID, `fileName` = `<id>.dnm.<ext>`, `label`, `original`, `displayUUID`, `geometry`, `createdAt`, `state` = `active` or `retired(at, reason)` with reason `replaced`/`removed`/`undone`, `supersededBy`), `Original` (`path`, `bookmark`, `scaling`, `clipping`, `fillColor` as an archived `NSColor`), `StateRef` (`stamp(id)` or `original(...)`), and `ChangeRecord` (`displayUUID`, `kind` = `set`/`replace`/`remove`, `at`, `produced`, `before`), all `Codable`
- [x] T010 [P] Create `Sources/DesktopNameCore/Model/DnmError.swift`: error cases for invalid input, unsupported wallpaper, access denied, original missing, nothing to undo, undo expired, wallpaper changed, newer manifest, store not writable, and a mapping to exit codes per contracts/cli.md (`1` failure, `2` invalid input, `3` unsupported wallpaper)
- [x] T011 Create `Sources/DesktopNameCore/System/WallpaperSystem.swift`: the `WallpaperSystem` protocol (list displays, read a display's current wallpaper URL and placement, set a wallpaper for a display) and the `Display` value (`name`, `uuid`, `isMain`, `pixelSize`, `insets`)
- [x] T012 [P] Create `Sources/DesktopNameCore/Store/Clock.swift`: a `Clock` protocol with a system implementation, so cleanup and undo can be tested with advanced time
- [x] T013 Create the fakes in `Tests/DesktopNameCoreTests/Support/FakeWallpaperSystem.swift` (in-memory displays, current files, recorded set calls) and `Tests/DesktopNameCoreTests/Support/FakeClock.swift` (depends on T011, T012)
- [x] T014 Create `Sources/DesktopNameCore/System/SystemWallpaperSystem.swift`: the real implementation over `NSWorkspace.desktopImageURL(for:)`, `desktopImageOptions(for:)`, `setDesktopImageURL(_:for:options:)`, `NSScreen.localizedName`, `CGMainDisplayID()` and the CoreGraphics display UUID (depends on T011)
- [x] T015 Create `Sources/DesktopNameCore/Store/Store.swift` and `Sources/DesktopNameCore/Store/StoreLock.swift`: the store directory `~/Library/Application Support/<store name>/` where the store name is a constant in the core, `com.altmansoftwaredesign.desktop-name-manager`, with `.dev` appended in debug builds (`#if DEBUG`) and not read from any bundle; `DNM_STORE_DIR` override; versioned `manifest.json` (`schemaVersion` starting at 1, written atomically); `manifest.lock` held during every read-modify-write; a manifest with a newer `schemaVersion` is read-only with an error; a store that cannot be written fails before any wallpaper change (depends on T009, T010)
- [x] T016 Create `Sources/DesktopNameCore/Store/Cleanup.swift`: at the start of a command, under the lock, delete stamp files whose entry was retired more than the cool-down (30 minutes) ago, and files with no manifest entry that are older than the cool-down and whose name matches `<uuid>.dnm.<ext>` exactly; never delete an active stamp, the manifest, the lock file, a subfolder or any other file; do nothing in a folder that has no manifest of ours; no background process (depends on T012, T015)
- [x] T017 Create `Sources/DesktopNameCore/Displays/DisplayResolver.swift`: resolve `--display` as `main`, then a case-insensitive exact name, then a unique case-insensitive partial name; no match or several matches throw invalid input listing the candidates; numbers and position keywords are not accepted (FR-023) (depends on T011)
- [x] T018 Create the CLI shell: `Sources/dnm/Dnm.swift` (root command, `--version`), `Sources/dnm/Output.swift` (results to standard output, messages to standard error), `Sources/dnm/DisplayOption.swift` (shared `--display` option), and exit-code mapping from `DnmError` (depends on T001, T010)
- [x] T019 [P] Test label validation in `Tests/DesktopNameCoreTests/LabelValidationTests.swift`: empty, whitespace only, 30 characters accepted, 31 rejected, a line break rejected, emoji counted as one character each
- [x] T020 [P] Test display resolution in `Tests/DesktopNameCoreTests/DisplayResolverTests.swift`: `main`, exact name, unique partial, case-insensitivity, ambiguous and unknown values listing candidates, numbers and `left`/`right`/`here` rejected
- [x] T021 [P] Test the store in `Tests/DesktopNameCoreTests/StoreTests.swift`: atomic write, round trip, the store name with and without the debug suffix, `DNM_STORE_DIR` override, the lock prevents concurrent read-modify-write, a newer `schemaVersion` is read-only, an unwritable store throws before anything else changes
- [x] T022 [P] Test cleanup in `Tests/DesktopNameCoreTests/CleanupTests.swift` with the fake clock: nothing deleted before 30 minutes, retired stamps deleted after, active stamps never deleted, unreferenced `<uuid>.dnm.<ext>` files deleted only after the cool-down, other files (including `.jpg` files, the manifest, the lock and subfolders) never deleted, nothing deleted in a folder with no manifest, 100 relabelings leave only active and recent stamps (SC-006, FR-026)
- [x] T023 [P] Add a hygiene scan test in `Tests/DesktopNameCoreTests/HygieneScanTests.swift` that lists tracked files with `git ls-files` and fails on personal paths (a home-directory path of a real user), UUID-shaped display or Space identifiers, and keychain profile names; build the patterns so the test file does not match itself (FR-021)

**Checkpoint**: Foundation ready. Models, store, cleanup, display resolution and the CLI shell work and are tested without touching the real wallpaper.

---

## Phase 3: User Story 1 - Label the current Desktop (Priority: P1) 🎯 MVP (with US2)

**Goal**: One command puts a legible label on the current Desktop of a display, within a second, leaving everything else unchanged, and refusing wallpapers it cannot handle.

**Independent Test**: Run `dnm set "Email"` on Desktop 2 and visit Desktops 1 to 3: only Desktop 2 shows a readable label (quickstart scenarios 1 to 3). Run this live only together with US2, so there is a way back.

### Tests for User Story 1

> Write these first and confirm they fail before the implementation.

- [x] T024 [P] [US1] Test the set operation against the fake system, using only `DesktopNameCore` and not the CLI (so reuse by the app is proven, FR-020), in `Tests/DesktopNameCoreTests/SetLabelTests.swift`: only the target display's wallpaper is set; the original is recorded on the first label only; a replacement keeps the same `Original` and does not inherit options from the label it replaces (FR-009); every set uses a new random `<uuid>.dnm.<ext>` file name
- [x] T025 [P] [US1] Test the crash-safety and failure order in `Tests/DesktopNameCoreTests/SetLabelOrderTests.swift`: the stamp file is written, then the manifest saved, then the wallpaper set; a failure after the file write leaves only a stray file; a failure after the manifest save leaves an active entry that was never applied; an unwritable or full store leaves the wallpaper unchanged
- [x] T026 [P] [US1] Test automatic style on synthetic bright and dark backdrops in `Tests/DesktopNameCoreTests/StylePickerTests.swift`: the finished image's text has a contrast ratio of at least 3:1 against at least 95% of the pixels directly behind it, and the chosen look and text color are reported
- [x] T027 [P] [US1] Test unsupported-wallpaper detection in `Tests/DesktopNameCoreTests/WallpaperKindTests.swift` with synthetic files: no URL reported, a `.madesktop` file, a video, a folder, and a multi-frame image are all unsupported; a plain image is supported; `set` on each unsupported kind changes nothing and maps to exit code `3`
- [x] T028 [P] [US1] Test replacement from the recorded original in `Tests/DesktopNameCoreTests/ReplaceLabelTests.swift`: the new image is rendered from the `Original`, never from the previous stamp, so labels do not stack; replacement still works when the old stamp file has been deleted; `show`-level information flags the missing file (`stampMissing`)
- [x] T029 [P] [US1] Test a wallpaper changed by hand in `Tests/DesktopNameCoreTests/HandChangedWallpaperTests.swift`: after labeling, the current file is no longer our stamp; a new `set` records the new file as the original, and `remove` reports no label instead of restoring an outdated original

### Implementation for User Story 1

- [x] T030 [P] [US1] Create `Sources/DesktopNameCore/System/WallpaperKind.swift`: classify the current wallpaper as supported or unsupported by file (no file reported, catalog `.madesktop`, video, folder, or more than one frame or dynamic metadata), with the reason for the message (FR-014)
- [x] T031 [P] [US1] Port backdrop composition from `prototype/dnm-prototype.swift` (`Geometry`, `Placement`, `composeBackdrop`) to `Sources/DesktopNameCore/Render/Backdrop.swift`
- [x] T032 [P] [US1] Port the sampler and style picker (`Sampler`, `RegionStats`, `chooseTreatment`) to `Sources/DesktopNameCore/Render/Sampler.swift` and `Sources/DesktopNameCore/Render/StylePicker.swift`, keeping plain, halo and frosted only (no "pill") and a fixed corner (no automatic position)
- [x] T033 [P] [US1] Port layout and drawing to `Sources/DesktopNameCore/Render/Painter.swift` (SF Pro Semibold, single line, bottom-left default) and image writing to `Sources/DesktopNameCore/Render/ImageWriter.swift` (high-quality JPEG; the file extension comes from the format written)
- [x] T034 [US1] Create `Sources/DesktopNameCore/Render/LabelRenderer.swift` combining backdrop, sampling, style choice and painting behind one function that returns the image and the chosen treatment (depends on T031, T032, T033)
- [x] T035 [US1] Create `Sources/DesktopNameCore/Operations/SetLabel.swift`: refuse unsupported wallpaper before writing anything (T030); take the base image from the manifest's recorded `Original` when the current file is one of our stamps (even if that stamp file is missing), otherwise from the current wallpaper, recording a new `Original` (path, bookmark, scaling, clipping, archived fill color); render; write `<uuid>.dnm.<ext>`; save the manifest; set the wallpaper with scale-to-fill and the original fill color; retire any replaced stamp; update the display's `ChangeRecord` (depends on T014, T015, T030, T034)
- [x] T036 [US1] Add `Sources/dnm/Commands/SetCommand.swift`: `dnm set <label>` with `--display`, running cleanup first and printing `Labeled "<label>" on <display> (<look>, <color> text, <position>).` (depends on T018, T035)
- [x] T037 [US1] Review: independent code review of Phases 1 to 3, recorded in `specs/001-labels-and-cli/review-notes.md`; resolve findings before continuing

**Checkpoint**: Labels can be set and replaced from the command line, and unsupported wallpapers are refused. Do not run it live on your real wallpaper until US2 is done.

---

## Phase 4: User Story 2 - Remove a label and get the original back exactly; undo (Priority: P1)

**Goal**: Removing a label restores the original image, placement and fill color exactly, and a one-level undo reverses the last change within the cool-down.

**Independent Test**: Record a Desktop's wallpaper settings, label it, remove the label, compare (quickstart scenarios 5 and 6).

### Tests for User Story 2

- [x] T038 [P] [US2] Test remove in `Tests/DesktopNameCoreTests/RemoveLabelTests.swift`: the original file, scaling, clipping and fill color are restored exactly; a Desktop with no label changes nothing and exits `0`; the stamp is retired (reason `removed`) but not deleted
- [x] T039 [P] [US2] Test a missing original in `Tests/DesktopNameCoreTests/RemoveMissingOriginalTests.swift`: a moved original resolves through the bookmark; a deleted original reports why, changes nothing and fails with exit code `1`
- [x] T040 [P] [US2] Test undo in `Tests/DesktopNameCoreTests/UndoLabelTests.swift` with the fake clock: undo after remove brings the label back; undo after a replacement brings the previous label back; undo after the first set restores the original; a second undo reports nothing to undo; undo after the 30-minute cool-down, after the current wallpaper changed, or with the needed file gone changes nothing and says why (FR-022)

### Implementation for User Story 2

- [x] T041 [US2] Create `Sources/DesktopNameCore/Operations/RemoveLabel.swift`: resolve the bookmark (falling back to the path), set the original image with its exact placement and fill color, retire the stamp, record the `ChangeRecord` (depends on T035)
- [x] T042 [US2] Create `Sources/DesktopNameCore/Operations/UndoLabel.swift`: require the display's `ChangeRecord` to be within the cool-down and the current wallpaper to equal `produced`, re-apply `before` (an earlier stamp or the original), reactivate or retire stamps accordingly, then clear the record so undo is one level only (depends on T041)
- [x] T043 [P] [US2] Add `Sources/dnm/Commands/RemoveCommand.swift` and `Sources/dnm/Commands/UndoCommand.swift` per contracts/cli.md, including the messages `No label on <display>.` and `Restored label "<label>" on <display> (<change> <n> minutes ago).` (depends on T018, T041, T042)
- [x] T044 [US2] Review and MVP check: independent code review of Phase 4 recorded in `review-notes.md`, then run quickstart scenarios 1 to 3, 5 and 6 live on macOS 26 and 27 with the backup and restore steps

**Checkpoint (MVP)**: Labels can be set, removed and undone with an exact restore.

---

## Phase 5: User Story 5 - Work safely and privately (Priority: P1)

**Goal**: No permissions requested, no network, no telemetry, originals never modified, and a clear non-destructive failure when the wallpaper is unreadable.

**Independent Test**: Run every command with the network off and no privacy permissions; compare original file checksums before and after (quickstart scenarios 12 to 15).

### Tests for User Story 5

- [x] T045 [P] [US5] Test access denial in `Tests/DesktopNameCoreTests/AccessDeniedTests.swift`: an unreadable wallpaper file (permissions removed) surfaces the system's error text, changes nothing and maps to exit code `1`
- [x] T046 [P] [US5] Add a source-scan test in `Tests/DesktopNameCoreTests/PrivacyScanTests.swift` that fails if `Sources/` mentions `URLSession`, `Network`, `CFNetwork`, sockets, `dlopen` or SkyLight (research R10)
- [x] T047 [P] [US5] Add a linked-libraries test in `Tests/dnmTests/LinkedLibrariesTests.swift` that inspects the built `dnm` binary and fails on any networking or private framework
- [x] T048 [P] [US5] Test that original wallpaper files are byte-identical after set, replace, remove and undo, in `Tests/DesktopNameCoreTests/OriginalsUntouchedTests.swift` (SC-004)

### Implementation for User Story 5

- [x] T049 [US5] Map read and write permission errors to `DnmError` access-denied carrying the system's error text, never prompting and never retrying with a workaround, in `Sources/DesktopNameCore/Operations/SetLabel.swift` and `Sources/DesktopNameCore/Operations/RemoveLabel.swift` (FR-015)
- [x] T050 [P] [US5] Write the live check script `Tests/live/live-safety.sh` (use the `shell-script-expert` skill): backs up `Index.plist`, sets `DNM_STORE_DIR`, runs scenarios 12 to 15 from quickstart.md including a network-off run, and restores everything on exit
- [x] T051 [US5] Review: independent code review and a first security pass of Phase 5 recorded in `review-notes.md`

**Checkpoint**: The tool never asks for permissions, and its privacy rules are enforced by tests.

---

## Phase 6: User Story 3 - Control the look of a label (Priority: P2)

**Goal**: The user can choose position, size, text color and style; emoji render cleanly; over-limit labels are rejected.

**Independent Test**: Set a label containing an emoji with an explicit position, size, style and color and see each choice in the result (quickstart scenarios 7 and 8).

### Tests for User Story 3

- [x] T052 [P] [US3] Test option handling in `Tests/DesktopNameCoreTests/LabelOptionsTests.swift`: explicit values override the automatic choice and are recorded as not automatic; omitted options use their defaults (bottom-left, medium, automatic style and color); invalid values are rejected with a clear message and no change
- [x] T053 [P] [US3] Test the CLI contract for `set` options in `Tests/dnmTests/SetOptionsContractTests.swift`: accepted values per contracts/cli.md, over-30-character and line-break labels exit `2`, `--color #RRGGBB` parsing
- [x] T054 [P] [US3] Test drawing in `Tests/DesktopNameCoreTests/PainterTests.swift` on synthetic images: an emoji label draws without clipping, a 30-character label at `large` on the smallest display stays fully on screen, a label at the limit is accepted
- [x] T055 [P] [US3] Add the local legibility and quality sweep in `Tests/SnapshotTests/LegibilitySweepTests.swift` over `wallpaper-samples/`, reporting skipped when the folder is absent, failing if any rendering misses the 3:1 on 95% rule (SC-002), and printing the difference measurement against the composed backdrop for the JPEG quality check (research R7); images stay untracked

### Implementation for User Story 3

- [x] T056 [US3] Add `--position`, `--size`, `--style` and `--color` to `Sources/dnm/Commands/SetCommand.swift` with the values from contracts/cli.md, and pass them as explicit overrides to `Sources/DesktopNameCore/Operations/SetLabel.swift`
- [x] T057 [US3] Make `Sources/DesktopNameCore/Render/LabelRenderer.swift` and `Sources/DesktopNameCore/Render/Painter.swift` honor explicit look, color, position and size, clamp the layout so the label never leaves the screen, and draw emoji through font fallback
- [x] T058 [US3] Review: independent code review of Phase 6 recorded in `review-notes.md`

**Checkpoint**: Labels can be styled by the user and the automatic choices are only defaults.

---

## Phase 7: User Story 4 - See what is labeled (Priority: P2)

**Goal**: Users can list labeled and current Desktops, show one label's details, and list displays, in text or JSON, with the scope note always present.

**Independent Test**: Label two Desktops, run `dnm list` and `dnm show` (quickstart scenarios 9 to 11).

### Tests for User Story 4

- [x] T059 [P] [US4] Test list in `Tests/DesktopNameCoreTests/ListDesktopsTests.swift`: labeled Desktops plus the current Desktop per display, current ones marked, a labeled Desktop on a disconnected display marked `connected: false`, a deleted stamp file marked `stampMissing: true`, and no UUIDs or file paths in the output
- [x] T060 [P] [US4] Test the JSON contract in `Tests/dnmTests/JsonContractTests.swift`: the shapes in contracts/cli.md for `list`, `show` and `displays`, exactly one JSON document on standard output, diagnostics on standard error, and the scope sentence present as `scope` and as the last line of human output even when nothing is omitted (FR-011)
- [x] T061 [P] [US4] Test that `desktop-name` and `dnm` behave identically in `Tests/dnmTests/AliasTests.swift` by running the same binary under both names

### Implementation for User Story 4

- [x] T062 [P] [US4] Create `Sources/DesktopNameCore/Operations/ListDesktops.swift` returning labeled Desktops and each connected display's current Desktop, with the missing-stamp flag (depends on T014, T015)
- [x] T063 [P] [US4] Create `Sources/DesktopNameCore/Operations/ShowLabel.swift` returning a label's text, look, color, position, size, automatic flags, `createdAt`, whether an original is recorded, and whether the stamp file is missing
- [x] T064 [US4] Add `Sources/dnm/Commands/ListCommand.swift`, `Sources/dnm/Commands/ShowCommand.swift` and `Sources/dnm/Commands/DisplaysCommand.swift` with human and `--json` output per contracts/cli.md, ending human `list` output with `Only labeled and current Desktops are shown.` (depends on T018, T062, T063, T017)
- [x] T065 [US4] Review: independent code review of Phase 7 recorded in `review-notes.md`

**Checkpoint**: All five stories work independently.

---

## Phase 8: Polish and cross-cutting

**Purpose**: Documentation, live checks, performance and the release review gate.

- [x] T066 [P] Update `README.md` with one end-to-end example a first-time user can follow in under a minute (SC-005), the exit codes (also shown in `dnm --help`), and a note on the "Show on all Spaces" setting
- [x] T067 [P] Update `CLAUDE.md` with the build and test commands (`swift build`, `swift test`) and the `DNM_STORE_DIR` rule for live tests
- [x] T068 [P] Write `Tests/live/live-label.sh` covering quickstart scenarios 1 to 3, 5 to 11 and 16 to 19 (scenario 4 is manual because it needs a log out) with the `Index.plist` backup, a private store directory and restore on exit, using the `shell-script-expert` skill
- [x] T069 Check the timing budget: `time .build/release/dnm set "Timing"` is under 1 s on a 5K display (SC-001, FR-019); record the result in `review-notes.md`
- [ ] T070 Run the full quickstart on macOS 26 and on macOS 27 and record the results, including solid colors (scenario 17), image quality (scenario 18) and persistence (scenario 4, by hand); this is the evidence for the minimum-version decision in research R3
- [x] T071 [P] Add `scripts/codeql-local.sh` (use the `shell-script-expert` skill) that creates a CodeQL database from `swift build` and runs the Swift security queries, taking the CodeQL CLI from the Homebrew install and the query repository checkout from the `CODEQL_REPO` environment variable (no path hard-coded), checking that the checkout is at a pinned release tag, writing results to a `.codeql/` folder that is added to `.gitignore`, and printing a short findings summary; document the install steps in `review-notes.md` and record the CodeQL and query-repo versions with each run. The script must never download anything itself
- [ ] T072 Pre-release code review and security review of everything, using the modes agreed in `review-notes.md` (including a CodeQL run from T071) (permissions, private interfaces, network, file access including cleanup, the `swift-argument-parser` dependency, and the build); resolve findings or have them explicitly accepted before any release

---

## Phase 9: Open issue KI-1 (superseded 2026-10-05; see Phase 10)

**Purpose**: Fix the issue recorded in [known-issues.md](known-issues.md). Needs the maintainer's go-ahead before the first task starts.

- [x] T073 [US1] Add an optional, read-only reader of the wallpaper store in one isolated file, `Sources/DesktopNameCore/System/WallpaperStoreReader.swift`: report which Desktops' entries, display defaults and the new-Desktop template reference a given stamp file; any failure to read or parse returns "unknown" and never blocks labeling; update the privacy scan so this one file may read the store but nothing may write it
- [x] T074 [P] [US1] Test the reader in `Tests/DesktopNameCoreTests/WallpaperStoreReaderTests.swift` with small synthetic store files (a stamp in one Desktop's entries only; in a display default; in the new-Desktop template; in several Desktops; unreadable or malformed file), built in the test and never copied from a real machine
- [x] T075 [US1] In `Sources/DesktopNameCore/Operations/SetLabel.swift`: before the first label on a Desktop, re-apply the wallpaper it already shows (after the store is written), so macOS's wide first set carries the original image (design change: undoing afterwards cannot repair a display default); after the stamp is set, read the store and, if the stamp also became a default or reached other Desktops, return a warning naming the display and the setting; an unreadable store gives no warning
- [x] T076 [P] [US1] Test it in `Tests/DesktopNameCoreTests/NewDesktopDefaultTests.swift` with a fake system that models the quirk: the first label leaves the display default as the original; a replacement does not re-apply; the re-applied image and placement equal the Desktop's own; a label that still becomes the default produces the warning; an unreadable store neither warns nor blocks
- [x] T077 [US1] Make `Sources/DesktopNameCore/Store/Cleanup.swift` keep any stamp the wallpaper store still references (retired stamps included), with a test in `Tests/DesktopNameCoreTests/CleanupTests.swift`; amend FR-018 in spec.md accordingly
- [x] T078 (superseded by Phase 10, not done) Re-check on a real display with "Show on all Spaces" ON and then OFF (live, with the `Index.plist` backup): the first label is refused and undone when it would spread, labeling works once the setting is off, new Desktops do not inherit a label, and the quickstart, README and `live-label.sh` prompt name the setting per display

---

## Phase 10: Amendment 2026-10-05 (shared labeled images, `--desktop`, public interfaces only)

**Purpose**: Implement the spec amendment (User Story 6, FR-008, FR-009, FR-018, FR-027 to FR-029) and remove private interfaces from the product. Research: R13 to R15 and `docs/research/desktop-association.md`.

- [x] T079 Remove the private wallpaper-store reader from the product: delete `Sources/DesktopNameCore/System/WallpaperStoreReader.swift`, the inspector in `DesktopLabeler`, the spread warning in `SetLabel.swift`, the store check in `Cleanup.swift`, their tests and the local real-store check, and the KI-1 "re-apply first" step; make the privacy scan forbid any mention of `com.apple.wallpaper` in `Sources/`
- [x] T080 [US2] Shared labeled images in `Sources/DesktopNameCore/Operations/`: any of our stamp files shown on the targeted Desktop is its label whatever its state; `set`, `remove` and `undo` change only that Desktop; a replacement gives the Desktop a new stamp and leaves the old one for other Desktops
- [x] T081 [P] [US2] Test it in `Tests/DesktopNameCoreTests/SharedStampTests.swift`: two Desktops (modelled as two displays in the fake) show one stamp; removing on one leaves the other recognized; `show` and `remove` work on the other; undo still works
- [x] T082 Cleanup in `Sources/DesktopNameCore/Store/Cleanup.swift`: never delete a stamp that has a manifest entry (every entry was applied: a failed set is rolled back, so no `applied` flag is needed); delete only stray `<uuid>.dnm.<ext>` files with no entry after 30 minutes; update `CleanupTests.swift` and SC-006
- [x] T083 [P] `dnm prune` in `Sources/DesktopNameCore/Operations/Prune.swift` and `Sources/dnm/Commands/PruneCommand.swift`: list retired applied stamps with sizes, warn, delete only with `--yes`, never one shown on a display's current Desktop; tests in `Tests/DesktopNameCoreTests/PruneTests.swift`
- [ ] T084 [US6] `Sources/DesktopNameCore/Switching/DesktopNavigator.swift`: a `DesktopNavigator` protocol (go to Desktop N on a display, return to the start) and the public implementation from research R14: pointer to the display and back, Control-Left/Right with confirmation by `NSWorkspace.activeSpaceDidChangeNotification`, an accessory application event loop, `AXIsProcessTrusted` without prompting, the shortcut check from the symbolic hot keys preferences, and a stop on any unconfirmed step or outside change
- [ ] T085 [P] [US6] Test the orchestration with a fake navigator in `Tests/DesktopNameCoreTests/DesktopNavigatorTests.swift`: reaching N from any start, a missing Desktop, no permission, shortcuts off, a failed step, always returning to the start, and no switching when N is already showing
- [ ] T086 [US6] Document the full-screen edge case (decided: not handled): a full-screen app Space among the Desktops can shift the `--desktop` count; say so in the README and in `dnm set --help`
- [ ] T087 [US6] Add `--desktop <n>` to `set`, `remove`, `undo` and `show` in `Sources/dnm/` (shared option, exit codes and messages per `contracts/cli.md`), name the Desktop in the confirmation, and add the Desktop 1 note (FR-028)
- [ ] T088 [P] Documentation: the README section on sets of Desktops (the four-command example, the Accessibility opt-in, what you see) and the macOS first-Desktop rule; `known-issues.md` KI-1 resolution status
- [ ] T089 [P] `dnm about` (FR-030): `Sources/DesktopNameCore/Operations/About.swift` and `Sources/dnm/Commands/AboutCommand.swift`, with the permissions statement; contract test in `Tests/dnmTests/`
- [ ] T090 [P] `dnm check` (FR-031): `Sources/DesktopNameCore/Operations/Check.swift` and `Sources/dnm/Commands/CheckCommand.swift`, public interfaces only (`NSScreen.screensHaveSeparateSpaces`, `AXIsProcessTrusted` without prompting, displays, store totals); the shortcut line says it cannot be checked and where to look; human and `--json` output; tests with fakes
- [ ] T091 Review: independent code review and security review of Phase 10 (permission handling, keystroke sending, pointer movement), recorded in `review-notes.md`
- [ ] T092 Live: quickstart scenarios 21 to 23 on macOS 27 and macOS 26 (the kit), including timing for SC-008

---

## Dependencies and execution order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup and blocks every user story.
- **US1 (Phase 3)**: depends on Phase 2.
- **US2 (Phase 4)**: depends on US1's `SetLabel` (T035), since removing and undoing act on stamps it creates. US1 plus US2 is the MVP.
- **US5 (Phase 5)**: depends on US1 and US2 (it edits `SetLabel.swift` and `RemoveLabel.swift`).
- **US3 (Phase 6)**: depends on US1 (it extends `SetCommand.swift`, `LabelRenderer.swift` and `Painter.swift`).
- **US4 (Phase 7)**: depends on Phase 2 and on US1 for labels to list; otherwise independent of US2, US3 and US5.
- **Polish (Phase 8)**: after the stories you want in the release.

### Within each story

- Tests first, and confirm they fail.
- Models, then rendering, then operations, then commands, then the review task.
- Tasks touching the same file run in order: `SetLabel.swift` (T035, T049, T056), `SetCommand.swift` (T036, T056), `LabelRenderer.swift` and `Painter.swift` (T033, T034, T057), `RemoveLabel.swift` (T041, T049).
- T013 depends on T011 and T012; T016 on T012 and T015.

### Parallel opportunities

- Setup: T003, T004, T005 and T006 together.
- Foundational: T008, T009, T010, T012 together; later T019 to T023 together once their targets exist.
- US1: T024 to T029 together; T030 to T033 together.
- US2: T038 to T040 together; T043 can start once T041 and T042 exist.
- US5: T045 to T048 together, and T050 alongside the implementation tasks.
- US3 and US4 can proceed in parallel after US1 (they touch different files).

### Parallel example: User Story 1

```text
# Tests together:
T024 SetLabelTests, T025 SetLabelOrderTests, T026 StylePickerTests,
T027 WallpaperKindTests, T028 ReplaceLabelTests, T029 HandChangedWallpaperTests

# Implementation pieces together:
T030 WallpaperKind.swift, T031 Backdrop.swift, T032 Sampler.swift + StylePicker.swift,
T033 Painter.swift + ImageWriter.swift
```

---

## Implementation strategy

### MVP first (User Stories 1 and 2)

1. Phase 1 (Setup) and Phase 2 (Foundational).
2. Phase 3 (US1), then Phase 4 (US2).
3. **Stop and validate** (T044): run the quickstart scenarios on macOS 26 and 27, backing up and restoring the wallpaper store.

### Incremental delivery

1. Foundation, then US1 and US2: labels can be set, removed and undone safely.
2. US5: the privacy and failure rules are enforced before anyone else runs it.
3. US3 and US4: styling and visibility.
4. Polish, the live runs on 26 and 27, then the pre-release reviews. The release itself is spec 005.

---

## Notes

- 92 tasks. The prototype in `prototype/` is reference only; port its algorithms, do not import it.
- Live tasks (T044, T050, T068, T069, T070) touch the real wallpaper: follow the rules at the top.
- Commit after each task or logical group, with signed Conventional Commits.
