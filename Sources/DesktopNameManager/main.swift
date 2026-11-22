import AppKit

// Desktop Name Manager, the menu-bar app (spec 014). An accessory app (LSUIElement): no Dock icon, except while the
// welcome or Settings window is open. Everything is wired in AppDelegate.

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
