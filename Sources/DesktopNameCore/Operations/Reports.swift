import Foundation

/// The JSON documents printed by `list`, `show` and `displays` (contracts/cli.md, FR-025).
/// They never include display UUIDs or file paths.
public enum Reports {
    public struct Display: Codable, Equatable, Sendable {
        public var name: String
        public var isMain: Bool
    }

    /// A display as `displays` lists it: with the aliases in use for it, sorted; empty when it has none.
    public struct ListedDisplay: Codable, Equatable, Sendable {
        public var name: String
        public var isMain: Bool
        public var aliases: [String]
    }

    public struct Desktop: Codable, Equatable, Sendable {
        public var display: String
        public var connected: Bool
        public var current: Bool
        public var label: String?
        public var stampMissing: Bool

        public init(display: String, connected: Bool, current: Bool, label: String?, stampMissing: Bool) {
            self.display = display; self.connected = connected; self.current = current; self.label = label; self.stampMissing = stampMissing
        }

        enum CodingKeys: String, CodingKey { case display, connected, current, label, stampMissing }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(display, forKey: .display)
            try container.encode(connected, forKey: .connected)
            try container.encode(current, forKey: .current)
            try container.encode(label, forKey: .label)   // an explicit null when there is no label
            try container.encode(stampMissing, forKey: .stampMissing)
        }
    }

    public struct List: Codable, Equatable, Sendable {
        public var scope: String
        public var desktops: [Desktop]
    }

    public struct LabelDetails: Codable, Equatable, Sendable {
        public var text: String
        public var look: String
        public var textColor: String
        public var position: String
        public var size: String
        public var automatic: [String]
    }

    public struct Show: Codable, Equatable, Sendable {
        public var display: Display
        public var labeled: Bool
        public var label: LabelDetails?
        public var createdAt: Date?
        public var originalRecorded: Bool
        public var stampMissing: Bool

        enum CodingKeys: String, CodingKey { case display, labeled, label, createdAt, originalRecorded, stampMissing }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(display, forKey: .display)
            try container.encode(labeled, forKey: .labeled)
            try container.encode(label, forKey: .label)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(originalRecorded, forKey: .originalRecorded)
            try container.encode(stampMissing, forKey: .stampMissing)
        }
    }

    public struct Displays: Codable, Equatable, Sendable {
        public var displays: [ListedDisplay]
    }

    public struct CleanupEntry: Codable, Equatable, Sendable {
        public var label: String
        public var display: String
        /// `removed`, `replaced`, `undone`, `not seen` or `not on any Desktop`.
        public var why: String
        public var since: Date
        public var bytes: Int64
    }

    public struct NotChecked: Codable, Equatable, Sendable {
        public var display: String
        public var labels: Int
    }

    /// The `cleanup` document (spec 009), with `mode` (`age` or `scan`) and, for a scan, its fields (spec 012 §6).
    public struct Cleanup: Codable, Equatable, Sendable {
        public var mode: String
        /// nil for a scan, printed as an explicit null.
        public var days: Int?
        public var candidates: [CleanupEntry]
        public var totalBytes: Int64
        public var deleted: Bool
        public var scanned: [String]?
        public var notChecked: [NotChecked]?
        public var wouldScan: [String]?

        enum CodingKeys: String, CodingKey { case mode, days, candidates, totalBytes, deleted, scanned, notChecked, wouldScan }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(mode, forKey: .mode)
            try container.encode(days, forKey: .days)
            try container.encode(candidates, forKey: .candidates)
            try container.encode(totalBytes, forKey: .totalBytes)
            try container.encode(deleted, forKey: .deleted)
            try container.encodeIfPresent(scanned, forKey: .scanned)
            try container.encodeIfPresent(notChecked, forKey: .notChecked)
            try container.encodeIfPresent(wouldScan, forKey: .wouldScan)
        }
    }

    // MARK: - Builders

    public static func list(_ listing: DesktopListing) -> List {
        List(scope: listing.scope, desktops: listing.entries.map {
            Desktop(display: $0.displayName, connected: $0.connected, current: $0.current, label: $0.label, stampMissing: $0.stampMissing)
        })
    }

    public static func show(_ result: ShowLabelResult) -> Show {
        Show(display: Display(name: result.displayName, isMain: result.isMain), labeled: result.labeled,
             label: result.label.map {
                 LabelDetails(text: $0.text.value, look: $0.look.rawValue, textColor: $0.textColor.description, position: $0.position.rawValue,
                              size: $0.size.rawValue, automatic: $0.automatic.map(\.rawValue).sorted())
             },
             createdAt: result.createdAt, originalRecorded: result.originalRecorded, stampMissing: result.stampMissing)
    }

    public static func displays(_ displays: [DesktopNameCore.Display], aliases: [DisplayAlias] = []) -> Displays {
        Displays(displays: displays.map {
            ListedDisplay(name: $0.name, isMain: $0.isMain, aliases: DisplayResolver.activeAliases(of: $0, in: aliases, displays: displays))
        })
    }

    public struct Aliases: Codable, Equatable, Sendable {
        public var aliases: [AliasEntry]
    }

    public static func aliases(_ entries: [AliasEntry]) -> Aliases { Aliases(aliases: entries) }

    public static func cleanup(_ plan: CleanupPlan, deleted: Bool) -> Cleanup {
        Cleanup(mode: "age", days: plan.days, candidates: entries(plan), totalBytes: plan.totalBytes, deleted: deleted)
    }

    /// A scan's document: what it found and did, or (without `--yes`) what it would visit.
    public static func scan(_ plan: CleanupPlan, scanned: [String], notConnected: [NotConnectedDisplay], deleted: Bool, wouldScan: [String]? = nil) -> Cleanup {
        Cleanup(mode: "scan", days: nil, candidates: entries(plan), totalBytes: plan.totalBytes, deleted: deleted, scanned: scanned,
                notChecked: notConnected.map { NotChecked(display: $0.name, labels: $0.labels) }, wouldScan: wouldScan)
    }

    static func entries(_ plan: CleanupPlan) -> [CleanupEntry] {
        plan.candidates.map { CleanupEntry(label: $0.label, display: $0.displayName, why: $0.reason.rawValue, since: $0.since, bytes: $0.bytes) }
    }

    /// One JSON document, sorted keys, ISO 8601 dates.
    public static func json<Value: Encodable>(_ value: Value) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}

extension TextColor: CustomStringConvertible {
    public var description: String {
        switch self {
        case .light: "light"
        case .dark: "dark"
        case .custom(let red, let green, let blue):
            String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
        }
    }
}
