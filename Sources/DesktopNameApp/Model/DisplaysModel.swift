import DesktopNameCore
import Foundation
import Observation

/// The Displays pane (spec 014, contracts/app-ui.md §Settings window): each display with its aliases, added and
/// removed through the core's alias operations, so the rules and sentences are `dnm alias`'s. No confirmation:
/// removing an alias is undone by adding it again.
@MainActor
@Observable
public final class DisplaysModel {
    public struct Row: Identifiable, Equatable, Sendable {
        public var display: Display
        public var aliases: [String]
        /// The row's place: two displays can report the same identity, so the identity cannot be the row's ID.
        public var id: Int
    }

    public private(set) var rows: [Row] = []
    /// One line under a row, after adding or removing there: a refusal (red) or a move ("… moved here from …").
    public private(set) var note: (displayUUID: String, text: String, isError: Bool)?

    @ObservationIgnored private let labeler: DesktopLabeler

    public init(labeler: DesktopLabeler) {
        self.labeler = labeler
    }

    /// Reads the displays and aliases again (when the pane opens, and after each change).
    public func refresh() {
        do {
            let displays = try labeler.system.displays().sorted { $0.isMain && !$1.isMain }
            let aliases = try labeler.aliases()
            rows = displays.enumerated().map { index, display in
                Row(display: display, aliases: aliases.filter { $0.displayUUID == display.uuid }.map(\.name)
                    .sorted { $0.lowercased() < $1.lowercased() }, id: index)
            }
            if note?.displayUUID.isEmpty == true { note = nil }   // a reading problem that is gone
        } catch {
            rows = []
            note = ("", MessageWording.sentence(for: error), true)
        }
    }

    /// Adds `name` to `display`. An alias already on another display moves here, and the row says so.
    public func add(_ name: String, to display: Display) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            let result = try labeler.setAlias(trimmed, on: display)
            if case .moved(let from) = result.change {
                note = (display.uuid, "\(result.name) moved here from \(from).", false)
            } else {
                note = nil
            }
        } catch {
            note = (display.uuid, MessageWording.sentence(for: error), true)
        }
        refresh()
    }

    public func remove(_ name: String, from display: Display) {
        do {
            try labeler.removeAlias(named: name)
            note = nil
        } catch {
            note = (display.uuid, MessageWording.sentence(for: error), true)
        }
        refresh()
    }
}

/// One label in use, as the Labels pane lists it: the labeled Desktops `dnm list` reports, with their display and the
/// size of their image.
public struct LabelInUse: Identifiable, Equatable, Sendable {
    public var label: String
    public var displayName: String
    public var connected: Bool
    public var bytes: Int64
    /// The place in the list: two Desktops can carry the same label on the same display.
    public var id: Int

    /// Reads the list (when the Labels pane opens).
    @MainActor
    public static func read(_ labeler: DesktopLabeler) throws -> [LabelInUse] {
        let manifest = try labeler.store.readManifest()
        return try labeler.listDesktops().entries.filter { $0.label != nil }.enumerated().map { index, entry in
            let label = entry.label ?? ""
            let stamp = manifest.stamps.first {
                $0.label.text.value == label && ($0.displayName == entry.displayName || $0.displayName.isEmpty) && $0.isActive
            }
            return LabelInUse(label: label, displayName: entry.displayName, connected: entry.connected,
                              bytes: stamp.map { StorageSummary.fileSize(labeler.store, $0.fileName) } ?? 0, id: index)
        }
    }
}
