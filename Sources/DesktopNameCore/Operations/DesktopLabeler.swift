import AppKit
import Foundation

/// The label operations (set, remove, undo, list, show) over a wallpaper system and a store.
/// Everything the CLI does goes through here, and so will the app.
public final class DesktopLabeler {
    let system: WallpaperSystem
    let store: Store
    let time: TimeSource
    /// How long to wait for macOS to report a wallpaper it was just told to show.
    let settleTimeout: TimeInterval
    /// Optional, read-only view of where macOS references a stamp (known issue KI-1).
    let inspector: WallpaperStoreInspector?

    public init(system: WallpaperSystem, store: Store, time: TimeSource = SystemTimeSource(), settleTimeout: TimeInterval = 3,
                inspector: WallpaperStoreInspector? = WallpaperStoreReader()) {
        self.system = system
        self.store = store
        self.time = time
        self.settleTimeout = settleTimeout
        self.inspector = inspector
    }

    /// Every command starts here: delete stamps nobody needs (FR-018).
    public func cleanUp() throws {
        try Cleanup.run(store: store, now: time.now, inspector: inspector)
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
        try waitUntilShowing(url, on: display)
    }

    /// macOS reports a new wallpaper a moment after `setDesktopImageURL` returns. A command run straight
    /// afterwards (a script, or `set` then `remove`) would read the old one and mistake our label for
    /// someone else's wallpaper. Wait, briefly, until the system reports the file we just set. If it never
    /// does within the timeout, carry on: the set itself succeeded.
    private func waitUntilShowing(_ url: URL, on display: Display) throws {
        let deadline = Date().addingTimeInterval(settleTimeout)
        while Date() < deadline {
            if let shown = try system.currentWallpaper(on: display).url, Self.isSameFile(shown, url) { return }
            // Keep the run loop turning so AppKit can deliver the system's update.
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    static func isSameFile(_ a: URL, _ b: URL) -> Bool {
        a.resolvingSymlinksInPath().path == b.resolvingSymlinksInPath().path
    }
}
