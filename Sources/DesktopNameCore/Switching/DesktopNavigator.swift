import AppKit
import ApplicationServices
import Foundation

/// The moves the navigator needs, behind a protocol so the logic can be tested without switching real Desktops.
@MainActor
public protocol DesktopSwitching {
    /// True when this process may send the switching shortcuts (the Accessibility permission). Never prompts.
    var isTrusted: Bool { get }
    /// Puts the pointer on `display`, so the shortcuts act there, and returns a token to put it back.
    func pointAt(_ display: Display) throws -> CGPoint
    func restorePointer(_ location: CGPoint)
    /// Presses "Move left a space" or "Move right a space"; true if macOS announced a Desktop change.
    func step(_ direction: StepDirection) -> Bool
    /// Every Desktop change macOS has announced so far, the person's included.
    var announcedChanges: Int { get }
    /// Waits about `seconds` while delivering the application's events, so a wallpaper read afterwards is current.
    func pause(_ seconds: TimeInterval)
}

public enum StepDirection: Sendable {
    case left, right
}

/// Reaches Desktop N of a display with public interfaces only (spec 001 FR-027, research R14), runs `body` there,
/// and always returns to the Desktop the display started on.
///
/// Public interfaces cannot say which Desktop is showing, so it first steps left until nothing moves: that is
/// Desktop 1, and the number of steps gives the starting position.
@MainActor
public struct DesktopNavigator {
    let switcher: DesktopSwitching
    /// Guards against a runaway loop; macOS allows at most 16 Desktops per display.
    static let maximumSteps = 32
    /// How long a walk waits for a late notice of a Desktop change before comparing the counts (spec 012). A step
    /// that timed out (1.5 s) but moved after all is announced late; counting it stops the scan instead of skipping
    /// a Desktop.
    static let lateNoticePause: TimeInterval = 0.5

    public init(switcher: DesktopSwitching) {
        self.switcher = switcher
    }

    public func visit<T>(desktop target: Int, on display: Display, _ body: () throws -> T) throws -> T {
        guard target >= 1 else { throw DnmError.invalidInput("--desktop takes a Desktop number, 1 or more.") }
        guard switcher.isTrusted else { throw Self.permissionMissing(for: "--desktop", outcome: "Nothing was changed.") }
        let savedPointer = try switcher.pointAt(display)
        defer { switcher.restorePointer(savedPointer) }
        let baseline = switcher.announcedChanges

        // Find the start: step left to Desktop 1, counting the steps.
        var lefts = 0
        while lefts < Self.maximumSteps && switcher.step(.left) { lefts += 1 }
        let origin = lefts + 1

        // Nothing moved: either this is Desktop 1, or the shortcuts are off. A step right tells them apart. For a
        // target beyond Desktop 1 the first step toward it does that; only Desktop 1 needs a step right and back.
        let probed = lefts == 0 && target == 1
        if probed {
            guard switcher.step(.right) else { throw nothingMoved(display) }
            guard switcher.step(.left) else {
                throw DnmError.failure("macOS did not confirm a step back on \(display.name); it may be one Desktop to the right of where it was. Nothing was labeled.")
            }
        }

        var at = 1
        while at < target {
            guard switcher.step(.right) else {
                if lefts == 0 && at == 1 { throw nothingMoved(display) }
                try returnTo(origin, from: at, on: display)
                throw DnmError.invalidInput("\(display.name) has \(at) Desktop\(at == 1 ? "" : "s"); there is no Desktop \(target). Nothing was changed.")
            }
            at += 1
        }

        // More changes than steps means the person (or another app) switched Desktops meanwhile: the position is
        // no longer known, so stop rather than label the wrong Desktop.
        let moves = lefts + (probed ? 2 : 0) + (target - 1)
        guard switcher.announcedChanges - baseline == moves else {
            throw DnmError.failure("The Desktop on \(display.name) changed while dnm was switching (another switch or shortcut). Nothing was labeled. dnm no longer knows where it is, so it did not switch back; return to your Desktop yourself.")
        }
        let beforeBody = switcher.announcedChanges

        let result: T
        do {
            result = try body()
        } catch {
            try? returnTo(origin, from: at, on: display)
            throw error
        }
        guard switcher.announcedChanges == beforeBody else {
            throw DnmError.failure("The Desktop on \(display.name) changed while dnm was working on Desktop \(target), so the change may have gone to another Desktop. Check with `dnm show`, and run `dnm undo` if needed. dnm did not switch back.")
        }
        try returnTo(origin, from: at, on: display)
        return result
    }

