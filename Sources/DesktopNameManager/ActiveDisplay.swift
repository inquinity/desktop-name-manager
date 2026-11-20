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
