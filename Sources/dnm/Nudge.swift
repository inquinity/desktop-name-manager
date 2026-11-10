import DesktopNameCore
import Foundation

/// A one-line reminder, after `set` and `remove` (never `undo`, which is someone fixing a mistake), that old labeled images
/// have piled up (spec 009). Only when standard error is a terminal and quiet mode is off (spec 011); any failure stays
/// silent.
enum Nudge {
    static func showIfDue(_ context: Context) {
        if let line = line(standardErrorIsTerminal: isatty(STDERR_FILENO) != 0, quiet: Output.quiet,
                           due: { try? context.labeler.nudgeIfDue() }) {
            Output.note(line)
        }
    }

    /// The reminder to print (without its `dnm: note: ` prefix, which `Output.note` adds), if any. `due` asks the store
    /// (and records that it was shown), so it is not asked at all when standard error is not a terminal or in quiet
    /// mode: scripts and quiet runs never move the throttle, so a held-back reminder is not used up.
    static func line(standardErrorIsTerminal: Bool, quiet: Bool, due: () -> CleanupNudge?) -> String? {
        guard standardErrorIsTerminal, !quiet, let nudge = due() else { return nil }
        let size = ByteCountFormatter().string(fromByteCount: nudge.bytes)
        return "about \(size) (\(nudge.labels) label\(nudge.labels == 1 ? "" : "s")) of old labeled images could be freed: run dnm cleanup."
    }
}
