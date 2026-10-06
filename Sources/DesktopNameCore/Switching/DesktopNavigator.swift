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

    public init(switcher: DesktopSwitching) {
        self.switcher = switcher
    }

    public func visit<T>(desktop target: Int, on display: Display, _ body: () throws -> T) throws -> T {
        guard target >= 1 else { throw DnmError.invalidInput("--desktop takes a Desktop number, 1 or more.") }
        guard switcher.isTrusted else {
            throw DnmError.failure("""
                --desktop needs the Accessibility permission, to press macOS's own "Move left a space" and "Move right a space" \
                shortcuts (macOS offers apps no public way to switch Desktops). Nothing else is typed or read. Grant it to the app \
                you run dnm from in System Settings > Privacy & Security > Accessibility, then run the command again. Nothing was changed.
                """)
        }
        let savedPointer = try switcher.pointAt(display)
        defer { switcher.restorePointer(savedPointer) }
        let baseline = switcher.announcedChanges

        // Find the start: step left to Desktop 1, counting the steps.
        var lefts = 0
        while lefts < Self.maximumSteps && switcher.step(.left) { lefts += 1 }
        let origin = lefts + 1

        if lefts == 0 {
            // Nothing moved. Either this is Desktop 1, or the shortcuts are off: one step right tells them apart.
            if switcher.step(.right) {
                guard switcher.step(.left) else {
                    throw DnmError.failure("macOS did not confirm a step back on \(display.name); it may be one Desktop to the right of where it was. Nothing was labeled.")
                }
            } else {
                throw DnmError.failure("""
                    No Desktop change happened on \(display.name). Either it has only one Desktop (then leave out --desktop), \
                    or the "Move left a space" and "Move right a space" shortcuts are off (System Settings > Keyboard > \
                    Keyboard Shortcuts > Mission Control). Nothing was changed.
                    """)
            }
        }

        var at = 1
        while at < target {
            guard switcher.step(.right) else {
                try returnTo(origin, from: at, on: display)
                throw DnmError.invalidInput("\(display.name) has \(at) Desktop\(at == 1 ? "" : "s"); there is no Desktop \(target). Nothing was changed.")
            }
            at += 1
        }

        // More changes than steps means the person (or another app) switched Desktops meanwhile: the position is
        // no longer known, so stop rather than label the wrong Desktop.
        let moves = lefts + (lefts == 0 ? 2 : 0) + (target - 1)
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
    /// How long to wait for macOS to confirm one step, and to let the slide finish.
    let confirmTimeout: TimeInterval = 1.0
    let settleTime: TimeInterval = 0.25

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

    public func step(_ direction: StepDirection) -> Bool {
        let before = changes.value
        press(direction == .left ? 123 : 124)
        pump(for: confirmTimeout) { self.changes.value != before }
        guard changes.value != before else { return false }
        pump(for: settleTime)
        return true
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
