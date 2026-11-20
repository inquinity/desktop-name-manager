# Research: The menu-bar app and label editor (spec 014)

Phase 0 of the plan. Each item: the decision, why, and what else was considered. Items marked **spike** are settled by
a measurement or a live check during the build (named in `tasks.md`), with the fallback stated here.

## R1. How the app is built: SwiftPM plus a bundle script, no Xcode project

- **Decision**: the app is two new SwiftPM targets in the existing package (R12), built by `just build` like `dnm`, into
  `build.noindex/`. A new script, `scripts/make-app.sh`, assembles `Desktop Name Manager.app` from the built
  executables: `Contents/MacOS/DesktopNameManager`, `Contents/Helpers/dnm`, `Contents/Info.plist` (from a tracked
  template, `Resources/App/Info.plist`, with the version and build from `Version.xcconfig`), `Contents/Resources/`
  (the icon, the license files) and `PkgInfo`. `just app` builds and assembles a development app (bundle ID with the
  `.dev` suffix, ad-hoc signed); `just run-app` opens it. The build stamp (`scripts/build-stamp.sh`) goes into both
  executables, so the app's About shows the same version line as `dnm --version`.
- **Rationale**: one build system, one scratch path, one build stamp. The constitution's checks (`just test`,
  Periphery, the release script's binary checks) already work on SwiftPM output. The app needs no asset catalog,
  storyboard or entitlements, which is what an Xcode project would mainly add.
- **Alternatives**: an Xcode project (`.xcodeproj` or a generated one): asset catalogs and SwiftUI canvas previews,
  but a second build system, project-file churn in a public repo, and the release script would have to drive
  `xcodebuild` as well as `swift build`. Rejected. Xcode is still usable as an editor: it opens `Package.swift`.
- **Icon**: an `.icns` made by `iconutil` from a tracked `.iconset` of PNGs drawn for this project (synthetic, no
  personal image, constitution VIII). The icon is designed in prototype stage 1 (R11).

## R2. The menu-bar item and the editor: AppKit status item with SwiftUI content

- **Decision**: an `NSStatusItem` whose button shows the icon and, in Icon and text mode, the app's fixed text; never the label
  (FR-010, prototype review round 3).
  Clicking it opens the main window: an `NSPopover` anchored to the item (FR-013, prototype review 2026-11-19), whose
  content is read from the store each time it opens, so it always reflects it. "Style and Preview…" replaces the
  popover's content with the editor (Cancel returns to the main window); the hotkey opens the editor in the same
  popover, or, when the item is hidden, in a floating `NSPanel` near the top of the active display (FR-014). The
  Settings window is one `NSWindow` holding a SwiftUI `NavigationSplitView`: a sidebar of panes (General, Create
  Label, Clean Up, Configuration, Displays, Labels, About) and the selected pane as a grouped `Form` (FR-016); the
  main window's items and a second launch select the pane to show. All content is SwiftUI, hosted with
  `NSHostingController`. The popover becomes key while open so its field takes typing; that needs no permission.
- **Rationale**: SwiftUI's `MenuBarExtra` has no public way to open its window from code, which the hotkey needs, and
  no control over the item's length for long labels. AppKit gives both, with public APIs; SwiftUI keeps the views
  short and previewable.
- **Alternatives**: `MenuBarExtra` (`.window` style) alone: simpler, but cannot be opened by the hotkey. An `NSMenu`
  (the design before 2026-11-19): it cannot hold a text field that takes typing well, nor the space and Clean Up line
  laid out as the review asked. SwiftUI's `Settings` scene for the window: it cannot be told which pane to open from the
  main window's items; an `NSWindow` hosting the split view can. AppKit views throughout: more code for the same
  result.
- **Long labels** (US3 scenario 6): the item never shows the label, so its width is fixed; the main window's first
  line shows the label whole, wrapping if needed.

## R3. The hotkey: Carbon `RegisterEventHotKey`, no permission

- **Decision**: register the one hotkey with `RegisterEventHotKey` (Carbon Event Manager, public and documented,
  still supported on macOS 26 and 27). Settings has a small shortcut recorder built for this app: it captures one key
  with at least two of ⌃⌥⌘ (or ⌘ plus ⇧), shows it, and registers it. If registration fails (`eventHotKeyExistsErr`,
  another app holds it), Settings says so and the hotkey stays off (FR-015).
