# Quickstart and live checks: the menu-bar app (spec 014)

How to build the app and prove it works. The automated tests never touch the real wallpaper; every scenario marked
**live** does, and follows the project's live-test rules.

## Before any live scenario

1. Back up the wallpaper index:

   ```bash
   cp ~/Library/Application\ Support/com.apple.wallpaper/Store/Index.plist "$TMPDIR/Index.plist.backup"
   ```

2. Use a private store, and start the app with it (the app honours `DNM_STORE_DIR`, research R7):

   ```bash
   export DNM_STORE_DIR="$(mktemp -d)/store"
   ```

   ```bash
   open --env DNM_STORE_DIR="$DNM_STORE_DIR" "build.noindex/app/Desktop Name Manager.app"
   ```

3. Afterwards: remove every label (`dnm remove` for each display, with the same `DNM_STORE_DIR`), quit the app, and
   restore `Index.plist` only if a wallpaper did not come back.

Quote `dnm --version` and the app's About version line in each result.

## Build and automated checks

```bash
just build
```

```bash
just test
```

```bash
just periphery
```

```bash
just app
```

Expected: all pass; `build.noindex/app/Desktop Name Manager.app` exists with the layout in contracts/app-bundle.md, and
`Contents/Helpers/dnm --version` prints the same version line as the app's About.

## Scenarios

1. **Prototype stage 1** (US1): open the published mockups; every state in FR-001 is reachable from the index; no
   image in `prototypes/` comes from `wallpaper-samples/` or `working-notes/`. Approval recorded in
   `prototypes/REVIEW.md`.
2. **Prototype stage 2** (US1, spike S2): `swift run --scratch-path build.noindex EditorPrototype`; type and change
   options on each sample; the preview keeps up (SC-002, the measured times are printed); the real wallpaper never
   changes; approval recorded.
3. **Label from the menu bar** (US2, live): on a still-image wallpaper, menu > Label this Desktop…, type "Mail", choose
   Halo and top-right, Apply. The Desktop shows it; `dnm list` shows it; `dnm show` reports halo, top-right.
4. **Same image as dnm** (SC-003, automated plus one live spot check): the unit test compares bytes; live, label a
   Desktop from the app, note the stamp file, remove, label it with `dnm set` with the same text and options: `dnm`
   reuses the same image (spec 009 reuse), which shows they are identical.
5. **Undo both ways** (US2 scenario 8, live): label in the app, run `dnm undo`; label with `dnm set`, choose Undo in the
   app's main window within 60 s. Both undo; after 60 s the main window no longer offers Undo. Also label a Desktop
   from the main window's field (US2 scenario 9): it gets the defaults for new labels from General, and `dnm show` reports them.
6. **Unsupported wallpaper** (Edge Cases, live): on a dynamic wallpaper, open the editor: the sentence explains why,
   no Apply, nothing changes.
7. **The main window names the Desktop** (US3, SC-004, live, two displays; spike S1): label two Desktops on each
   display; switch Desktops 20 times across both displays, opening the main window from each display's menu bar after
   each switch; it names the right label every time; a label set with `dnm` shows the next time it opens; the item
   shows only the icon and the fixed text, never a label; Icon and Hidden modes behave as contracts/app-ui.md says.
8. **Hotkey** (US4, live): record a shortcut (⌃⌥⌘L); press it in another app; the editor opens on the active display; hide
   the menu-bar item and press it again: a floating panel opens; pick a shortcut another app holds: Settings says so.
9. **Welcome and login** (US5, live): `defaults delete com.altmansoftwaredesign.desktop-name-manager.dev`, launch:
   the welcome window shows once; turn on Open at login in Settings, log out and in: the app is in the menu bar with
   no window and no welcome window; launching it again opens the Settings window at General.
10. **Clean Up** (US5 scenarios 7 and 8): with a test store holding old labels (made with `dnm` and an earlier date
    through the test support), Clean Up lists what `dnm cleanup` lists; Delete Selected is off until something is
    selected, deletes only the selection, and asks first; above 50 MB the red
    message shows in the main window and in Clean Up, and goes away after cleaning.
11. **The Settings window** (FR-016, FR-019): Settings…, Configuration… and About Desktop Name Manager open it at
    General, Configuration and About; the version, macOS version, Separate Spaces, displays and aliases match `dnm
    about` and `dnm check`; the Labels pane lists what `dnm list` lists for the Desktops on screen and stored; no
    window or message names `dnm` or Terminal (FR-019a).
12. **No permission, no network** (SC-006, SC-008, live): on a fresh user account, run scenarios 3 and 8: no
    permission prompt appears; `nettop -p <app pid>` shows no connection throughout.
13. **VoiceOver** (FR-027, live): with VoiceOver on, label a Desktop using only the keyboard.
14. **`dnm` unchanged** (FR-020, SC-005): `just test` passes the 0.3.0 contract tests unchanged; `Tests/live/live-syntax.sh`
    passes with the app running.
15. **macOS 26** (R13, before the release): scenarios 3, 7 and 9 on a macOS 26 Mac.
16. **Speed and first use** (FR-026, SC-001, live): on one 5K wallpaper, time Apply in the app and `dnm set` with the
    same text and options, three runs each: the app is no slower and under 1 s. Time a first labeling by someone new
    to the app (or the maintainer's first use of the approved build), from clicking the menu-bar item to the label
    showing: under 15 s, without reading help.
