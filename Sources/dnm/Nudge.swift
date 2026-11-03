import DesktopNameCore
import Foundation

/// A one-line reminder, after `set` and `remove` (never `undo`, which is someone fixing a mistake), that old labeled images
/// have piled up (spec 009). Only when standard error is a terminal; any failure stays silent.
enum Nudge {
    static func showIfDue(_ context: Context) {
        if let line = line(standardErrorIsTerminal: isatty(STDERR_FILENO) != 0, due: { try? context.labeler.nudgeIfDue() }) {
            Output.err(line)
        }
    }

    /// The reminder to print, if any. `due` asks the store (and records that it was shown), so it is not asked at all
    /// when standard error is not a terminal: scripts never move the throttle.
    static func line(standardErrorIsTerminal: Bool, due: () -> CleanupNudge?) -> String? {
        guard standardErrorIsTerminal, let nudge = due() else { return nil }
        let size = ByteCountFormatter().string(fromByteCount: nudge.bytes)
        return "dnm: note: about \(size) (\(nudge.labels) label\(nudge.labels == 1 ? "" : "s")) of old labeled images could be freed: run dnm cleanup."
    }
}
