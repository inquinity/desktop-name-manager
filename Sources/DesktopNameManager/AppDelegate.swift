import AppKit
import DesktopNameApp
import DesktopNameCore
import SwiftUI

/// Wires the app's parts together (spec 014, T032): the single-instance check, the status item, the main window
/// and editor, the Settings and welcome windows, the hotkey and the login item. One store and one labeler, the same
/// operations as `dnm` (research R7).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let controller = LabelingController(labeler: DesktopLabeler(system: SystemWallpaperSystem(),
                                                                        store: Store(directory: Store.defaultDirectory())))
    private let registrar = HotkeyRegistrar()
    private let loginItem = MainAppLoginItem()
    private lazy var hotkey = HotkeySetting(settings: settings, registrar: registrar)
    private lazy var dock = DockPresence()
    private lazy var settingsWindow = SettingsWindowController(
        model: SettingsModel(settings: settings, labeler: controller.labeler, loginItem: loginItem, hotkey: hotkey,
                             machine: { Configuration.current() }),
        dock: dock)
    private lazy var presenter = PopoverPresenter(controller: controller, settings: settings,
                                                  openSettings: { [unowned self] pane in settingsWindow.show(pane) })
    private lazy var statusItem = StatusItemController(onClick: { [unowned self] button in presenter.toggle(from: button) })
    private var welcome: WelcomeWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // A second copy hands over to the first and quits (FR-017).
        if SingleInstance.handOverToRunningCopy() { exit(0) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        registrar.onPress = { [unowned self] kind in presenter.hotkey(kind, itemButton: statusItem.visibleButton) }
        hotkey.registerStored()
        hotkey.keepAWayToSettings()   // a hidden item needs a working main hotkey (FR-014a)
        statusItem.apply(settings.menuBarMode)
        settingsWindow.model.onMenuBarModeChange = { [unowned self] mode in statusItem.apply(mode) }
        hotkey.onMenuBarModeForced = { [unowned self] in statusItem.apply(settings.menuBarMode) }

        let state = WelcomeState(settings: settings)
        if state.shouldShow(loginStart: LoginStart.detected(loginItemEnabled: loginItem.isEnabled)) {
            let welcome = WelcomeWindowController(mode: settings.menuBarMode, dock: dock) { [unowned self] in
                state.dismissed()
                self.welcome = nil
            }
            self.welcome = welcome
            welcome.show()
        }
    }

    /// Opening the app again while it runs (from Finder, Spotlight or a second launch) opens Settings at General.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show(.general)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        for kind in HotkeyKind.allCases { registrar.unregister(kind) }
    }
}

/// Whether macOS opened the app at login. The welcome window never shows then (FR-017a).
enum LoginStart {
    static func detected(loginItemEnabled: Bool) -> Bool {
        // A login item launched by the system carries this property in its open event.
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchedAsLoginItem = event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        // Open at login is set in Settings, after the first launch; when it is on, the welcome was already seen.
        return launchedAsLoginItem || loginItemEnabled
    }
}

/// The Dock icon shows while the welcome or Settings window is open (contracts/app-ui.md), and only then.
@MainActor
final class DockPresence {
    private var openWindows = 0

    func windowOpened() {
        openWindows += 1
        NSApp.setActivationPolicy(.regular)
    }

    func windowClosed() {
        openWindows = max(0, openWindows - 1)
        if openWindows == 0 { NSApp.setActivationPolicy(.accessory) }
    }
}
