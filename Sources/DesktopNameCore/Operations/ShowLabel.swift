import Foundation

public struct ShowLabelResult: Equatable, Sendable {
    public var displayName: String
    public var isMain: Bool
    public var label: Label?
    public var createdAt: Date?
    public var originalRecorded: Bool
    /// The stamp file is gone; `set` rebuilds it from the recorded original (spec edge case).
    public var stampMissing: Bool

    public var labeled: Bool { label != nil }
}

extension DesktopLabeler {
    /// The details of the label on the current Desktop of `display` (FR-012).
    public func showLabel(on display: Display) throws -> ShowLabelResult {
        try cleanUp()
        let current = try system.currentWallpaper(on: display)
        let manifest = try store.readManifest()
        guard let stamp = stamp(for: current.url, in: manifest) else {
            return ShowLabelResult(displayName: display.name, isMain: display.isMain, label: nil, createdAt: nil,
                                   originalRecorded: false, stampMissing: false)
        }
        return ShowLabelResult(displayName: display.name, isMain: display.isMain, label: stamp.label, createdAt: stamp.createdAt,
                               originalRecorded: true, stampMissing: !store.stampFileExists(named: stamp.fileName))
    }
}
