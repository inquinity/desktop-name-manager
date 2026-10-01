import Foundation

/// What the Desktop showed before its first label, so removing the label restores it exactly.
public struct Original: Codable, Equatable, Sendable {
    public var path: String
    /// Bookmark data, so a moved or renamed file still resolves.
    public var bookmark: Data?
    /// The system's image scaling mode, as reported.
    public var scaling: UInt
    public var clipping: Bool
    /// The fill color archived as an `NSColor`, so its color space round-trips exactly.
    public var fillColor: Data?

    public init(path: String, bookmark: Data?, scaling: UInt, clipping: Bool, fillColor: Data?) {
        self.path = path
        self.bookmark = bookmark
        self.scaling = scaling
        self.clipping = clipping
        self.fillColor = fillColor
    }
}

/// Why a stamp stopped being the active one.
public enum RetireReason: String, Codable, Sendable {
    case replaced, removed, undone
}

public enum StampState: Codable, Equatable, Sendable {
    case active
    case retired(at: Date, reason: RetireReason)
}

/// A reference to a state a display's wallpaper can be in.
public enum StateRef: Codable, Equatable, Sendable {
    case stamp(id: UUID)
    case original(Original)
}

/// One labeled copy of the original image; one is made per set operation.
public struct Stamp: Codable, Equatable, Sendable {
    public var id: UUID
    /// `<id>.dnm.<ext>`, the file in the store directory.
    public var fileName: String
    public var label: Label
    public var original: Original
    public var displayUUID: String
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var createdAt: Date
    public var state: StampState
    public var supersededBy: UUID?

    public init(id: UUID, fileName: String, label: Label, original: Original, displayUUID: String,
                pixelWidth: Int, pixelHeight: Int, createdAt: Date, state: StampState = .active, supersededBy: UUID? = nil) {
        self.id = id
        self.fileName = fileName
        self.label = label
        self.original = original
        self.displayUUID = displayUUID
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.createdAt = createdAt
        self.state = state
        self.supersededBy = supersededBy
    }

    public var isActive: Bool {
        if case .active = state { return true }
        return false
    }
}

public enum ChangeKind: String, Codable, Sendable {
    case set, replace, remove
}

/// The last change made on a display, kept so `undo` can reverse it.
public struct ChangeRecord: Codable, Equatable, Sendable {
    public var displayUUID: String
    public var kind: ChangeKind
    public var at: Date
    /// What the display's wallpaper became.
    public var produced: StateRef
    /// What it was before.
    public var before: StateRef

    public init(displayUUID: String, kind: ChangeKind, at: Date, produced: StateRef, before: StateRef) {
        self.displayUUID = displayUUID
        self.kind = kind
        self.at = at
        self.produced = produced
        self.before = before
    }
}

/// Everything the tool stores in `manifest.json`.
public struct Manifest: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var stamps: [Stamp]
    /// At most one record per display.
    public var changes: [ChangeRecord]

    public init(schemaVersion: Int = Manifest.currentSchemaVersion, stamps: [Stamp] = [], changes: [ChangeRecord] = []) {
        self.schemaVersion = schemaVersion
        self.stamps = stamps
        self.changes = changes
    }
}
