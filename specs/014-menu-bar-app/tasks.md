---
description: "Task list for M2: the menu-bar app and label editor"
---

# Tasks: M2 — the menu-bar app and label editor

**Input**: `specs/014-menu-bar-app/` (spec.md, plan.md, research.md, data-model.md, contracts/app-ui.md,
contracts/app-bundle.md, contracts/app-settings.md, contracts/core-additions.md, quickstart.md)

**Tests**: included (constitution VII; research R15; SC-003 and SC-005 ask for them).

**Rules for every task**: work in the worktree `.worktree/014-menu-bar-app` on branch `014-menu-bar-app`; no
automated test or prototype changes a real wallpaper or the real store (the fake wallpaper system and a temporary
store only); synthetic display names (`Built-in Display`, `DP1`) and synthetic images in tests, prototypes and docs;
public interfaces only; no new dependency; build and test with `just` (`build.noindex/`). Live runs follow the
quickstart's backup rules and need live control, asked for and announced first (`say "Requesting lyve control"`, then
`say "Completed using lyve control"`). `dnm`'s sources (`Sources/dnm/`) do not change.

**Gates**: Gate A (T011) and Gate B (T028) are the maintainer's approvals of the prototypes (FR-002). No task after a
gate starts before it is passed.

## Phase 1: Setup

- [X] T001 Create the worktree `.worktree/014-menu-bar-app` on branch `014-menu-bar-app` from `main` (check `.worktree/` is ignored); confirm the baseline there: `just build`, `just test` and `just periphery` pass; quote `dnm --version`
- [X] T002 Start the version: `just bump minor` (0.3.1 → 0.4.0 in `Version.xcconfig`); commit with the first change
- [X] T003 [P] Start `specs/014-menu-bar-app/prototypes/REVIEW.md` with the structure in data-model.md (PrototypeReview: rounds with date, stage, what was shown, decisions, changes; an approval line per stage)

## Phase 2: Prototype stage 1 — web mockups (US1) and Gate A

**Goal**: every FR-001 state as a clickable web mockup, approved before any app code is written.

**Independent test**: open the published mockups' index; every state below is one click away; no image comes from
`wallpaper-samples/` or `working-notes/` (FR-003).

