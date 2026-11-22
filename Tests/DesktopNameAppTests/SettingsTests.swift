import DesktopNameApp
import DesktopNameCore
import DNMTestSupport
import Foundation
import Testing

/// App settings (spec 014, T047, contracts/app-settings.md), the welcome window's rule (T036) and the hotkey's
/// shortcut rules (T043).
@MainActor
@Suite struct AppSettingsTests {
    @Test func defaults() throws {
        let rig = try AppRig()
        let settings = rig.settings()
        #expect(settings.menuBarMode == .iconAndText)
        #expect(settings.hotkey == nil && settings.editorHotkey == nil)
        #expect(settings.defaultLook == nil && settings.defaultColor == nil)
        #expect(settings.defaultPosition == .bottomLeft && settings.defaultSize == .medium)
        #expect(settings.cleanUpDays == 30 && !settings.welcomeShown)
        #expect(settings.newLabelOptions == LabelOptions(position: .bottomLeft, size: .medium))
    }

    @Test func valuesRoundTripWithDnmsSpellings() throws {
        let rig = try AppRig()
        let settings = rig.settings()
        settings.menuBarMode = .hidden
        settings.hotkey = Shortcut(keyCode: 37, modifiers: Shortcut.Modifier.control | Shortcut.Modifier.option | Shortcut.Modifier.command)
        settings.defaultLook = .frosted
        settings.defaultColor = .custom(red: 1, green: 0.5, blue: 0)
        settings.defaultPosition = .topRight
        settings.defaultSize = .large
        settings.cleanUpDays = 90
        settings.welcomeShown = true
        #expect(rig.defaults.string(forKey: "defaultColor") == "#FF8000")
        #expect(rig.defaults.string(forKey: "defaultPosition") == "top-right")
        #expect(rig.defaults.integer(forKey: "hotkeyKeyCode") == 37)

        let again = rig.settings()
        #expect(again.menuBarMode == .hidden && again.hotkey == settings.hotkey)
        #expect(again.defaultLook == .frosted && again.defaultColor == .custom(red: 1, green: 128.0 / 255, blue: 0))
        #expect(again.defaultPosition == .topRight && again.defaultSize == .large)
        #expect(again.cleanUpDays == 90 && again.welcomeShown)

        again.hotkey = nil
        #expect(rig.defaults.object(forKey: "hotkeyKeyCode") == nil && rig.defaults.object(forKey: "hotkeyModifiers") == nil)
    }

    @Test func theEditorHotkeyIsStoredApartAndNeverEqualsTheMainOne() throws {
        let rig = try AppRig()
        let main = Shortcut(keyCode: 37, modifiers: Shortcut.Modifier.control | Shortcut.Modifier.option | Shortcut.Modifier.command)
        let editor = Shortcut(keyCode: 14, modifiers: Shortcut.Modifier.control | Shortcut.Modifier.option | Shortcut.Modifier.command)
        let settings = rig.settings()
        settings.hotkey = main
        settings.editorHotkey = editor
        #expect(rig.defaults.integer(forKey: "editorHotkeyKeyCode") == 14)
        #expect(rig.settings().editorHotkey == editor && rig.settings().shortcut(for: .editor) == editor)
        rig.defaults.set(37, forKey: "editorHotkeyKeyCode")   // written by hand as the main one: read as absent
        #expect(rig.settings().editorHotkey == nil && rig.settings().hotkey == main)
        settings.setShortcut(nil, for: .editor)
        #expect(rig.defaults.object(forKey: "editorHotkeyKeyCode") == nil && rig.defaults.object(forKey: "editorHotkeyModifiers") == nil)
    }

