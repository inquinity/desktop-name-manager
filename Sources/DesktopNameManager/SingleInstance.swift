import AppKit

/// One copy of the app at a time (spec 014, FR-017): a second launch asks the running copy to reopen (it opens
/// Settings at General) and quits. Launch Services already sends a reopen for the usual case (opening the app
/// again from Finder); this covers a second copy started some other way, for example from another folder.
@MainActor
enum SingleInstance {
    /// True when another copy with this bundle ID is running and was asked to reopen; the caller then quits.
    static func handOverToRunningCopy() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let mine = ProcessInfo.processInfo.processIdentifier
        guard let other = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.processIdentifier != mine && !$0.isTerminated }),
              let url = other.bundleURL else { return false }
        // Opening a running app sends it a reopen event; nothing new is started.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        // The request is sent asynchronously: let it go out (briefly) before this copy quits. The run loop keeps
        // turning, so a completion delivered on the main queue is not left waiting.
        let sent = SentFlag()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async { sent.value = true }
        }
        let deadline = Date().addingTimeInterval(3)
        while !sent.value, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        return true
    }
}

/// Set and read on the main queue only.
private final class SentFlag: @unchecked Sendable { var value = false }