    /// The explanation when the Accessibility permission is missing, for `--desktop` and `cleanup --scan`.
    public static func permissionMissing(for feature: String, outcome: String) -> DnmError {
        .failure("""
            \(feature) needs the Accessibility permission, to press macOS's own "Move left a space" and "Move right a space" \
            shortcuts (macOS offers apps no public way to switch Desktops). Nothing else is typed or read. Grant it to the app \
            you run dnm from in \(About.accessibilitySettings), then run the command again. Note: \(About.accessibilityScope) \
            \(outcome)
            """)
    }

    // MARK: - Walking every Desktop (spec 012, research R1)

    /// Thrown by a walk's `read` when the display can no longer be used (disconnected): the walk then stops without
    /// stepping back, since the shortcuts would act on another display.
    public struct StopWithoutReturning: Error {
        public var message: String
        public init(_ message: String) { self.message = message }
    }

    /// How a walk of one display ended.
    public enum WalkOutcome: Equatable, Sendable {
        /// Every Desktop was read, in order; `steps` confirmed steps were taken, the way back included.
        case walked(steps: Int)
        /// No step moved: the display has one Desktop, or the shortcuts are off. Public interfaces cannot tell which,
        /// so the caller decides (spec 012 FR-017). The current Desktop was read once.
        case nothingMoved
    }

    /// Visits every Desktop of `display` and calls `read` on each, from Desktop 1 to the last, then returns the display
    /// to the Desktop it started on and the pointer to where it was. Before each step it asks `isInterrupted`; when
    /// true it stops reading, returns, and throws `DnmError.interrupted` (the caller names what was finished).
    /// The permission is checked by the caller, before anything is printed.
    public func walk(on display: Display, isInterrupted: () -> Bool = { false }, read: () throws -> Void) throws -> WalkOutcome {
        let savedPointer = try switcher.pointAt(display)
        defer { switcher.restorePointer(savedPointer) }
        let baseline = switcher.announcedChanges
        var offset = 0   // from the starting Desktop: negative is left of it
        var confirmed = 0

        func back() throws {
            while offset > 0 {
                guard switcher.step(.left) else { throw lostWayScanning(display) }
                offset -= 1; confirmed += 1
            }
            while offset < 0 {
                guard switcher.step(.right) else { throw lostWayScanning(display) }
                offset += 1; confirmed += 1
            }
        }
        // More changes than confirmed steps means the person (or another app) switched meanwhile, or a step that
        // timed out moved after all: a Desktop may have been skipped or read twice, and the position is unknown.
        // A late notice is counted only once the events are delivered, so wait a moment first.
        func checkCount() throws {
            switcher.pause(Self.lateNoticePause)
            guard switcher.announcedChanges - baseline == confirmed else { throw changedWhileScanning(display) }
        }
        func stopIfInterrupted() throws {
            guard isInterrupted() else { return }
            try checkCount()
            try back()
            throw DnmError.interrupted(scanned: [])
        }
        func readHere() throws {
            do { try read() } catch let stop as StopWithoutReturning {
                // The display may be gone: its shortcuts would now switch another display, so press nothing.
                throw DnmError.failure(stop.message)
            } catch let failure {
                do { try back() } catch {
                    throw DnmError.failure("\((failure as? LocalizedError)?.errorDescription ?? "\(failure)") dnm could not return \(display.name) to the Desktop it started on; switch back yourself if needed.")
                }
                throw failure
            }
        }
        func tooMany() throws -> Never {
            let message = "\(display.name) has more than \(Self.maximumSteps) Desktops and full-screen apps, more than dnm can scan. Nothing was deleted."
            do { try back() } catch { throw DnmError.failure(message + " dnm could not return \(display.name) to the Desktop it started on; switch back yourself if needed.") }
            throw DnmError.failure(message)
        }

        // Step left to Desktop 1.
        var lefts = 0
        while true {
            try stopIfInterrupted()
            guard switcher.step(.left) else { break }
            lefts += 1; offset -= 1; confirmed += 1
            if lefts >= Self.maximumSteps { try tooMany() }
        }
        try readHere()
        // Then right, reading each Desktop, until a step does not move: the last Desktop.
        var rights = 0
        while true {
            try stopIfInterrupted()
            guard switcher.step(.right) else { break }
            rights += 1; offset += 1; confirmed += 1
            if rights >= Self.maximumSteps { try tooMany() }
            try readHere()
        }
        try checkCount()
        guard lefts + rights > 0 else { return .nothingMoved }
        try back()
        try checkCount()
        return .walked(steps: confirmed)
    }