- **Rationale**: the only public way to get a system-wide shortcut without Accessibility or Input Monitoring
  (FR-023). Global event monitors (`NSEvent.addGlobalMonitorForEvents`) need Accessibility; rejected.
- **Alternatives**: the `KeyboardShortcuts` package (MIT), which wraps the same call and adds a recorder: a new
  dependency for about 150 lines of our own code; rejected (constitution: a dependency must be justified).
- **Limit**: a shortcut macOS itself uses (for example one in Keyboard Shortcuts settings) may register yet never
  reach the app; Settings' help line says to pick another if the hotkey does nothing. A shortcut another app holds is
  refused at registration, which is the common case.

## R4. Launch at login: `SMAppService.mainApp`

- **Decision**: `SMAppService.mainApp.register()` and `unregister()`, from Settings (FR-016; the welcome window holds no
  settings since prototype review, 2026-11-16). Settings reads `status` each time it opens, so a login item turned off in System Settings > General >
  Login Items shows as off. macOS shows its own "Login item added" notice; the app adds none.
- **Rationale**: the public, current API; no helper app, no permission.
- **Alternatives**: a LaunchAgent plist (deprecated route for apps, and writes outside the app's data); rejected.

## R5. Which Desktop the main window and the hotkey are about (FR-011, FR-012) — spike

- **Decision** (revised after prototype review round 3, 2026-11-19, when the item stopped showing the label): nothing
  has to follow Desktop switches in the background. The main window reads, when it opens, `desktopImageURL(for:)` for
  the screen whose menu bar was clicked (the status item button's window's screen) and looks the file up in the store:
  one of our stamps gives its label; anything else gives "No label". The counts and sizes it shows are read at the same
  moment. The hotkey opens the editor for the **active display**: the screen of the frontmost app's frontmost window
  where macOS reports it (`NSScreen.main` as seen from the app), else the screen under the pointer.
- **Two cases with their own rule** (spec Edge Cases): with "Displays have separate Spaces" off, the main window is
  about the main display (one Desktop spans every display, as `dnm` treats it); with a full-screen app in front, it
  names the label of the stamp the display reports, if any, else "No label", and never guesses.
- **Spike S1** (before the hotkey and the main window are finished): on two displays, check that (a) `NSScreen.main`
  follows the display with the frontmost window while the app is in the background, and (b) `desktopImageURL(for:)`
  reports the new Desktop's image when the main window is opened right after a switch (`dnm` waits up to 3 s for the
  wallpaper to settle after a switch). Fallbacks: (a) the screen under the pointer; (b) re-read once after 0.5 s while
  the window is open.
- **Rationale**: no public interface names the current Desktop; the wallpaper on screen is what `dnm show` already
  relies on, so the app and `dnm` agree.
- **Alternatives**: following every switch with `activeSpaceDidChangeNotification` (the design before round 3; no
  longer needed, since nothing on screen shows the label until the main window opens); polling every second; private
  Space notifications (constitution I); rejected.

## R6. The live preview: the core renderer at preview size — spike

- **Decision**: a new public core function renders a preview: it resolves the Desktop's **original** image (the one
  `setLabel` would stamp, never the current labeled image, so labels do not stack in the preview either), composes
  it for the display as `Backdrop` does, scales it down to the preview's pixel size, and runs `LabelRenderer` with a
  display geometry scaled by the same factor. The backdrop for a Desktop is loaded once when the editor opens; each
  change of text or option re-renders on a background task, with changes coalesced (the newest wins). Each style
  chip is the same render at chip size.
- **Rationale**: the same pipeline as Apply, so the preview is what will be applied (SC-003 concerns the applied
  image, which is the full `setLabel` path). Rendering a downscaled backdrop is far cheaper than a 5K one.
- **Spike S2** (in prototype stage 2): measure the preview on the sample wallpapers; SC-002 asks for a quarter of a
  second. The automatic style is chosen from sampled statistics, which are close at preview size but can differ near
  a threshold; the spike compares the automatic choice at preview and full size over `wallpaper-samples/` and, if
  they ever differ, the preview takes the style choice from a full-size sample of the label's area (computed once per
  position and size). Fallback for speed: a smaller preview, then fewer chip renders.
- **Alternatives**: drawing the label as a SwiftUI overlay on the wallpaper (fast, but not the real rendering: the
  halo, frost and automatic choice would only be imitated); rejected.

