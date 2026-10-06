import Foundation
@testable import DesktopNameCore

/// An in-memory wallpaper system for tests.
final class FakeWallpaperSystem: WallpaperSystem {
    struct SetCall: Equatable {
        var url: URL
        var placement: WallpaperPlacement
        var displayUUID: String
    }

    var connectedDisplays: [Display]
    var current: [String: CurrentWallpaper] = [:]
    private(set) var setCalls: [SetCall] = []
    /// When set, `setWallpaper` throws this error and changes nothing.
    var setError: Error?
    /// Called just before a wallpaper is set, to test ordering.
    var beforeSet: (() -> Void)?
    /// Like the real system, report a newly set wallpaper only after this many reads (0 = at once).
    var readsBeforeSetShows = 0
    private var pending: [String: (wallpaper: CurrentWallpaper, readsLeft: Int)] = [:]

    static let defaultPlacement = WallpaperPlacement(scaling: 3, clipping: true, fillColor: nil)

    init(displays: [Display] = [FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "DISPLAY-A", isMain: true)]) {
        connectedDisplays = displays
    }

    static func makeDisplay(name: String, uuid: String, isMain: Bool, width: Double = 1440, height: Double = 900, scale: Double = 2) -> Display {
        Display(name: name, uuid: uuid, isMain: isMain,
                geometry: DisplayGeometry(pointWidth: width, pointHeight: height, scale: scale, insetTop: 30, insetBottom: 60))
    }

    func show(_ url: URL?, placement: WallpaperPlacement = FakeWallpaperSystem.defaultPlacement, on display: Display) {
        current[display.uuid] = CurrentWallpaper(url: url, placement: placement)
    }

    func displays() throws -> [Display] { connectedDisplays }

    func currentWallpaper(on display: Display) throws -> CurrentWallpaper {
        if var waiting = pending[display.uuid] {
            if waiting.readsLeft <= 0 {
                current[display.uuid] = waiting.wallpaper
                pending[display.uuid] = nil
            } else {
                waiting.readsLeft -= 1
                pending[display.uuid] = waiting
            }
        }
        return current[display.uuid] ?? CurrentWallpaper(url: nil, placement: Self.defaultPlacement)
    }

    func setWallpaper(_ url: URL, placement: WallpaperPlacement, on display: Display) throws {
        beforeSet?()
        if let setError { throw setError }
        setCalls.append(SetCall(url: url, placement: placement, displayUUID: display.uuid))
        let shown = CurrentWallpaper(url: url, placement: placement)
        if readsBeforeSetShows > 0 {
            pending[display.uuid] = (shown, readsBeforeSetShows)
        } else {
            current[display.uuid] = shown
        }
    }
}
