import Foundation

/// A display that has labels in the store but is not connected: the scan cannot see its Desktops (known issue KI-2),
/// so its labels are left alone and named (spec 012 FR-004).
public struct NotConnectedDisplay: Equatable, Sendable {
    public var name: String
    public var labels: Int
}

/// What a scan would visit, known before anything switches.
public struct ScanPreview: Equatable, Sendable {
    /// The connected displays, in the order they are visited.
    public var displays: [Display]
    public var notConnected: [NotConnectedDisplay]
    /// Whether any label of a connected display is stored; without one there is nothing to look for.
    public var hasLabelsToCheck: Bool
}

/// What a scan saw (spec 012 data model).
public struct ScanResult: Equatable, Sendable {
    public struct Scanned: Equatable, Sendable {
        public var name: String
        var uuid: String
        /// The image file names shown by this display's Desktops.
        var seen: Set<String>
    }

    /// The connected displays walked, in order.
    public var scanned: [Scanned]
    public var notConnected: [NotConnectedDisplay]
    /// Whether "Displays have separate Spaces" was on (one walk per display) or off (one walk for all).
    public var separateSpaces: Bool
    /// Displays where no step moved, counted as having one Desktop because steps moved elsewhere (spec 012 FR-017).
    /// Shown in the report, so a wrong guess can be seen before deleting.
    public var oneDesktop: [String] = []
    /// Every image file name some Desktop showed: what "shown by some Desktop" means.
    public var seen: Set<String> { scanned.reduce(into: Set<String>()) { $0.formUnion($1.seen) } }
}

extension DesktopLabeler {
    /// Pauses between two reads of a Desktop's wallpaper, and how many reads at most (about 1.5 s, the step timeout).
    static let stableReadPause: TimeInterval = 0.1
    static let stableReadLimit = 15
    /// Consecutive reads that must agree before a Desktop's wallpaper is taken as read.
    static let stableReadsNeeded = 3

    /// The displays a scan would visit and what it cannot check. Reads only.
    public func scanPreview() throws -> ScanPreview {
        let displays = try system.displays()
        let stamps = store.hasManifest ? try store.readManifest().stamps : []
        let connected = Set(displays.map(\.uuid))
        return ScanPreview(displays: displays, notConnected: Self.notConnected(stamps, connected: connected),
                           hasLabelsToCheck: stamps.contains { connected.contains($0.displayUUID) })
    }

    /// Labels of displays that are not connected, by display, in the order first stored.
    static func notConnected(_ stamps: [Stamp], connected: Set<String>) -> [NotConnectedDisplay] {
        var order: [String] = []
        var groups: [String: NotConnectedDisplay] = [:]
        for stamp in stamps where !connected.contains(stamp.displayUUID) {
            let name = stamp.displayName.isEmpty ? "Unknown display" : stamp.displayName
            if groups[stamp.displayUUID] == nil { order.append(stamp.displayUUID) }
            groups[stamp.displayUUID, default: NotConnectedDisplay(name: name, labels: 0)].labels += 1
            groups[stamp.displayUUID]?.name = name   // the most recent name
        }
        return order.compactMap { groups[$0] }
    }

