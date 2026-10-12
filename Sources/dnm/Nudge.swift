import DesktopNameCore
import Foundation

/// A one-line reminder, after `set` and `remove` (never `undo`, which is someone fixing a mistake), that old labeled images
/// have piled up (spec 009). Only when standard error is a terminal; any failure stays silent.
enum Nudge {
    static func showIfDue(_ context: Context) {
        guard isatty(STDERR_FILENO) != 0, let nudge = try? context.labeler.nudgeIfDue() else { return }
        let size = ByteCountFormatter().string(fromByteCount: nudge.bytes)
        Output.err("dnm: note: about \(size) (\(nudge.labels) label\(nudge.labels == 1 ? "" : "s")) of old labeled images could be freed: run dnm cleanup.")
    }
}
