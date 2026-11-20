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
        // The request is sent asynchronously: wait for it (briefly) before this copy quits.
        let sent = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in sent.signal() }
        _ = sent.wait(timeout: .now() + 3)
        return true
    }
}