    @Test func invalidValuesReadAsDefaultsAndAreNotRewritten() throws {
        let rig = try AppRig()
        rig.defaults.set("sideways", forKey: "menuBarMode")
        rig.defaults.set("neon", forKey: "defaultLook")
        rig.defaults.set("#12", forKey: "defaultColor")
        rig.defaults.set("middle", forKey: "defaultPosition")
        rig.defaults.set(0, forKey: "cleanUpDays")
        rig.defaults.set(53, forKey: "hotkeyKeyCode")   // Escape, refused
        rig.defaults.set(Int(Shortcut.Modifier.command), forKey: "hotkeyModifiers")
        let settings = rig.settings()
        #expect(settings.menuBarMode == .iconAndText && settings.defaultLook == nil && settings.defaultColor == nil)
        #expect(settings.defaultPosition == .bottomLeft && settings.cleanUpDays == 30 && settings.hotkey == nil)
        #expect(rig.defaults.string(forKey: "menuBarMode") == "sideways")   // left as it was
        #expect(rig.defaults.integer(forKey: "cleanUpDays") == 0)
    }

    @Test func cleanUpDaysStaysInRange() throws {
        let rig = try AppRig()
        let settings = rig.settings()
        settings.cleanUpDays = 5000
        #expect(settings.cleanUpDays == 3650 && rig.defaults.integer(forKey: "cleanUpDays") == 3650)
        settings.cleanUpDays = -3
        #expect(settings.cleanUpDays == 1)
    }

    @Test func nothingIsWrittenToTheLabelStore() throws {
        let rig = try AppRig()
        let settings = rig.settings()
        settings.defaultLook = .halo
        settings.welcomeShown = true
        #expect(!FileManager.default.fileExists(atPath: rig.store.directory.path))
    }
}

@MainActor
@Suite struct WelcomeTests {
    @Test func theFirstLaunchShowsItAndOKOrCloseDismissesIt() throws {
        let rig = try AppRig()
        let state = WelcomeState(settings: rig.settings())
        #expect(state.shouldShow(loginStart: false))
        state.dismissed()   // OK and closing the window both call this
        #expect(!WelcomeState(settings: rig.settings()).shouldShow(loginStart: false))   // a second launch
    }

    @Test func aLoginStartDoesNotShowIt() throws {
        let rig = try AppRig()
        #expect(!WelcomeState(settings: rig.settings()).shouldShow(loginStart: true))
        #expect(!rig.settings().welcomeShown)   // and it is still due on a normal launch
    }
}

@MainActor
@Suite struct ShortcutTests {
    typealias M = Shortcut.Modifier

    @Test func rules() {
        #expect(Shortcut(keyCode: 37, modifiers: M.control | M.option | M.command).problem == nil)
        #expect(Shortcut(keyCode: 37, modifiers: M.control | M.option).problem == nil)
        #expect(Shortcut(keyCode: 37, modifiers: M.command | M.shift).problem == nil)
        #expect(Shortcut(keyCode: 37, modifiers: M.command).problem == "Use at least two of ⌃ ⌥ ⌘, or ⌘ with ⇧.")
        #expect(Shortcut(keyCode: 37, modifiers: M.option | M.shift).problem != nil)
        #expect(Shortcut(keyCode: 37, modifiers: 0).problem != nil)
        for key: UInt32 in [53, 36, 48, 49] {   // Escape, Return, Tab, Space
            #expect(Shortcut(keyCode: key, modifiers: M.control | M.option | M.command).problem == "Escape, Return, Tab and Space cannot be used. Choose another key.")
        }
    }

    @Test func displayStrings() {
        #expect(Shortcut(keyCode: 37, modifiers: M.control | M.option | M.command).displayString == "⌃⌥⌘L")
        #expect(Shortcut(keyCode: 18, modifiers: M.command | M.shift).displayString == "⇧⌘1")
        #expect(Shortcut(keyCode: 122, modifiers: M.control | M.option).displayString == "⌃⌥F1")
    }

