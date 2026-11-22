import AppKit
import DesktopNameApp
import SwiftUI

/// The Settings window (spec 014, T049): one window with the sidebar; the main window's items and a second launch
/// open it at a pane. The Dock icon shows while it is open.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    let model: SettingsModel
    private let dock: DockPresence
    private var window: NSWindow?

    init(model: SettingsModel, dock: DockPresence) {
        self.model = model
        self.dock = dock
    }

    func show(_ pane: SettingsPane) {
        model.show(pane)
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsWindowView(model: model)))
            window.title = "\(AppInfo.displayName) Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.toolbarStyle = .unified
            window.setContentSize(NSSize(width: 720, height: 500))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
            dock.windowOpened()
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        dock.windowClosed()
        model.hotkey.endRecording()   // a recorder left recording must not keep the hotkeys let go
    }
}

/// The welcome window (spec 014, T035, FR-017a): shown once; OK and closing it both dismiss it.
@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    private let dock: DockPresence
    private let onDismiss: () -> Void
    private var window: NSWindow?

    init(mode: MenuBarMode, dock: DockPresence, onDismiss: @escaping () -> Void) {
        self.dock = dock
        self.onDismiss = onDismiss
        super.init()
        let window = NSWindow(contentViewController: NSHostingController(rootView: WelcomeView(menuBarMode: mode) { [weak self] in
            self?.window?.close()
        }))
        window.title = "Welcome"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
    }

    func show() {
        dock.windowOpened()
        window?.center()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        dock.windowClosed()
        onDismiss()
    }
}
