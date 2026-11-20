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
        #expect(settings.hotkey == nil)
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

        hotkey.record(first)
        #expect(settings.hotkey == first && registrar.registered == first && hotkey.message == nil)
        hotkey.record(taken)
        #expect(hotkey.message == "Another app is using this shortcut. Choose another.")
        #expect(settings.hotkey == first && registrar.registered == first)   // the previous one stays
        hotkey.record(Shortcut(keyCode: 37, modifiers: M.command))
        #expect(hotkey.message == "Use at least two of ⌃ ⌥ ⌘, or ⌘ with ⇧." && settings.hotkey == first)
        hotkey.recording(true)   // the current one is let go while a new one is recorded
        #expect(registrar.registered == nil)
        hotkey.recording(false)
        #expect(registrar.registered == first)
        hotkey.clear()
        #expect(settings.hotkey == nil && registrar.registered == nil)
    }
}