    @Test func aShortcutIsStoredOnlyOnceClaimed() throws {
        let rig = try AppRig()
        let settings = rig.settings(), registrar = FakeRegistrar()
        let hotkey = HotkeySetting(settings: settings, registrar: registrar)
        let first = Shortcut(keyCode: 37, modifiers: M.control | M.option | M.command)
        let taken = Shortcut(keyCode: 40, modifiers: M.control | M.option | M.command)
        registrar.heldElsewhere = [taken]

        hotkey.record(first, for: .main)
        #expect(settings.hotkey == first && registrar.registered[.main] == first && hotkey.message(for: .main) == nil)
        hotkey.record(taken, for: .main)
        #expect(hotkey.message(for: .main) == "Another app is using this shortcut. Choose another.")
        #expect(settings.hotkey == first && registrar.registered[.main] == first)   // the previous one stays
        hotkey.record(Shortcut(keyCode: 37, modifiers: M.command), for: .main)
        #expect(hotkey.message(for: .main) == "Use at least two of ⌃ ⌥ ⌘, or ⌘ with ⇧." && settings.hotkey == first)
        hotkey.recording(true)   // the current one is let go while a new one is recorded
        #expect(registrar.registered[.main] == nil)
        hotkey.recording(false)
        #expect(registrar.registered[.main] == first)
        hotkey.clear(.main)
        #expect(settings.hotkey == nil && registrar.registered[.main] == nil)
    }

    @Test func theTwoHotkeysAreSeparateAndNeverTheSame() throws {
        let rig = try AppRig()
        let settings = rig.settings(), registrar = FakeRegistrar()
        let hotkey = HotkeySetting(settings: settings, registrar: registrar)
        let main = Shortcut(keyCode: 37, modifiers: M.control | M.option | M.command)
        let editor = Shortcut(keyCode: 14, modifiers: M.control | M.option | M.command)

        hotkey.record(main, for: .main)
        hotkey.record(main, for: .editor)
        #expect(hotkey.message(for: .editor) == "This shortcut opens the main window. Choose another.")
        #expect(settings.editorHotkey == nil && registrar.registered[.editor] == nil && registrar.registered[.main] == main)
        hotkey.record(editor, for: .editor)
        #expect(settings.editorHotkey == editor && registrar.registered[.editor] == editor && hotkey.message(for: .editor) == nil)
        hotkey.record(editor, for: .main)
        #expect(hotkey.message(for: .main) == "This shortcut opens Style and Preview. Choose another." && settings.hotkey == main)

        hotkey.recording(true)   // both are let go, so either key press reaches the recorder
        #expect(registrar.registered.isEmpty)
        hotkey.recording(true)    // the other recorder starts before the first one stops
        hotkey.recording(false)
        #expect(registrar.registered.isEmpty)   // still recording: nothing claimed
        hotkey.recording(false)
        #expect(registrar.registered[.main] == main && registrar.registered[.editor] == editor)
        hotkey.clear(.editor)
        #expect(settings.editorHotkey == nil && registrar.registered[.editor] == nil && registrar.registered[.main] == main)

        // As in Settings: recording starts, a key is pressed, recording ends; the key's sentence stays.
        hotkey.recording(true)
        hotkey.record(main, for: .editor)
        hotkey.recording(false)
        #expect(hotkey.message(for: .editor) == "This shortcut opens the main window. Choose another.")
        hotkey.recording(true)
        hotkey.record(Shortcut(keyCode: 14, modifiers: M.command), for: .main)
        hotkey.recording(false)
        #expect(hotkey.message(for: .main) == "Use at least two of ⌃ ⌥ ⌘, or ⌘ with ⇧." && registrar.registered[.main] == main)
        hotkey.recording(true)   // a recorder left recording when Settings closes
        hotkey.endRecording()
        #expect(registrar.registered[.main] == main && registrar.registered[.editor] == nil)

        let fresh = FakeRegistrar()
        settings.editorHotkey = editor
        HotkeySetting(settings: settings, registrar: fresh).registerStored()   // a launch claims both
        #expect(fresh.registered[.main] == main && fresh.registered[.editor] == editor)
    }

