import AppKit
import Foundation

/// The label operations (set, remove, undo, list, show) over a wallpaper system and a store.
/// Everything the CLI does goes through here, and so will the app.
public final class DesktopLabeler {
    let system: WallpaperSystem
    let store: Store
    let time: TimeSource

    public init(system: WallpaperSystem, store: Store, time: TimeSource = SystemTimeSource()) {
        self.system = system
        self.store = store
        self.time = time
    }

    /// Every command starts here: delete stamps nobody needs (FR-018).
    func cleanUp() throws {
        try Cleanup.run(store: store, now: time.now)
    }

    /// The wallpaper placement used for a stamp. The image already matches the display exactly,
    /// so scale-to-fill is lossless whatever the original placement was (research R7).
    static func stampPlacement(fill: Data?) -> WallpaperPlacement {
        WallpaperPlacement(scaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue, clipping: true, fillColor: fill)
    }

    /// The stamp that `url` belongs to, if it is a file in our store named after a manifest entry.
    func stamp(for url: URL?, in manifest: Manifest) -> Stamp? {
        guard let url else { return nil }
        let parent = url.deletingLastPathComponent().resolvingSymlinksInPath().path
        guard parent == store.directory.resolvingSymlinksInPath().path else { return nil }
        return manifest.stamps.first { $0.fileName == url.lastPathComponent }
    }

    /// Resolves an original through its bookmark (which follows moves), falling back to its path.
    static func resolve(_ original: Original) throws -> URL {
        if let bookmark = original.bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale),
               FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        let url = URL(fileURLWithPath: original.path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DnmError.originalMissing(url.lastPathComponent)
        }
        return url
    }

    static func original(from current: CurrentWallpaper, url: URL) -> Original {
        Original(path: url.path, bookmark: try? url.bookmarkData(), scaling: current.placement.scaling,
                 clipping: current.placement.clipping, fillColor: current.placement.fillColor)
    }

    static func placement(of original: Original) -> WallpaperPlacement {
        WallpaperPlacement(scaling: original.scaling, clipping: original.clipping, fillColor: original.fillColor)
    }

    /// Sets a wallpaper, turning system errors into the tool's own.
    func apply(_ url: URL, placement: WallpaperPlacement, on display: Display) throws {
        do {
            try system.setWallpaper(url, placement: placement, on: display)
        } catch let error as DnmError {
            throw error
        } catch {
            throw DnmError.failure("Could not set the wallpaper: \(error.localizedDescription)")
        }
    }
}