    /// Visits every Desktop of every connected display and notes the image each shows (spec 012 FR-003). With
    /// separate Spaces, each display is walked in turn and only it is read; without, one walk on the main display
    /// reads every display at each stop (research R3). `progress` is called as each walk starts, with the displays
    /// it covers. Writes nothing: what was seen is recorded by `carryOut` or `recordSeen`.
    ///
    /// Any failure throws with nothing written; displays already walked are back where they started and are named.
    @MainActor
    public func scan(switcher: DesktopSwitching, separateSpaces: Bool, isInterrupted: () -> Bool = { false },
                     progress: ([Display]) -> Void = { _ in }) throws -> ScanResult {
        guard switcher.isTrusted else { throw DesktopNavigator.permissionMissing(for: "cleanup --scan", to: "scan Desktops") }
        let preview = try scanPreview()
        let displays = preview.displays
        let navigator = DesktopNavigator(switcher: switcher)
        let walks: [(walked: Display, reads: [Display])] = separateSpaces
            ? displays.map { ($0, [$0]) }
            : (displays.first { $0.isMain } ?? displays.first).map { [($0, displays)] } ?? []

        var seen: [String: Set<String>] = [:]
        var finished: [String] = []
        var anyStepConfirmed = false
        var nothingMovedOn: Display?
        var oneDesktop: [String] = []
        for walk in walks {
            progress(walk.reads)
            do {
                let outcome = try navigator.walk(on: walk.walked, isInterrupted: isInterrupted) {
                    for display in walk.reads {
                        if let name = try stableRead(display, walking: walk.walked, switcher: switcher) { seen[display.uuid, default: []].insert(name) }
                    }
                }
                switch outcome {
                case .walked: anyStepConfirmed = true
                case .nothingMoved:
                    nothingMovedOn = nothingMovedOn ?? walk.walked
                    oneDesktop.append(walk.walked.name)
                }
            } catch DnmError.interrupted {
                throw DnmError.interrupted(scanned: finished)
            } catch where !finished.isEmpty {
                throw DnmError.failure("\((error as? LocalizedError)?.errorDescription ?? "\(error)") Scanned and returned: \(finished.joined(separator: ", ")).")
            }
            finished += walk.reads.map(\.name)
        }
        // A Ctrl-C during the last walk's final step or its way back is seen here, so it still deletes nothing.
        if isInterrupted() { throw DnmError.interrupted(scanned: finished) }
        // A display connected or disconnected meanwhile makes the result incomplete: stop rather than guess.
        guard try system.displays().map(\.uuid).sorted() == displays.map(\.uuid).sorted() else {
            throw DnmError.failure("A display was connected or disconnected during the scan, so its Desktops were not all seen. Nothing was deleted; run the scan again.")
        }
        // A display where nothing moved has one Desktop only if the shortcuts work, which a confirmed step anywhere
        // in this run shows; otherwise its one read may have missed Desktops in use (spec 012 FR-017).
        if let display = nothingMovedOn, !anyStepConfirmed { throw Self.nothingMovedScanning(display) }

        return ScanResult(scanned: displays.map { ScanResult.Scanned(name: $0.name, uuid: $0.uuid, seen: seen[$0.uuid] ?? []) },
                          notConnected: preview.notConnected, separateSpaces: separateSpaces, oneDesktop: oneDesktop)
    }

    static func nothingMovedScanning(_ display: Display) -> DnmError {
        .failure("""
            No Desktop change happened on \(display.name). Either every display has only one Desktop, or the "Move left a \
            space" and "Move right a space" shortcuts are off, and dnm cannot tell which; it scans a display with one \
            Desktop only beside one where Desktops switch. To turn the shortcuts on: \(About.shortcutSettings). \
            `dnm cleanup` without --scan still works. Nothing was deleted.
            """)
    }

    /// The image file name a display's current Desktop shows, once three reads a moment apart agree (research R2).
    /// Fifteen reads (about 1.5 s) without three in a row agreeing stop the scan, with nothing deleted. nil when it
    /// shows no image file. A read that fails (the display was
    /// disconnected) stops the scan: a Desktop that could not be read must never count as showing nothing.
    @MainActor
    func stableRead(_ display: Display, walking walked: Display? = nil, switcher: DesktopSwitching) throws -> String? {
        func read() throws -> String? {
            do { return try system.currentWallpaper(on: display).url?.lastPathComponent } catch {
                let away = walked.map { $0.uuid == display.uuid ? "" : " \($0.name) may be on another Desktop." } ?? ""
                throw DesktopNavigator.StopWithoutReturning("dnm could not read the wallpaper of \(display.name) during the scan (\(error.localizedDescription)). Nothing was deleted. dnm did not switch back, since \(display.name) may be disconnected; check that each display is on the Desktop you want.\(away)")
            }
        }
        switcher.pause(Self.stableReadPause)
        var last = try read()
        var agreeing = 1
        for _ in 1..<Self.stableReadLimit {
            switcher.pause(Self.stableReadPause)
            let next = try read()
            agreeing = next == last ? agreeing + 1 : 1
            last = next
            if agreeing >= Self.stableReadsNeeded { return last }
        }
        // A wallpaper that never settles is not read: taking a stale value would offer a label in use.
        throw DnmError.failure("The wallpaper of \(display.name) kept changing while dnm read it, so a Desktop could not be read. Nothing was deleted.")
    }

    /// Records that every label the scan saw was seen now (spec 012 FR-006), as one locked change. For a scan whose
    /// candidates are kept, or that found none; `carryOut` does it when deleting.
    public func recordSeen(_ result: ScanResult) throws {
        guard store.hasManifest else { return }
        try store.exclusive {
            let now = time.now
            let names = result.seen.union(try shownFileNames())
            try store.transaction { Self.markSeen(names, at: now, in: &$0) }
        }
    }
}

/// The order of a scan's questions (spec 012 contracts/cli.md §2), apart from the command so it can be tested:
/// nothing switches, and nothing is deleted, without an answer or `--yes`.
public enum ScanFlow {
    public enum Start: Equatable, Sendable {
        /// Ask `Scan every Desktop now?` and walk only on yes.
        case askToScan
        case scan
        /// Describe only, and say to add `--yes` (no terminal, or `--json`, without `--yes`).
        case describeOnly
    }