    @Test func thereIsAlwaysAWayToSettings() throws {
        let rig = try AppRig()
        let settings = rig.settings(), registrar = FakeRegistrar()
        let hotkey = HotkeySetting(settings: settings, registrar: registrar)
        let model = SettingsModel(settings: settings, labeler: rig.labeler, loginItem: FakeLoginItem(), hotkey: hotkey,
                                  machine: { AboutConfigurationTests.machine })
        let main = Shortcut(keyCode: 37, modifiers: M.control | M.option | M.command)

        model.setMenuBarMode(.hidden)   // no main hotkey: refused
        #expect(settings.menuBarMode == .iconAndText && model.message == SettingsModel.hideNeedsHotkey)
        hotkey.record(main, for: .main)
        model.setMenuBarMode(.hidden)
        #expect(settings.menuBarMode == .hidden && model.message == nil)
        hotkey.clear(.main)   // the way to Settings: kept while the item is hidden
        #expect(settings.hotkey == main && registrar.registered[.main] == main)
        #expect(hotkey.message(for: .main) == HotkeySetting.onlyWayToSettings)
        hotkey.clear(.editor)   // the editor's is free to go
        model.setMenuBarMode(.icon)
        hotkey.clear(.main)
        #expect(settings.hotkey == nil)

        // During a session: the main hotkey cannot be claimed again after recording while hidden: the item comes back.
        hotkey.record(main, for: .main)
        model.setMenuBarMode(.hidden)
        var forced = false
        hotkey.onMenuBarModeForced = { forced = true }
        hotkey.recording(true)
        #expect(hotkey.opensMainWindow)   // a release while recording does not count
        registrar.heldElsewhere = [main]
        hotkey.recording(false)
        #expect(forced && settings.menuBarMode == .iconAndText && !hotkey.opensMainWindow)
        #expect(hotkey.message(for: .main) == HotkeySetting.inUse)
    }

    @Test func aHiddenItemWithNoWorkingHotkeyIsShownAtLaunch() throws {
        let rig = try AppRig()
        let main = Shortcut(keyCode: 37, modifiers: M.control | M.option | M.command)
        let settings = rig.settings()
        settings.menuBarMode = .hidden   // written by hand, with no hotkey
        let launch = HotkeySetting(settings: settings, registrar: FakeRegistrar())
        launch.registerStored()
        #expect(launch.keepAWayToSettings() && settings.menuBarMode == .iconAndText)

        settings.hotkey = main
        settings.menuBarMode = .hidden
        let refusing = FakeRegistrar()
        refusing.heldElsewhere = [main]   // macOS refuses it at this launch
        let second = HotkeySetting(settings: settings, registrar: refusing)
        second.registerStored()
        #expect(second.keepAWayToSettings() && settings.menuBarMode == .iconAndText)

        settings.menuBarMode = .hidden
        let working = HotkeySetting(settings: settings, registrar: FakeRegistrar())
        working.registerStored()
        #expect(!working.keepAWayToSettings() && settings.menuBarMode == .hidden)
    }

    @Test func theNextDisplayIsLeftToRightAndWraps() {
        let left = CGRect(x: -2560, y: 0, width: 2560, height: 1440)
        let main = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let above = CGRect(x: 0, y: 1117, width: 1920, height: 1080)
        let frames = [main, left, above]
        #expect(ScreenOrder.next(after: 1, frames: frames) == 2)   // left → the higher of the two at x 0
        #expect(ScreenOrder.next(after: 2, frames: frames) == 0)
        #expect(ScreenOrder.next(after: 0, frames: frames) == 1)   // wraps
        #expect(ScreenOrder.next(after: 0, frames: [main]) == nil)   // one display: no move
        #expect(ScreenOrder.next(after: 5, frames: frames) == nil)
    }
}
