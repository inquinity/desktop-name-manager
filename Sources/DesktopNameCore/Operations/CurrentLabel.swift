import Foundation

extension DesktopLabeler {
    /// The label of the Desktop on screen of `display`, if its wallpaper is one of this store's stamps; nil for any
    /// other wallpaper, including a stamp from another store (spec 014, contracts/core-additions.md §2).
    ///
    /// Reads only: no housekeeping and no lock. A torn read cannot happen, since the manifest is replaced atomically.
    /// Throws for a manifest written by a newer version, as every reader does.
    public func currentLabel(on display: Display) throws -> Label? {
        try currentStamp(on: display)?.label
    }

    /// The stamp showing on `display`, by the one rule `dnm show` and the app share.
    func currentStamp(on display: Display) throws -> Stamp? {
        let current = try system.currentWallpaper(on: display)
        return stamp(for: current.url, in: try store.readManifest())
    }
}