    public enum Finish: Equatable, Sendable {
        case nothingToDelete
        /// Ask `Delete these …?` and delete only on yes.
        case askToDelete
        case delete
        /// Keep everything: no way to ask.
        case keep
    }

    public static func start(yes: Bool, terminal: Bool, json: Bool) -> Start {
        if yes { return .scan }
        return terminal && !json ? .askToScan : .describeOnly
    }

    public static func finish(candidates: Int, yes: Bool, terminal: Bool, json: Bool) -> Finish {
        guard candidates > 0 else { return .nothingToDelete }
        if yes { return .delete }
        return terminal && !json ? .askToDelete : .keep
    }

    /// Only `y` or `yes`, in any case, is a yes.
    public static func isYes(_ answer: String?) -> Bool {
        guard let answer = answer?.trimmingCharacters(in: .whitespaces).lowercased() else { return false }
        return answer == "y" || answer == "yes"
    }
}

/// The scan's text (spec 012 contracts/cli.md §2), built here so the command stays thin.
public enum ScanText {
    /// Seconds per Desktop in the description's estimate: about two steps per Desktop, about a second each.
    public static let secondsPerDesktop = 2

    public static func description(_ preview: ScanPreview, separateSpaces: Bool) -> [String] {
        let names = preview.displays.map(\.name).joined(separator: ", ")
        let first = separateSpaces || preview.displays.count < 2
            ? "dnm will visit every Desktop of \(preview.displays.count == 1 ? "this display" : "these displays, one display at a time"): \(names)."
            : "dnm will visit every Desktop once; these displays switch together (\"Displays have separate Spaces\" is off): \(names)."
        return [first,
                "It takes about \(secondsPerDesktop) seconds per Desktop. The Desktops slide by and the pointer moves; do not type until it is done.",
                "Each display returns to the Desktop it started on."]
    }

    public static func notChecked(_ displays: [NotConnectedDisplay]) -> [String] {
        displays.map { "Not checked: \($0.name) is not connected (\($0.labels) label\($0.labels == 1 ? "" : "s"))." }
    }

    public static let nothingToScan = "No label of a connected display is stored, so there is nothing to scan."
    public static let nothingScanned = "Nothing was scanned: add --yes to scan without asking."
    public static let nothingToDelete = "Every label of the connected displays shows on a Desktop; nothing to clean up."

    public static func images(_ count: Int) -> String { "\(count) labeled image\(count == 1 ? "" : "s")" }

    /// The candidates, then the displays not checked.
    public static func report(_ plan: CleanupPlan, notConnected: [NotConnectedDisplay], now: Date) -> [String] {
        let size = ByteCountFormatter()
        var lines = ["Not on any Desktop (\(plan.candidates.count) label\(plan.candidates.count == 1 ? "" : "s"), \(size.string(fromByteCount: plan.totalBytes))):"]
        let rows = plan.candidates.map { candidate in
            (display: candidate.displayName, label: "\"\(candidate.label)\"", size: size.string(fromByteCount: candidate.bytes),
             seen: candidate.lastSeen.map { "last seen \(ago($0, now: now))" } ?? "never seen")
        }
        let displayWidth = rows.map(\.display.count).max() ?? 0
        let labelWidth = rows.map(\.label.count).max() ?? 0
        let sizeWidth = rows.map(\.size.count).max() ?? 0
        for row in rows {
            lines.append("  " + row.display.padding(toLength: displayWidth, withPad: " ", startingAt: 0) + "  "
                + row.label.padding(toLength: labelWidth, withPad: " ", startingAt: 0) + "  "
                + String(repeating: " ", count: sizeWidth - row.size.count) + row.size + "  " + row.seen)
        }
        return lines + notChecked(notConnected)
    }

    /// Displays counted as having one Desktop (FR-017), said plainly before the question.
    public static func oneDesktop(_ names: [String]) -> [String] {
        names.map { "Only one Desktop was found on \($0) (no step moved there); if it has more, do not delete its labels: run the scan again." }
    }

    public static func question(_ plan: CleanupPlan) -> String {
        "Delete these \(images(plan.candidates.count)) (\(ByteCountFormatter().string(fromByteCount: plan.totalBytes)))? [y/N] "
    }

    public static func deleted(_ plan: CleanupPlan) -> String {
        guard !plan.candidates.isEmpty else { return "Nothing was deleted: the labeled images changed since they were listed." }
        return "Deleted \(images(plan.candidates.count)) (\(ByteCountFormatter().string(fromByteCount: plan.totalBytes)))."
    }

    static func ago(_ date: Date, now: Date) -> String {
        let days = max(0, Int(now.timeIntervalSince(date) / 86_400))
        return days == 0 ? "today" : "\(days) day\(days == 1 ? "" : "s") ago"
    }
}
