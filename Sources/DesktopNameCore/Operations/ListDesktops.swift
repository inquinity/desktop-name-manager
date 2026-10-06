import Foundation

public struct DesktopEntry: Equatable, Sendable {
    public var displayName: String
    public var connected: Bool
    /// True for the Desktop currently shown on a connected display.
    public var current: Bool
    public var label: String?
    /// The stamp file for a labeled Desktop has been deleted; `set` rebuilds it.
    public var stampMissing: Bool
}

public struct DesktopListing: Equatable, Sendable {
    /// Always present, so a reader never mistakes the list for every Desktop (FR-011).
    public static let scopeNote = "Only labeled and current Desktops are shown."

    public var scope: String { Self.scopeNote }
    public var entries: [DesktopEntry]
}

extension DesktopLabeler {
    /// Labeled Desktops plus the current Desktop of each connected display (FR-011).
    /// Desktops that are neither labeled nor current cannot be seen with public interfaces.
    public func listDesktops() throws -> DesktopListing {
        try cleanUp()
        let displays = try system.displays()
        let manifest = try store.readManifest()
        var entries: [DesktopEntry] = []
        var shown: Set<UUID> = []

        // Connected displays, main first, each with its current Desktop first.
        for display in displays.sorted(by: { $0.isMain && !$1.isMain }) {
            let current = try system.currentWallpaper(on: display)
            if let stamp = stamp(for: current.url, in: manifest) {
                shown.insert(stamp.id)
                entries.append(DesktopEntry(displayName: display.name, connected: true, current: true, label: stamp.label.text.value,
                                            stampMissing: !store.stampFileExists(named: stamp.fileName)))
            } else {
                entries.append(DesktopEntry(displayName: display.name, connected: true, current: true, label: nil, stampMissing: false))
            }
            for stamp in manifest.stamps where stamp.isActive && stamp.displayUUID == display.uuid && !shown.contains(stamp.id) {
                shown.insert(stamp.id)
                entries.append(DesktopEntry(displayName: display.name, connected: true, current: false, label: stamp.label.text.value,
                                            stampMissing: !store.stampFileExists(named: stamp.fileName)))
            }
        }
        // Labeled Desktops on displays that are not connected.
        for stamp in manifest.stamps where stamp.isActive && !shown.contains(stamp.id) {
            entries.append(DesktopEntry(displayName: stamp.displayName.isEmpty ? "Unknown display" : stamp.displayName, connected: false,
                                        current: false, label: stamp.label.text.value,
                                        stampMissing: !store.stampFileExists(named: stamp.fileName)))
        }
        return DesktopListing(entries: entries)
    }
}
