import AppKit
import DesktopNameApp
import DesktopNameCore

/// Which display the main window is about (spec 014, FR-011, FR-012, research R5).
@MainActor
enum ActiveDisplay {
    /// For the hotkey: the screen of the frontmost window, as macOS reports it to a background app (`NSScreen.main`),
    /// else the screen under the pointer. Spike S1 (T038) checks the first on two displays.
    static func forHotkey() -> NSScreen? {
        NSScreen.main ?? underPointer()
    }

    /// The screen after the one showing `display`, left to right and wrapping (FR-014), or nil when the window would
    /// not move: one display, or "Displays have separate Spaces" off (one Desktop spans them all).
    static func nextScreen(after display: Display) -> NSScreen? {
        guard NSScreen.screensHaveSeparateSpaces else { return nil }
        let screens = NSScreen.screens
        guard let current = screens.firstIndex(where: { SystemWallpaperSystem.display(for: $0).uuid == display.uuid }),
              let next = ScreenOrder.next(after: current, frames: screens.map(\.frame)) else { return nil }
        return screens[next]
    }

    /// True when both are the same physical screen.
    static func same(_ first: NSScreen?, _ second: NSScreen?) -> Bool {
        guard let first, let second else { return false }
        return number(of: first) != nil && number(of: first) == number(of: second)
    }

    private static func number(of screen: NSScreen) -> NSNumber? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    }

    static func underPointer() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    /// The core's display for `screen`, with the rule for "Displays have separate Spaces" off: then one Desktop spans
    /// every display, and the main display is used, as `dnm` does.
    static func display(for screen: NSScreen?, system: WallpaperSystem) -> Display? {
        let displays = (try? system.displays()) ?? []
        return MenuBarState.targetDisplay(chosen: screen.map(SystemWallpaperSystem.display(for:)), displays: displays,
                                          separateSpaces: NSScreen.screensHaveSeparateSpaces)
    }
}