## R7. One store for the app and `dnm` (FR-021, FR-022)

- **Decision**: no change to the store. The app uses `Store.defaultDirectory()` and the same `DesktopLabeler`
  operations as `dnm`; the store's `flock` on `manifest.lock` (`StoreLock`) and atomic owner-only writes already keep
  two runs from interleaving. The app holds the lock only for the length of one operation, never while a window is
  open. The editor works from the store as it is when Apply is pressed (`setLabel` reads it under the lock).
- **Undo**: the existing per-display undo record and its 60-second window (`Housekeeping.undoWindow`); the main window offers
  Undo when `checkUndo(on:onScreen:)` passes for the active display. `dnm undo` and the app's Undo are the same call.
- **Threads**: `SystemWallpaperSystem` must run on the main thread and `Store.exclusive` is per thread, so Apply,
  Remove, Undo and Clean Up run on the main actor, as one call each. The editor shows its working state before the call
  starts (one run-loop turn), and the call takes under a second (FR-026).
- **Store name**: a debug build of the app uses the `.dev` store, as a debug `dnm` does; release builds share the
  release store. `DNM_STORE_DIR` is honoured, so live checks run the app on a private store (`open --env`).
- **Format**: format 3, unchanged; nothing new is stored in it (app settings are kept elsewhere, R9).

## R8. The About, Configuration, Displays and Labels panes from the same source (FR-019)

- **Decision**: the panes take their values from the core, from `About.info(dataDirectory:)` and
  `DesktopLabeler.check(_:)`, the same source as `dnm about` and `dnm check`, but show only a subset (prototype review,
  2026-11-16, FR-019): About shows the essentials; Configuration shows the macOS version, Separate Spaces and the
  displays with their aliases, and the stored labels from the store. The Accessibility row is left out (the app does
  not use the permission, and `AXIsProcessTrusted()` in the app would report the app, not the terminal that runs
  `dnm`), as is the Space-shortcut row (not readable through public interfaces). Since prototype review on
  2026-11-19 these are panes of the Settings window: Configuration (macOS, Separate Spaces, space used, the data
  folder), Displays (each display with its aliases, which it adds and removes through the core's alias operations) and Labels (the labels in use, from the store); the main window
  shows the count of labels in use and the space used from the same reads.
- **Rationale**: the values they share never disagree because there is one source; a row the app cannot act on or
  read is noise to someone who never uses a terminal (FR-019a).
- **Alternatives**: run the bundled `dnm check --json` and show its output: same result with a second process and its
  failure modes; rejected.

## R9. App settings: the app's user defaults

- **Decision**: `UserDefaults` in the app's own domain (the bundle ID, `.dev` for development): menu-bar mode, hotkey
  (key code and modifiers, or none), label defaults (style, color, position, size), whether the welcome window was shown, and
  the age used by Clean Up's list (the `dnm cleanup` default, 30 days, unless changed). Open at login is not stored:
  `SMAppService` is the truth. Keys and defaults are in `contracts/app-settings.md`.
- **Rationale**: per-user, kept across restarts, outside the label store (spec: app settings are not part of it), and
  never read by `dnm` (FR-018).

## R10. Clean Up and the over-50 MB message (FR-016a, FR-016b)

- **Decision**: Clean Up shows `cleanupPlan(days:)` and deletes with `carryOut(_:)`, the calls `dnm cleanup` makes,
  after a confirmation sheet that names how many labels and how much space. The red message uses `dnm`'s nudge rule:
  it shows while what Clean Up could free is at least `nudgeThresholdBytes` (50 MB); unlike `dnm`'s note it is not
  throttled, since it is a state shown in the main window, not a line printed after a command. The text says it in words
  ("Old labeled images use 63 MB. Clean Up…"), in the system red, with a warning symbol, so color is not the only cue.
- **Interpretation to confirm**: the spec says "when labeled images use more than 50 MB". The plan reads it as `dnm`'s
  threshold: space Clean Up could free, not the space every label uses (labels in use cannot be cleaned up, so a
  warning about them would have no action). Spec FR-016b is worded to match.
- **`cleanup --scan`** stays in `dnm` (it needs Accessibility); Clean Up's help line says so.

## R11. Prototypes (FR-001 to FR-003)

- **Stage 1, web mockups**: self-contained HTML files in `specs/014-menu-bar-app/prototypes/` (tracked: they are
  design records), built from the September 2026 concepts but limited to this spec's options, published as a private
  claude.ai artifact for review on any device. Wallpapers in them are synthetic (generated gradients and shapes); no
  file from `wallpaper-samples/` or `working-notes/` is copied in. Every state in FR-001 has a direct link. Review
  rounds and the approval go in `prototypes/REVIEW.md`.
- **Stage 2, runnable editor prototype**: a development-only executable target, `EditorPrototype` (R12), that shows
  the real editor views with the real preview (R6) over a fake wallpaper system: images from `wallpaper-samples/` when
  that folder exists (local only), otherwise synthetic ones. It has no code path to `SystemWallpaperSystem` or the
  real store (a temporary store), so it cannot change the wallpaper (FR-003). It measures the preview time (spike
  S2). Its views become the app's views after approval, so the work is kept.
- **Rationale**: the maintainer's decision (2026-11-12): web mockups settle layout and wording cheaply; the editor
  prototype checks what only real rendering can show.

## R12. Code layout

- **Decision**:
  - `Sources/DesktopNameApp/` (library): the app's logic and views, testable without AppKit's real objects: settings
    model, menu-bar state, editor draft and validation, Clean Up model, the SwiftUI views.
  - `Sources/DesktopNameManager/` (executable): the app delegate, status item, popover and panel, hotkey, login item,
    single-instance check, file watch. Thin.
  - `prototype/editor/` as target `EditorPrototype` (executable, never shipped, never in a release product).
  - Core gains a small public surface (contracts/core-additions.md): preview rendering, "which label is this display
    showing", and store-change observation helpers. Nothing in `dnm` changes.
- **Rationale**: logic in a library is unit-testable with the existing fake wallpaper system (`DNMTestSupport`);
  the executable is glue checked live.

## R13. Minimum macOS: 26

- **Decision**: macOS 26 or later, Apple silicon, as `dnm` (`Package.swift` already says `.v26`). Every API above
  (`SMAppService`, `NSStatusItem`, `NSPopover`, SwiftUI hosting, `RegisterEventHotKey`) predates 26, so 26 costs
  nothing; nothing in this design needs 27. The plan cannot test on 26 locally (this Mac runs 27); the live checks on
  26 are listed in the quickstart for the release gates.

## R14. App Store gap (FR-028)

- **Recorded gap**: a sandboxed app could not use `dnm`'s store in `~/Library/Application Support/` (it would get a
  container), could not read wallpapers outside its container without the person choosing them, and could not ship
  `dnm` usable from the PATH in the same way. This design depends on all three. To be resolved by the App Store
  readiness work in the backlog before any App Store build; nothing in M2 makes it harder (no private interfaces, no
  permissions).

