import AppKit
import CoreGraphics
import Foundation

/// The real wallpaper system over `NSWorkspace`, `NSScreen` and CoreGraphics. Public APIs only.
/// Must be used on the main thread, as AppKit requires.
public struct SystemWallpaperSystem: WallpaperSystem {
    public init() {}

    public func displays() throws -> [Display] {
        MainActor.assumeIsolated {
            let mainID = CGMainDisplayID()
            return NSScreen.screens.map { Self.display(for: $0, mainID: mainID) }
        }
    }

    public func currentWallpaper(on display: Display) throws -> CurrentWallpaper {
        try MainActor.assumeIsolated {
            let screen = try Self.screen(for: display)
            let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
            let scaling = (options[.imageScaling] as? NSNumber)?.uintValue ?? NSImageScaling.scaleProportionallyUpOrDown.rawValue
            let clipping = (options[.allowClipping] as? NSNumber)?.boolValue ?? true
            let fill = (options[.fillColor] as? NSColor).flatMap {
                try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
            }
            return CurrentWallpaper(url: NSWorkspace.shared.desktopImageURL(for: screen),
                                    placement: WallpaperPlacement(scaling: scaling, clipping: clipping, fillColor: fill))
        }
    }

    public func setWallpaper(_ url: URL, placement: WallpaperPlacement, on display: Display) throws {
        try MainActor.assumeIsolated {
            let screen = try Self.screen(for: display)
            var options: [NSWorkspace.DesktopImageOptionKey: Any] = [
                .imageScaling: NSNumber(value: placement.scaling),
                .allowClipping: NSNumber(value: placement.clipping),
            ]
            if let data = placement.fillColor,
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                options[.fillColor] = color
            }
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
        }
    }

    // MARK: - Helpers (main actor)

    @MainActor
    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    @MainActor
    private static func uuid(of id: CGDirectDisplayID) -> String {
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return "" }
        return CFUUIDCreateString(nil, cfUUID) as String
    }

    @MainActor
    private static func display(for screen: NSScreen, mainID: CGDirectDisplayID) -> Display {
        let id = displayID(of: screen)
        let frame = screen.frame, visible = screen.visibleFrame
        let modePixelWidth = CGDisplayCopyDisplayMode(id)?.pixelWidth ?? 0
        let scale = modePixelWidth > 0 ? Double(modePixelWidth) / Double(frame.width) : Double(screen.backingScaleFactor)
        let geometry = DisplayGeometry(
            pointWidth: Double(frame.width), pointHeight: Double(frame.height), scale: scale,
            insetTop: Double(frame.maxY - visible.maxY), insetLeft: Double(visible.minX - frame.minX),
            insetBottom: Double(visible.minY - frame.minY), insetRight: Double(frame.maxX - visible.maxX))
        return Display(name: screen.localizedName, uuid: uuid(of: id), isMain: id == mainID, geometry: geometry)
    }

    @MainActor
    private static func screen(for display: Display) throws -> NSScreen {
        guard let screen = NSScreen.screens.first(where: { uuid(of: displayID(of: $0)) == display.uuid }) else {
            throw DnmError.failure("The display \"\(display.name)\" is no longer connected.")
        }
        return screen
    }
}
