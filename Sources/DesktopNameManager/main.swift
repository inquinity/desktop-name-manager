import AppKit
import DesktopNameApp

// The menu-bar app (spec 014). Phase 3 placeholder: an accessory app with an empty menu-bar item, so the bundle
// can be assembled and launched; the main window and the rest arrive in later tasks.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = AppInfo.menuBarText
        item.button?.setAccessibilityLabel(AppInfo.displayName)
        statusItem = item
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