## R15. Testing

- **Unit tests** (`Tests/DesktopNameAppTests/`, Swift Testing, fake wallpaper system, temporary store): settings and
  their defaults, editor validation (the `dnm set` rules), that Apply, Remove and Undo from the app model produce the
  same manifest and the same image bytes as the core calls `dnm` makes (SC-003), menu-bar state for each mode and for
  labeled, unlabeled and unknown wallpapers, Clean Up list and the 50 MB rule, the welcome-shown flag.
- **`dnm` unchanged**: the existing contract tests run as they are (SC-005).
- **Snapshot**: preview renders over `wallpaper-samples/` (local only), comparing the automatic style at preview and
  full size (R6).
- **Live checks** (quickstart): menu-bar following on two displays (SC-004), apply, remove and undo against `dnm`,
  hotkey, login item, welcome window, no permission prompt (SC-006), no network (SC-008, with `nettop` on the app's
  process). Each with an `Index.plist` backup, a private store, and labels removed afterwards.
- **Periphery**: `.periphery.yml` gains the new targets; SwiftUI views and `@objc` entry points that only the runtime
  calls are retained by configuration, not by dead-code exceptions.

## R16. Accessibility (FR-027)

- **Decision**: every control has an accessibility label; the editor is keyboard-complete (focus starts in the field;
  Tab through style, color, position, size; Return applies; Escape cancels); the preview's accessibility value
  describes it ("Preview: 'Mail' at bottom left, halo, light text"); the red message is text plus a symbol. Checked
  with VoiceOver in the live checks.