- [X] T004 [US1] Load the `artifact-design` guidance, then create `specs/014-menu-bar-app/prototypes/index.html`: a self-contained page (inline CSS and JS, no external assets) with synthetic wallpapers drawn in CSS or SVG (a light and a dark one, a busy one), light and dark mode, and a list linking every state in T005-T009
- [X] T005 [US1] Mockup the editor in `specs/014-menu-bar-app/prototypes/index.html`, starting from `working-notes/ui-concepts/Main.dc.html` but limited to contracts/app-ui.md: Desktop empty, labeled (field prefilled and selected), typing with a live-looking preview, each invalid case with its sentence from contracts/app-ui.md, unsupported wallpaper (no Apply), working, an error; style chips Automatic (with its choice), Plain, Halo, Frosted only; color Automatic, Light, Dark, Custom; the six positions as a grid; Small, Medium, Large; Remove Label, Cancel, Apply; one variant with position, size and color behind "More options" and one without, for the maintainer to choose
- [X] T006 [P] [US1] Mockup the menu-bar item and menu (contracts/app-ui.md §Menu-bar item, §Menu): the three modes with and without a label, a long label shortened to 24 characters, the menu with and without Remove, Undo and the red "Old labeled images use <size>. Clean Up…" line
- [X] T007 [P] [US1] Mockup the hotkey's floating panel (the editor near the top of the active display, item hidden) and the welcome window (contracts/app-ui.md §Welcome window)
- [X] T008 [P] [US1] Mockup Settings: General (menu-bar mode, hotkey recorder with its "Another app is using this shortcut" line, Open at login), New labels (with the "`dnm` keeps its own defaults" line), Clean Up (with old labels, with none, confirming, and with the red message)
- [X] T009 [P] [US1] Mockup About and Help > Configuration with the content of `dnm about` and `dnm check` (synthetic display names; the Accessibility row's app wording from research R8), and an app icon draft (the icon used in all mockups)
- [X] T010 [US1] Check the mockups: no personal path, name, display or Desktop identifier, no copied image (grep the folder; FR-003); publish `prototypes/index.html` as a private claude.ai artifact and record its link and round 1 in `prototypes/REVIEW.md`
- [X] T011 [US1] **Gate A**: review rounds with the maintainer; apply each round's changes to the mockups and to contracts/app-ui.md (wording, "More options" decision, menu-bar width); record the decisions and the approval with its date in `prototypes/REVIEW.md` (FR-002, SC-007)

**Checkpoint**: the mockups are approved; contracts/app-ui.md matches them.

## Phase 3: Foundational (blocks every later story)

**Goal**: the targets, the bundle script, shared test support and the three core additions, with tests.

- [X] T012 In `Package.swift`, add the library target `DesktopNameApp` (depends on `DesktopNameCore`), the executable target `DesktopNameManager` (depends on `DesktopNameApp`), the executable target `EditorPrototype` at `prototype/editor` (depends on `DesktopNameApp` and `DNMTestSupport`; no product, never in a release), and the test target `DesktopNameAppTests` (depends on `DesktopNameApp`, `DNMTestSupport`); `dnm` keeps its own dependencies and does not link SwiftUI; empty placeholder sources so `just build` passes
- [X] T013 Move the test fakes the app tests and the prototype need into the shared `Tests/DNMTestSupport/` target, unchanged and made `public`: `FakeWallpaperSystem.swift`, `SyntheticImages.swift`, `FakeClock.swift`, `StoreBuilder.swift` from `Tests/DesktopNameCoreTests/Support/` (keep `LabelerHarness`, `Fixtures` and `FakeSwitcher` where they are unless needed); every existing test passes unchanged. Done: `StoreBuilder.swift` stayed too, since it extends `LabelerHarness`; the test files gained `import DNMTestSupport`
- [X] T014 [P] Create `Resources/App/Info.plist` (template with `@VERSION@`, `@BUILD@`, `@BUNDLE_ID@` placeholders and every key in contracts/app-bundle.md: `LSUIElement` true, `LSMinimumSystemVersion` 26.0, no usage-description keys) and `Resources/App/AppIcon.iconset/` from the approved icon (T009, T011)
- [X] T015 Create `scripts/make-app.sh` (with the shell-script-expert skill): from a built configuration (`debug` or `release`) assemble `build.noindex/app/Desktop Name Manager.app` with the layout in contracts/app-bundle.md (`MacOS/DesktopNameManager`, `Helpers/dnm`, `Info.plist` filled from `Version.xcconfig` via `scripts/ver` and `scripts/build-num`, `PkgInfo`, `Resources/AppIcon.icns` via `iconutil`, `Resources/Licenses/`); `--dev` sets the `.dev` bundle ID and ad-hoc signs; `--dry-run` and `--help`; refuses to run if an executable is missing
- [X] T016 In `justfile`, add `app` (`just build` then `scripts/make-app.sh --dev debug`) and `run-app` (opens it, passing `DNM_STORE_DIR` through `open --env` when set); `just build` builds every target with the same build stamp (check both executables report the same version line)
- [X] T017 [P] In `Tests/scripts/` (or a new `Tests/scripts/make-app-test.sh` run by `just test`), check `make-app.sh --dry-run` lists exactly the contracts/app-bundle.md layout and the `.dev` bundle ID with `--dev`
- [X] T018 [P] Create `Sources/DesktopNameCore/Operations/CurrentLabel.swift`: `DesktopLabeler.currentLabel(on:)` per contracts/core-additions.md §2 (reads only, no lock); refactor `showLabel(on:)` in `Sources/DesktopNameCore/Operations/ShowLabel.swift` to use the same lookup with no change to its results
- [X] T019 [P] Create `Sources/DesktopNameCore/Operations/Preview.swift`: `PreviewRequest`, `PreviewSource`, `DesktopLabeler.previewSource(on:maxPixelWidth:)` (the original `setLabel` would stamp, composed with `Backdrop` for the display, scaled to `maxPixelWidth`; throws as `setLabel` does for an unsupported wallpaper, a missing original, or a stamp from another store) and `LabelPreview.render(_:source:)` (runs `LabelRenderer` with the display geometry scaled by the same factor; safe off the main thread) per contracts/core-additions.md §1
- [X] T020 [P] Create `Sources/DesktopNameCore/Store/StoreWatcher.swift` per contracts/core-additions.md §3: a `DispatchSource` on the store folder, coalesced (about 100 ms), calling back on the main queue when `manifest.json` is replaced or removed; `stop()`
- [X] T021 [P] Create `Tests/DesktopNameCoreTests/CurrentLabelTests.swift`: labeled, unlabeled, a stamp from another store (nil), a newer manifest (throws); `showLabel` results unchanged (existing tests pass)
- [X] T022 [P] Create `Tests/DesktopNameCoreTests/PreviewTests.swift`: the preview's chosen look and text color equal `setLabel`'s for the same request over the synthetic backdrops (light, dark, busy); a labeled Desktop's source is its original, not the stamp; an unsupported wallpaper throws `unsupportedWallpaper`; rendering runs on a background task
- [X] T023 [P] Create `Tests/DesktopNameCoreTests/StoreWatcherTests.swift`: one transaction gives one call; a burst gives one call; after `stop()` none
- [X] T024 [P] Create `Tests/SnapshotTests/PreviewSnapshotTests.swift` (constitution VII; local only, skipped without `wallpaper-samples/`, as `LegibilitySweepTests` is): for every sample, position and size on a 5K display, render the preview with `LabelPreview` at the editor's preview width and the full image with `setLabel`'s pipeline; the automatic look and text color agree, and the label's box in the preview matches the full render scaled down (within one preview pixel); run with `just test --filter PreviewSnapshot`
- [X] T025 Update `.periphery.yml` for the new targets (retain SwiftUI `body` and `@objc` entry points by configuration, exclude `prototype/**` from reports); `just test` and `just periphery` pass (a native build first)

**Checkpoint**: `just app` produces a bundle that launches to an empty menu-bar item; the core additions are tested;
`dnm`'s tests pass unchanged.

## Phase 4: Prototype stage 2 — the runnable editor (US1) and Gate B

**Goal**: the real editor views with the real preview, on sample wallpapers, approved before the app is built.

**Independent test**: `swift run --scratch-path build.noindex EditorPrototype`: type and change every option over each
sample; the real wallpaper and store never change; the printed preview times meet SC-002.

- [X] T026 [US1] Create `Sources/DesktopNameApp/Model/EditorDraft.swift` per data-model.md (EditorDraft): fields `display`, `text`, `look`/`color`/`position`/`size`, `backdrop`, `preview`, `state`, `message`; states `loading`, `ready`, `invalid`, `applying`, `removing`, `unsupported`, `closed` with the transitions drawn in data-model.md ("`applying` and `removing` cannot be entered twice"); text checked as typed with `LabelText` ("one line, 1 to 30 characters"); options start from the current label, else from settings; previews coalesced, newest request wins, rendered off the main thread with `LabelPreview`; and `Sources/DesktopNameApp/Editor/EditorView.swift`, `StyleChips.swift`, `PreviewView.swift` per contracts/app-ui.md §Editor and the approved mockups
- [X] T027 [US1] Create `prototype/editor/main.swift` (`EditorPrototype`): a window hosting `EditorView` over `FakeWallpaperSystem` and a temporary store; images from `wallpaper-samples/` when it exists, else `SyntheticImages`; Apply writes only to the fake and the temporary store; prints the time of each preview render (spike S2) and compares the automatic look at preview and full size for each sample and position (research R6), printing any disagreement; no code path to `SystemWallpaperSystem` or `Store.defaultDirectory()` (FR-003)
- [X] T028 [US1] **Gate B**: run spike S2 and record the times and any automatic-style disagreement in research.md R6 (if they differ, implement R6's full-size sample fix in `Preview.swift` and re-run); review rounds with the maintainer on the running prototype; record the decisions and the approval with its date in `prototypes/REVIEW.md` (FR-002, SC-002, SC-007)

**Checkpoint**: the editor is approved as it runs.

## Phase 5: User Story 2 — Label the Desktop on screen from the menu bar (P1) 🎯 MVP

**Goal**: click the menu-bar item, type, Return (or open the editor, preview, Return): the Desktop is labeled, exactly
as `dnm set` would.

**Independent test**: with a still-image wallpaper (live) or the fake (unit), the main window's field → "Q4 budget" →
Return: the Desktop shows it with the defaults, `dnm list` reports it; Style and Preview… → Frosted → Apply: the style
changes; Remove restores; Undo works both ways within 60 s.

- [X] T029 [P] [US2] Create `Tests/DesktopNameAppTests/LabelingTests.swift`: Apply, Remove and Undo through the app model produce the same manifest and the same stamp file bytes as `DesktopLabeler.setLabel`/`removeLabel`/`undoLastChange` with the same text and options (SC-003); a `dnm`-made change is undoable from the app model within 60 s and not after; every invalid case shows the sentence in contracts/app-ui.md and keeps Apply off; an unsupported wallpaper gives `unsupported` with no Apply; a failure leaves the fake wallpaper and the manifest as they were
- [X] T030 [P] [US2] Create `Sources/DesktopNameApp/Model/MessageWording.swift`: the app's wording for core sentences that name `dnm` actions ("Update the tool." → "Update the app.", "then run again" → "then try again", and any other found by grepping `DnmError` and the operations for `dnm`, `--` and "run"); `Tests/DesktopNameAppTests/MessageWordingTests.swift` covers each substitution and leaves other sentences unchanged
- [X] T031 [US2] Create `Sources/DesktopNameApp/Model/LabelingController.swift`: Apply, Remove, Undo on the main actor as one core call each (research R7), after showing the working state for one run-loop turn; reads the store as it is when pressed; never holds the store lock while a window is open
- [X] T032 [US2] Create `Sources/DesktopNameManager/main.swift` and `AppDelegate.swift`: an accessory app (`LSUIElement`), the single-instance check (a second launch activates the first and exits; the first opens Settings on reopen, FR-017), and wiring of the parts below
- [X] T033 [US2] Create `Sources/DesktopNameManager/StatusItemController.swift` (the `NSStatusItem`, icon only in this phase; a click opens the main window) and `Sources/DesktopNameApp/Main/MainView.swift` with `Sources/DesktopNameApp/Model/QuickLabel.swift` per contracts/app-ui.md §Main window and data-model.md (QuickLabel): the Desktop line; the field (the current label, selected, or empty; checked as typed with `LabelText`, "one line, 1 to 30 characters"; Label and Return off while invalid or unchanged; a new label takes the defaults, built-in until T047 and then AppSettings', a relabel keeps the label's options; applies through `LabelingController`, FR-013a); Style and Preview…; Remove Label (labeled only); Undo (`checkUndo` passes); Labels in use (count) and Space used with Clean Up… (wired to panes in T049); Settings…, Configuration…, About Desktop Name Manager, Quit; never other Desktops' labels; `Tests/DesktopNameAppTests/QuickLabelTests.swift`: a new label gets the defaults, a relabel keeps the options, invalid text keeps Label off with the editor's sentence, and the result equals `setLabel` with the same text and options
- [X] T034 [US2] Create `Sources/DesktopNameManager/PopoverPresenter.swift`: shows `MainView` in an `NSPopover` anchored to the status item for the display it was opened on, made key so its field takes typing; "Style and Preview…" replaces the content with `EditorView` for the same display, and Cancel returns to the main window; Escape and a click outside close it with no change; Return applies; Remove from the editor and the main window; load the editor's picture (`previewSource`) off the main thread, keeping the editor in `loading` until it arrives (independent review, 2026-11-19: up to 167 ms on a 5K display)
- [X] T035 [US2] Create `Sources/DesktopNameApp/Model/WelcomeState.swift` and `Sources/DesktopNameApp/Windows/WelcomeView.swift` (contracts/app-ui.md §Welcome window): shown when `welcomeShown` is false and the launch is not a login start; one "OK" button and no settings or actions; `welcomeShown` set true on OK or close (FR-017a); its window shows the Dock icon while open (activation policy)
- [X] T036 [P] [US2] Create `Tests/DesktopNameAppTests/WelcomeTests.swift`: first launch shows it; OK and close each set `welcomeShown`; a login start does not show it; a second launch does not show it
- [ ] T037 [US2] Live check (quickstart scenarios 3, 4, 5, 6 and 16) with the backup rules and approved live control: also time Apply in the app and `dnm set` with the same text and options on the same 5K wallpaper, three runs each (FR-026: the app is no slower, and under 1 s), and time a first labeling by someone new to the app, or the maintainer's first use of the approved build, from clicking the menu-bar item to the label showing (SC-001: under 15 s, no help read); record the results and the versions in this file

**Checkpoint**: the app labels, removes and undoes on the Desktop on screen; MVP.

## Phase 6: User Story 3 — Reach the app from the menu bar (P2)

**Goal**: the item shows the icon and the fixed text (never the label) in the chosen mode; the main window names the
label of its display's Desktop on screen when it opens, and the hotkey targets the active display.

**Independent test**: label two Desktops on each of two displays; switch 20 times and open the main window each time;
it names the right label (SC-004).

- [ ] T038 [US3] **Spike S1** (research R5), live with approved live control: a temporary diagnostic build logs, on two displays, which screen `NSScreen.main` reports while the app is in the background, and what `desktopImageURL(for:)` reports when the main window is opened right after a Desktop switch; also, with a full-screen app in front, what `desktopImageURL(for:)` reports for that display; and, if the maintainer can switch "Displays have separate Spaces" off (it needs a log out), that the main display is used then; record the results, the active-display rule and any re-read in research.md R5; a rule other than FR-012's (the display with the frontmost window) needs the maintainer's approval and a change to FR-012
- [X] T039 [P] [US3] Create `Sources/DesktopNameApp/Model/MenuBarState.swift` per data-model.md (MenuBarState): `activeDisplay`, `currentLabel` (via `currentLabel(on:)`), `itemTitle` ("mode `iconAndText`: the app's fixed text; else none. Never the label"), `undoAvailable`, `cleanUpWarning`; and `Tests/DesktopNameAppTests/MenuBarStateTests.swift`: each mode with a label and without, the title never containing the label; a stamp from another store gives no label; separate Spaces off: the main display; a full-screen app in front: the label of the stamp the display reports, else none (spec Edge Cases, research R5); accessibility label "Desktop Name Manager"
- [ ] T040 [US3] (Built 2026-11-20 with FR-012's rule and no re-read; confirm or change after spike S1, T038.) Create `Sources/DesktopNameManager/ActiveDisplay.swift` with the rule chosen in T038 (the frontmost window's screen, else the screen under the pointer) for the hotkey; in `PopoverPresenter.swift`, compute `MenuBarState` for the clicked item's screen each time the main window opens (with the re-read chosen in T038), and refresh it while open on a `StoreWatcher` call
- [X] T041 [US3] Show the icon and the fixed text in the status item (Icon and text mode), the icon only in Icon mode, and remove the item in Hidden mode (`isVisible`); the main window's first line shows the label whole
- [ ] T042 [US3] Live check (quickstart scenario 7, SC-004) on two displays with approved live control; record the results in this file

**Checkpoint**: Stories 2 and 3 work together.

## Phase 7: User Story 4 — Open the main window with a hotkey (P3)

**Goal**: an optional shortcut, off by default, opens the main window; a floating panel when the item is hidden.

**Independent test**: record ⌃⌥⌘L, press it in another app, label the Desktop from the main window; clear it: nothing
happens.

- [X] T043 [P] [US4] Create `Sources/DesktopNameApp/Hotkey/Shortcut.swift` (key code and modifiers; valid only with "at least two of ⌃⌥⌘, or ⌘ with ⇧; Escape, Return, Tab, Space alone refused"; display string such as "⌃⌥⌘L") and `ShortcutRecorder.swift` (a SwiftUI control that captures one key while focused); `Tests/DesktopNameAppTests/ShortcutTests.swift` covers the rules and the display strings
- [X] T044 [US4] Create `Sources/DesktopNameManager/HotkeyRegistrar.swift`: `RegisterEventHotKey`/`UnregisterEventHotKey` (research R3); on `eventHotKeyExistsErr` or any failure, report it so Settings shows "Another app is using this shortcut. Choose another." and the shortcut is not stored (FR-015); register at launch when a shortcut is stored
- [X] T045 [US4] In `Sources/DesktopNameManager/PopoverPresenter.swift`, open the main window from the hotkey for the active display: in the popover from the status item when shown, else in a floating `NSPanel` near the top of the active display, where "Style and Preview…" swaps in the editor (FR-014); one main window or editor at a time
- [X] T062 [US4] Second hotkey (FR-014, decided 2026-11-20): `AppSettings.editorHotkey` (`editorHotkeyKeyCode`, `editorHotkeyModifiers`); `HotkeySetting` manages both shortcuts (one refuses the other's shortcut with its sentence; recording lets both go); `HotkeyRegistrar` registers each under its own ID and reports which was pressed; Settings › General shows two recorders; tests in `SettingsTests.swift`
- [X] T063 [US4] In `PopoverPresenter.swift`, the hotkey table in contracts/app-ui.md: open the page for the active display; the same hotkey moves the window to the next display (left to right, wrapping; it stays with one display or Separate Spaces off), the other hotkey switches the page; a floating panel when the item is not on the chosen display; Cancel closes an editor the hotkey opened; the next-display order in `DesktopNameApp` with tests
- [X] T064 [US2] The main window's button reads "Apply" (FR-013a); `contracts/app-ui.md` updated
- [X] T065 [US4] A way to Settings always (FR-014a, decided 2026-11-20): `SettingsModel.setMenuBarMode` refuses Hidden without a working main hotkey; `HotkeySetting.clear(.main)` refuses while hidden; `keepAWayToSettings()` shows the item at launch when the main hotkey is missing or refused; tests in `SettingsTests.swift`
- [X] T066 [US5] Clean Up layout (live check, 2026-11-21): the days field had a stray "Days" label; the header shows the count ("Old labeled images: 22"); Select all, the selection's count and size, and Delete Selected… sit in a bar pinned under the list (`safeAreaInset`), so a long list never scrolls them away; `CleanUpModel.summary`; test in `PaneTests.swift`; `contracts/app-ui.md` updated
- [X] T067 [US5] Displays pane (live check, 2026-11-21): the inline "Add alias" field had no visible border in the grouped form, so it did not look like a field (its title had also taken its width); replaced, as Users & Groups' Add User… does, by an "Add Alias…" button per display that opens a sheet with a bordered field, the rules, the refusal inline, and Cancel / Add; aliases are rows with a remove button. `DisplaysModel.add` returns the refusal for the sheet; tests in `PaneTests.swift`; `contracts/app-ui.md` updated
- [X] T046 [US4] Live check (quickstart scenario 8, now with both hotkeys, moving and switching) with approved live control; record the results in this file. 2026-11-20, `dnm --version` 0.4.0 build 48 (b9b5a4d+), two displays: all six steps passed (the maintainer). Earlier build 42 run: a shortcut macOS reserves (⇧⌘3) never reaches the recorder, and `RegisterEventHotKey` accepted ⌃⌥⌘K while a helper process held it exclusively, so another app's shortcut is not detected (FR-015 amended).

## Phase 8: User Story 5 — Settings, Configuration and About in one window (P3)

**Goal**: the Settings window with its sidebar: General (with the defaults for new labels), Clean Up with the over-50 MB message,
Configuration, Displays, Labels and About.

**Independent test**: change each setting and relaunch; launch again to reach General; the main window's items open
the right panes; Clean Up lists what `dnm cleanup` lists; the values the panes share with `dnm about` and `dnm check`
match.

- [X] T047 [P] [US5] Create `Sources/DesktopNameApp/Model/AppSettings.swift` per contracts/app-settings.md: every key, type and default in its table (`menuBarMode` `iconAndText`; `hotkeyKeyCode` and `hotkeyModifiers` absent (no hotkey); `defaultLook`/`defaultColor` `automatic`; `defaultPosition` `bottom-left`; `defaultSize` `medium`; `cleanUpDays` "Int, 1 to 3650", 30; `welcomeShown` false); "An unknown or invalid value is read as the default and is not rewritten until the person changes that setting"; backed by an injectable `UserDefaults`; `Tests/DesktopNameAppTests/AppSettingsTests.swift` covers defaults, round trips, invalid values, and that nothing is written to the label store or read by `dnm` (FR-018)
- [X] T048 [P] [US5] Create `Sources/DesktopNameApp/Model/CleanUpModel.swift` per data-model.md (CleanUpModel): `cleanupPlan(days: cleanUpDays)`, total, confirmation, `carryOut`; `cleanUpWarning` while what Clean Up could free is at least `DesktopLabeler.nudgeThresholdBytes` (FR-016b, research R10, not throttled); `Tests/DesktopNameAppTests/CleanUpTests.swift`: the list equals `dnm cleanup`'s for the same store and days; nothing is deleted before confirming; a candidate put on screen meanwhile is kept (the core's re-check); the warning appears at 50 MB and goes after cleaning
- [X] T049 [US5] Create `Sources/DesktopNameManager/SettingsWindowController.swift` and `Sources/DesktopNameApp/Windows/SettingsWindowView.swift`: one window, a `NavigationSplitView` with the sidebar of contracts/app-ui.md §Settings window (General, Clean Up, Configuration, Displays, Labels, About) and the selected pane as a grouped form (research R2); `show(pane:)` used by the main window's Settings… (General), Configuration…, About Desktop Name Manager, Labels in use, Clean Up…, and by a second launch (General, FR-017); and the panes `GeneralPane.swift` (Open at login through a `LoginItem` protocol, `SMAppService.mainApp`, status read each time the pane opens, research R4, faked in tests; Menu bar shows, wired to T041; the hotkey recorder with no on/off checkbox, T043-T044; New Labels: the defaults, with no sample, applied to new labels in the main window and the editor only) and `CleanUpPane.swift` (row selection, Delete Selected off until something is selected, its confirmation and the red message); no explanatory lines and no mention of `dnm` or Terminal (FR-019a); the window shows the Dock icon while open
- [X] T050 [US5] In `Sources/DesktopNameApp/Main/MainView.swift`, the storage row: "Space used: <size>" and "<size> in old images" with Clean Up… (computed when the main window opens; opens the Clean Up pane); at the FR-016b threshold the second line turns red with a warning symbol and the words, so it does not rely on color (FR-016b, FR-027); no separate banner
- [X] T051 [P] [US5] Create `Sources/DesktopNameApp/Windows/ConfigurationPane.swift`, `DisplaysPane.swift`, `LabelsPane.swift` and `AboutPane.swift` per contracts/app-ui.md §Settings window, from `About.info(dataDirectory:)`, `DesktopLabeler.check(_:)` and the store (FR-019, research R8): Configuration (macOS, Separate Spaces, labels in use and old labeled images with Clean Up…, the data folder with Show in Finder); Displays (each display, the main one marked, with its aliases as removable tags and an Add alias field, through `Aliases.setAlias`/`removeAlias`, with the core's sentences and the `--display` clause dropped; `Tests/DesktopNameAppTests/DisplaysPaneTests.swift` covers add, remove, move and each refusal against a temporary store); Labels (the labels in use with display and size); About (the header card without a build date, Privacy with the two promises, Links with the source and the Acknowledgements page); no Copy button, no Accessibility or Space-shortcut row, no Updates section; `Tests/DesktopNameAppTests/AboutConfigurationTests.swift` checks the shared values against `dnm about` and `dnm check`, and the Labels pane's list against `dnm list`
- [ ] T052 [US5] Live check (quickstart scenarios 9, 10, 11) with approved live control; record the results in this file
  - Scenario 10 (Clean Up), 2026-11-21, `0.4.0 build 53 (83d7f8c+)`, throwaway store: passed. The red message showed at 53.7 MB, the list matched `dnm cleanup` (22), and deleting all cleared the list and the message. The first run's layout faults (the days field's stray label, a list that pushed Delete Selected… off screen) were fixed in T066. The re-run with 20 images: header count, pinned bar, "2 selected", and deleting Bulk 1 and Bulk 2 left exactly the other 18 (checked with `dnm cleanup`). Scenario 9 still to run.
  - Scenario 11 (Settings window), 2026-11-21, `0.4.0 build 56 (45ed397+)`, throwaway store: passed. The first run found the Displays pane's inline alias field unusable (T067); on the Add Alias… sheet, `laptop` was added and `dnm alias` and `dnm check` showed it; `main` and `123` were refused in the sheet and not stored; removing it left `dnm alias` empty. Settings…, Configuration… and About open their panes; Configuration and About match `dnm check` and `dnm about`; Labels matches `dnm list`; nothing names `dnm` or Terminal. FR-014a: "Nothing (hidden)" refused without a main hotkey, allowed with one, and the main shortcut could not be cleared while hidden.

## Phase 9: Polish and cross-cutting

- [ ] T053 [P] Accessibility pass (FR-027): every control labeled, Tab order, Return and Escape, the preview's accessibility value ("Preview: 'Mail' at bottom left, halo, light text"); live check quickstart scenario 13 with VoiceOver
- [ ] T054 [P] `docs/app-and-cli.md`: bring the list to the built state (each app-only and `dnm`-only capability, reasons, links), per FR-021a
- [ ] T055 [P] `README.md`: an app section (installing, the menu bar, the editor, the hotkey, Settings, Clean Up, the welcome window, that `dnm` is inside and unchanged, that the app needs no permission); `docs/release-notes/UNRELEASED.md` (bullets only): the app
- [ ] T056 [P] Write the spec 005 amendment (`specs/005-packaging-and-release/`): the release zip holds the app; signing nested code (`Contents/Helpers/dnm`, then the app) with hardened runtime and no entitlements; notarizing and stapling the app; the cask installs the app and links `dnm` and `desktop-name` to `Contents/Helpers/dnm` (contracts/app-bundle.md); its own plan and tasks, reviewed separately; not part of this spec's merge gate
- [ ] T057 Update `.periphery.yml` and `scripts/periphery.sh` if needed; `just test` and `just periphery` pass (a native build first); scan the diff for personal paths, names and UUIDs
- [ ] T058 `dnm` unchanged (FR-020, SC-005): `git diff main -- Sources/dnm` is empty; the 0.3.0 contract tests pass unchanged; after the app has set, removed and undone labels in a private store, the installed `dnm` 0.3.0 reads that store (`show`, `list`, `cleanup`) with no error (FR-022); `Tests/live/live-syntax.sh` passes with the app running (quickstart scenario 14)
- [ ] T059 Quickstart scenario 12 (SC-006, SC-008) on a fresh user account: no permission prompt; `nettop` shows no connection from the app; record the results
- [ ] T060 Independent review before merge (constitution VII): a code review and a security review (permissions, file access, the hotkey, the login item, the store shared with `dnm`, the bundle script), each by a separate agent with fresh context given only the branch's diff against `main`; findings fixed (with a fresh re-review of the fixes) or accepted by the maintainer, and recorded in this file
- [ ] T061 Merge `014-menu-bar-app` into `main` after the maintainer's go-ahead; remove the worktree after checking for uncommitted changes; macOS 26 checks (quickstart scenario 15) are a release gate for 0.4.0, recorded in its gate record

## Dependencies

- Phase 1 first. Phase 2 (stage 1 mockups) needs only T003; **Gate A (T011) blocks every task from T012 on**, with no
  exception (FR-002, SC-007).
- Phase 3 before Phase 4. T012 before every other Phase 3 task; T013 before T022, T024, T027 and all app tests; T014 needs
  the approved icon (T011); T015 before T016-T017.
- **Gate B (T028) blocks Phases 5-8.**
- US2 (Phase 5): T031 before T034; T032 before T033-T035; T030 before T031's messages are shown.
- US3 (Phase 6) needs T033; T038 (spike S1) before T040.
- US4 (Phase 7) needs T034 (the presenter) and T049's General pane for the recorder's place in Settings (T043 can
  start earlier).
- US5 (Phase 8) needs T032-T034; T047 before T049; T048 before T049-T050; T051 before T049 wires its panes.
- Phase 9 after the stories it describes; T060 after T053-T059; T061 last.

## Parallel examples

- Phase 2: T006, T007, T008, T009 together after T004-T005 set the page's structure.
- Phase 3: T014, T018, T019, T020 together after T012-T013; then T021, T022, T023, T024 together.
- Phase 5: T029, T030 and T036 together; T033 and T035 side by side after T032.
- Phase 8: T047, T048 and T051 together.
- Phase 9: T053, T054, T055 and T056 together.

## Implementation strategy

1. **Prototypes first**: Phases 1-2 and Gate A; nothing user-visible is built before it.
2. **Foundation and the editor prototype**: Phases 3-4 and Gate B.
3. **MVP**: Phase 5 (US2): label, remove and undo from the menu bar, with the welcome window. Usable on its own.
4. Then US3 (the label in the menu bar), US4 (hotkey), US5 (the Settings window: settings, Clean Up, Configuration,
   About).
5. Polish, reviews, merge. Packaging (the spec 005 amendment) is planned in parallel so 0.4.0 can ship the app.