    func changedWhileScanning(_ display: Display) -> DnmError {
        .failure("The Desktop on \(display.name) changed while dnm was scanning. Nothing was deleted. dnm no longer knows where \(display.name) is, so it did not switch back; return to your Desktop yourself.")
    }

    func lostWayScanning(_ display: Display) -> DnmError {
        .failure("macOS did not confirm a step while returning \(display.name) to the Desktop it started on. Nothing was deleted; switch back yourself if needed.")
    }

    private func returnTo(_ origin: Int, from start: Int, on display: Display) throws {
        var at = start
        while at > origin {
            guard switcher.step(.left) else { throw lostWay(display, origin) }
            at -= 1
        }
        while at < origin {
            guard switcher.step(.right) else { throw lostWay(display, origin) }
            at += 1
        }
    }

    private func nothingMoved(_ display: Display) -> DnmError {
        .failure("""
            No Desktop change happened on \(display.name). Either it has only one Desktop (then leave out --desktop), \
            or the "Move left a space" and "Move right a space" shortcuts are off. To turn them on: \
            \(About.shortcutSettings). Nothing was changed.
            """)
    }

    private func lostWay(_ display: Display, _ origin: Int) -> DnmError {
        .failure("macOS did not confirm a step while returning \(display.name) to Desktop \(origin). The command's own change was made; switch back yourself if needed.")
    }
}

/// The real switcher: the pointer, the Control-Left/Right shortcuts, and NSWorkspace's public notification that the
/// active Desktop changed. Main thread only. Runs this process briefly as a background application (no Dock icon,
/// never active), because the notification arrives only through an application's event queue.
@MainActor
public final class SystemDesktopSwitcher: DesktopSwitching {
    /// Counts announced Desktop changes; written from the notification, read while waiting.
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        func increment() { lock.lock(); count += 1; lock.unlock() }
        var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    }

    private let changes = Counter()
    private var observer: NSObjectProtocol?
    /// How long to wait for macOS to confirm one step. Measured worst case 1027 ms (the M5's built-in display on
    /// macOS 27), plus a margin; see docs/research/timings.md, which also says how to recalibrate it. The next
    /// step can follow a confirmation at once: no step was lost with no pause, so there is no settle time.
    let confirmTimeout: TimeInterval = 1.5

    public init() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let counter = changes
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: nil) { _ in counter.increment() }
    }

    /// Stops listening; call when done with the switcher.
    public func stop() {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
    }

    public var isTrusted: Bool { AXIsProcessTrusted() }

    public var announcedChanges: Int { changes.value }

    public func pointAt(_ display: Display) throws -> CGPoint {
        let saved = CGEvent(source: nil)?.location ?? .zero
        let screen = try SystemWallpaperSystem.screen(for: display)
        let mainFrame = NSScreen.screens[0].frame
        // AppKit's origin is the bottom-left of the main screen; Quartz's is the top-left.
        CGWarpMouseCursorPosition(CGPoint(x: screen.frame.midX, y: mainFrame.maxY - screen.frame.midY))
        pump(for: 0.2)
        return saved
    }

    public func restorePointer(_ location: CGPoint) {
        CGWarpMouseCursorPosition(location)
    }

    public func pause(_ seconds: TimeInterval) { pump(for: seconds) }

    public func step(_ direction: StepDirection) -> Bool {
        let before = changes.value
        press(direction == .left ? 123 : 124)
        pump(for: confirmTimeout) { self.changes.value != before }
        return changes.value != before
    }

    private func press(_ key: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            event.flags = [.maskControl, .maskSecondaryFn, .maskNumericPad]
            event.post(tap: .cghidEventTap)
            usleep(20_000)
        }
    }

    /// Delivers the application's events (including the workspace notification) for a while.
    private func pump(for duration: TimeInterval, until done: () -> Bool = { false }) {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline && !done() {
            if let event = NSApp.nextEvent(matching: .any, until: Date().addingTimeInterval(0.02), inMode: .default, dequeue: true) {
                NSApp.sendEvent(event)
            }
        }
    }
}
