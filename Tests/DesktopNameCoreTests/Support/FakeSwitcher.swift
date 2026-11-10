import CoreGraphics
import Foundation
@testable import DesktopNameCore

/// Displays' Desktops as positions, moved by the fake shortcuts.
///
/// Made with `init(desktops:position:)` it is one display, whichever display it is pointed at (spec 001 and 010
/// tests). With `attach(_:wallpapers:position:)` each display has its own Desktops, each showing a wallpaper that a
/// linked `FakeWallpaperSystem` reports as the step lands there (spec 012).
@MainActor
final class FakeSwitcher: DesktopSwitching {
    struct Screen {
        var display: Display?
        var wallpapers: [URL?]
        var position: Int
    }

    private static let anyDisplay = "*"
    private var screens: [String: Screen]
    private var pointedKey = FakeSwitcher.anyDisplay
    /// Reports the wallpaper of the Desktop each display lands on.
    var system: FakeWallpaperSystem?
    /// When false, a step moves every display together ("Displays have separate Spaces" off).
    var separateSpaces = true
    /// The wallpaper takes this many reads to catch up after a step (0: at once).
    var lateReads = 0
    var isTrusted = true
    var shortcutsOn = true
    /// Steps (counted from 1) whose confirmation never arrives, to simulate a lost step.
    var unconfirmedSteps: Set<Int> = []
    /// Steps (counted from 1) that move but are announced late: after the step gave up, at the next pause.
    var lateAnnouncedSteps: Set<Int> = []
    private var lateAnnouncements = 0
    /// Makes `currentWallpaper` throw for this display from the next step on, as for one disconnected meanwhile.
    var disconnectAtStep: (step: Int, display: Display)?
    private(set) var steps = 0
    private(set) var pointedAt: String?
    private(set) var pointedAtNames: [String] = []
    private(set) var pointerRestored = false
    private(set) var visitedPositions: [Int] = []
    private(set) var announcedChanges = 0
    private(set) var pauses = 0
    /// A step (counted from 1) during which the person also switches one Desktop right.
    var personSwitchesAtStep: Int?
    /// A step (counted from 1) after which `onInterruptStep` runs, to raise an interrupt there.
    var interruptAtStep: Int?
    var onInterruptStep: (() -> Void)?

    init(desktops: Int, position: Int) {
        screens = [Self.anyDisplay: Screen(display: nil, wallpapers: Array(repeating: nil, count: desktops), position: position)]
    }

    /// Several displays, each added with `attach`.
    init(system: FakeWallpaperSystem) {
        screens = [:]
        self.system = system
    }

    /// Gives `display` its Desktops, one wallpaper each, showing Desktop `position`.
    func attach(_ display: Display, wallpapers: [URL?], position: Int) {
        screens[display.uuid] = Screen(display: display, wallpapers: wallpapers, position: position)
        system?.show(wallpapers[position - 1], on: display)
    }

    func position(of display: Display) -> Int? { screens[display.uuid]?.position }

    var desktops: Int { screens[pointedKey]?.wallpapers.count ?? 0 }
    var position: Int { screens[pointedKey]?.position ?? 0 }

    func pointAt(_ display: Display) throws -> CGPoint {
        pointedAt = display.name
        pointedAtNames.append(display.name)
        pointedKey = screens[display.uuid] != nil ? display.uuid : Self.anyDisplay
        pointerRestored = false
        return CGPoint(x: 1, y: 2)
    }

    func restorePointer(_ location: CGPoint) { pointerRestored = location == CGPoint(x: 1, y: 2) }

    func pause(_ seconds: TimeInterval) {
        pauses += 1
        announcedChanges += lateAnnouncements
        lateAnnouncements = 0
    }

    func step(_ direction: StepDirection) -> Bool {
        steps += 1
        defer { if interruptAtStep == steps { onInterruptStep?() } }
        guard shortcutsOn, let pointed = screens[pointedKey] else { return false }
        let next = direction == .left ? pointed.position - 1 : pointed.position + 1
        guard (1...pointed.wallpapers.count).contains(next) else { return false }
        for key in separateSpaces ? [pointedKey] : Array(screens.keys) { move(key, to: next) }
        visitedPositions.append(next)
        if personSwitchesAtStep == steps { personSwitches() }
        if let disconnect = disconnectAtStep, disconnect.step == steps { system?.unreadable.insert(disconnect.display.uuid) }
        guard !unconfirmedSteps.contains(steps) else { return false }
        if lateAnnouncedSteps.contains(steps) { lateAnnouncements += 1; return false }
        announcedChanges += 1
        return true
    }

    private func move(_ key: String, to position: Int) {
        guard var screen = screens[key], (1...screen.wallpapers.count).contains(position) else { return }
        screen.position = position
        screens[key] = screen
        guard let system, let display = screen.display else { return }
        let url = screen.wallpapers[position - 1]
        if lateReads > 0, let url {
            system.showLater(url, on: display, afterReads: lateReads)
        } else {
            system.show(url, on: display)
        }
    }

    /// The person moves one Desktop right (or left at the last one), and macOS announces it.
    func personSwitches() {
        guard let pointed = screens[pointedKey] else { return }
        move(pointedKey, to: pointed.position < pointed.wallpapers.count ? pointed.position + 1 : pointed.position - 1)
        announcedChanges += 1
    }
}
