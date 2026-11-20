# Implementation Plan: The menu-bar app and label editor (M2)

**Branch**: `014-menu-bar-app` (implementation in `.worktree/014-menu-bar-app`) | **Date**: 2026-11-12 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/014-menu-bar-app/spec.md`

## Summary

A Mac app, `Desktop Name Manager.app`, that labels the Desktop on screen from the menu bar: a main window under the
menu-bar item that labels this Desktop with the defaults, a popover editor with a live preview rendered by the same core
as `dnm`, the current Desktop's label in the menu bar, an optional hotkey, one Settings window with a sidebar (General,
Clean Up with the over-50 MB message, Configuration, Displays, Labels, About), and a first-launch welcome
window. `dnm` ships
inside the app and is unchanged. Work starts with prototypes in two stages (web mockups, then a runnable editor), each
approved by the maintainer before the next step. Technically: two new SwiftPM targets (an app library and a thin
executable) built by `just build`, assembled into a bundle by a new script; AppKit status item and popover with
SwiftUI content; Carbon `RegisterEventHotKey`; `SMAppService` for login; the existing store and its lock, unchanged
(research R1 to R16).

## Technical Context

**Language/Version**: Swift 6.4 (language mode 6), as the package.

**Primary Dependencies**: Apple frameworks only: AppKit, SwiftUI, ServiceManagement (`SMAppService`), Carbon
(`RegisterEventHotKey` only), CoreGraphics and ImageIO through the core. No new third-party dependency;
swift-argument-parser stays `dnm`'s only one and is not linked into the app.

**Storage**: the existing label store (format 3, unchanged, shared with `dnm`, R7); app settings in the app's user
defaults (R9, contracts/app-settings.md).

**Testing**: Swift Testing; a new `DesktopNameAppTests` target with the fake wallpaper system and temporary stores;
the existing `dnm` contract tests unchanged; local snapshot checks over `wallpaper-samples/`; live checks in
`quickstart.md`.

**Target Platform**: macOS 26 or later, Apple silicon (R13).

**Project Type**: desktop app plus the existing command-line tool, on one core library.

**Performance Goals**: preview updated within 0.25 s of a change (SC-002, spike S2); Apply under 1 s for a 5K
wallpaper (FR-026); menu-bar label updated within 1 s of a Desktop switch (SC-004, spike S1).

**Constraints**: public interfaces only, no permission, no network, no SIP change (FR-023 to FR-025); `dnm`'s
behavior byte-for-byte unchanged (FR-020); identical applied images from the app and `dnm` (SC-003).

**Scale/Scope**: one user, 1 to 4 displays, tens of labels; about 10 screens and states to prototype; roughly 2,000
lines of new Swift.

## Constitution Check

*GATE: checked before Phase 0 and again after Phase 1 design.*

| Principle | How this plan meets it | Result |
|---|---|---|
| I. Public APIs only | `NSStatusItem`, `NSPopover`, SwiftUI, `NSWorkspace` wallpaper and Space notifications, `SMAppService`, `RegisterEventHotKey`, `DispatchSource` file watch; no SkyLight, no reading of the wallpaper store or system preferences (R2 to R5) | Pass |
| II. No SIP change | Nothing in the app or its install touches SIP | Pass |
| III. Least permission | Nothing in M2 needs a permission (FR-023); the hotkey uses the one public API that needs none (R3); global event monitors rejected; `--desktop` and `--scan` stay in `dnm` | Pass |
| IV. Local-only | No networking code, no analytics or crash reporting; checked live (SC-008) | Pass |
| V. Reversible changes | Apply, Remove and Undo are the core calls `dnm` makes; originals never modified; Clean Up deletes only our stamp files after confirmation (FR-016a) | Pass |
| VI. Homebrew | Signed, notarized app with `dnm` inside; the cask change is the spec 005 amendment (below) | Pass, with the amendment |
| VII. Tested | Unit tests for the app model, unchanged `dnm` contract tests, local snapshots for the preview, live checks with the `Index.plist` backup in the quickstart; independent reviews before merge and release | Pass |
| VIII. Public-repo hygiene | Prototypes and icon use synthetic images; no personal paths or identifiers in tests, mockups or docs (FR-003) | Pass |
| Platform: App Store goal | Not sandboxed; the store, wallpaper access and the bundled CLI are recorded as known gaps (R14, FR-028) | Pass (gap recorded) |
| Platform: minimum macOS | 26, reasoning in R13 | Pass |
| Platform: licenses | No new component; the app's About lists the same acknowledgements, and the bundle carries `Licenses/` | Pass |

Post-design re-check (after data-model, contracts and quickstart): no change; nothing in the design adds a
permission, a dependency, a private interface or a stored format.

## Phases of the work

The order `tasks.md` will follow; each gate is a maintainer approval.

1. **Prototype stage 1** (US1): web mockups of every FR-001 state, the icon draft, and `prototypes/REVIEW.md`.
   **Gate A**: the maintainer approves the mockups.
2. **Foundation**: the new targets, `scripts/make-app.sh`, `just app`, the core additions (contracts/core-additions.md)
   with their tests, Periphery configuration.
3. **Prototype stage 2** (US1): `EditorPrototype` with the real editor views and preview; spike S2 (preview speed and
   automatic-style agreement). **Gate B**: the maintainer approves the editor.
4. **Labeling from the menu bar** (US2, P1): status item, menu, editor popover, Apply, Remove, Undo; the welcome window
   (it opens the editor).
5. **Menu-bar label** (US3, P2): spike S1 first; the modes and following the active display.
6. **Hotkey** (US4, P3) and **the Settings window: General, Clean Up, Configuration, Displays, Labels,
   About, login** (US5, P3).
7. **Polish**: VoiceOver pass, `docs/app-and-cli.md` final state, README section for the app, live checks, reviews.

The spec 005 amendment (packaging: the zip holds the app, the cask installs it and links `dnm` and `desktop-name` from
`Contents/Helpers`, signing nested code, stapling the app) is written and planned alongside phase 2, so the release
script is ready when the app is; it is its own review.

## Project Structure

### Documentation (this feature)

```text
specs/014-menu-bar-app/
├── spec.md
├── plan.md                    # this file
├── research.md                # Phase 0
├── data-model.md              # Phase 1
├── quickstart.md              # Phase 1: live checks
├── contracts/
│   ├── app-ui.md              # screens, menu, states, messages
│   ├── app-bundle.md          # bundle layout, Info.plist keys, where dnm lives
│   ├── app-settings.md        # user-defaults keys and defaults
│   └── core-additions.md      # new public core API
├── prototypes/                # stage 1 mockups and REVIEW.md (tracked, synthetic images only)
├── checklists/requirements.md
└── tasks.md                   # /speckit-tasks
```

### Source Code (repository root)

```text
Package.swift                         # + DesktopNameApp, DesktopNameManager, EditorPrototype, DesktopNameAppTests
Sources/
├── DesktopNameCore/                  # + Operations/Preview.swift, Operations/CurrentLabel.swift, Store/StoreWatcher.swift
├── dnm/                              # unchanged
├── DesktopNameApp/                   # library: app logic and SwiftUI views
│   ├── Model/                        # AppSettings, EditorDraft, QuickLabel, MenuBarState, CleanUpModel, WelcomeState
│   ├── Editor/                       # EditorView, StyleChips, PreviewView
│   ├── Main/                         # MainView (the panel under the menu-bar item)
│   ├── Windows/                      # WelcomeView, SettingsWindowView (sidebar) and one view per pane
│   └── Hotkey/                       # Shortcut value type and recorder view (registration lives in the executable)
└── DesktopNameManager/               # executable: AppDelegate, StatusItemController, PopoverPresenter (main window,
                                      # editor; panel when hidden), SettingsWindowController,
                                      # HotkeyRegistrar (Carbon), LoginItem (SMAppService), SingleInstance, ActiveDisplay
prototype/editor/                     # EditorPrototype: dev-only, fake wallpaper system, never shipped
Resources/App/                        # Info.plist template, AppIcon.iconset
scripts/make-app.sh                   # assembles and (dev) ad-hoc signs the .app
Tests/DesktopNameAppTests/            # unit tests for DesktopNameApp
```

**Structure Decision**: one Swift package, as today. The app's logic is a library so it can be tested with the fake
wallpaper system; the executable stays thin; the prototype target reuses the library's editor views so stage 2's work
carries into the app.

## Complexity Tracking

No constitution violations. One recorded gap, not a violation: App Store compatibility (R14, FR-028).

## Rollback

Everything is additive: new targets, a new script, new `just` recipes, a few public core functions that `dnm` does not
call. Rolling back is reverting the feature's merge; `dnm` and the store are untouched, so labels made by the app stay
usable with `dnm`.
