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
    /// The display's name when the stamp was made, for listing labels on displays that are not connected.
    public var displayName: String
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var createdAt: Date
    public var state: StampState
    public var supersededBy: UUID?
    /// SHA-256 (hex) of what this image was made from (spec 009 data model); nil for labels made before it existed,
    /// which are never reused.
    public var reuseKey: String?
    /// The last time this label's image was the wallpaper of a display's current Desktop that something looked at
    /// (set at creation). nil for labels made before it existed: their age counts from `createdAt`.
    public var lastSeen: Date?

    public init(id: UUID, fileName: String, label: Label, original: Original, displayUUID: String, displayName: String = "",
                pixelWidth: Int, pixelHeight: Int, createdAt: Date, state: StampState = .active, supersededBy: UUID? = nil,
                reuseKey: String? = nil, lastSeen: Date? = nil) {
        self.id = id
        self.fileName = fileName
        self.label = label
        self.original = original
        self.displayUUID = displayUUID
        self.displayName = displayName
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.createdAt = createdAt
        self.state = state
        self.supersededBy = supersededBy
        self.reuseKey = reuseKey
        self.lastSeen = lastSeen
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

/// When the cleanup nudge was last shown (spec 009), so it is not shown again at once.
public struct Maintenance: Codable, Equatable, Sendable {
    public var nudgedAt: Date?
    public var nudgedBytes: Int64?

    public init(nudgedAt: Date? = nil, nudgedBytes: Int64? = nil) {
        self.nudgedAt = nudgedAt
        self.nudgedBytes = nudgedBytes
    }
}

/// Everything the tool stores in `manifest.json`.
///
/// Version 2 added `aliases` (spec 006); version 3 added `maintenance` and each label's `reuseKey` and `lastSeen`
/// (spec 009). This build reads versions 1 to 3 and writes 3; older builds refuse a newer version, an accepted risk
/// at 0.x.
public struct Manifest: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 3

    public var schemaVersion: Int
    public var stamps: [Stamp]
    /// At most one record per display.
    public var changes: [ChangeRecord]
    /// Unique by lowercased name.
    public var aliases: [DisplayAlias]
    /// nil until the first nudge; cleared by a cleanup.
    public var maintenance: Maintenance?

    public init(schemaVersion: Int = Manifest.currentSchemaVersion, stamps: [Stamp] = [], changes: [ChangeRecord] = [],
                aliases: [DisplayAlias] = [], maintenance: Maintenance? = nil) {
        self.schemaVersion = schemaVersion
        self.stamps = stamps
        self.changes = changes
        self.aliases = aliases
        self.maintenance = maintenance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        stamps = try container.decode([Stamp].self, forKey: .stamps)
        changes = try container.decode([ChangeRecord].self, forKey: .changes)
        aliases = try container.decodeIfPresent([DisplayAlias].self, forKey: .aliases) ?? []
        maintenance = try container.decodeIfPresent(Maintenance.self, forKey: .maintenance)
    }
}
