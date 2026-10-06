// switch-timing: RESEARCH TOOL, never part of the product.
//
// Measures how quickly macOS switches Desktops when the "Move left/right a space" shortcuts are pressed,
// so `dnm --desktop`'s waits (confirm timeout, settle time) and spec 001's SC-008 can rest on numbers.
// Public interfaces only (the same ones `--desktop` uses): key presses posted with CGEvent, NSWorkspace's
// activeSpaceDidChangeNotification, and pointer moves. It switches Desktops but never changes a wallpaper,
// and it returns each display to the Desktop it started on.
//
// Needs the Accessibility permission for the app running it, the two shortcuts on, and at least two
// Desktops per measured display. Don't type or switch Desktops while it runs.
//
// Build and run (from the repository root):
//   swiftc -O -o build.noindex/research/switch-timing prototype/switch-timing.swift
//   build.noindex/research/switch-timing [--display main|NAME|all] [--samples N] [--csv FILE]
//   build.noindex/research/switch-timing --display NAME --goto N     # leave that display on Desktop N
//
// Measurements, per display:
//   confirm  time from the key press to macOS's "active Desktop changed" notification, with a long pause
//            between steps (sets dnm's confirm timeout);
//   gap      steps pressed a fixed time after the previous one was confirmed, for several gaps; counts steps
//            that were lost (no notification) or doubled (sets dnm's settle time);
//   edge     a press at the last Desktop, where nothing should move: whether any notification arrives late.

import AppKit
import ApplicationServices
import Foundation

// MARK: - Options

func argument(_ name: String) -> String? {
    let arguments = CommandLine.arguments
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

let displayChoice = argument("--display") ?? "all"
let samples = Int(argument("--samples") ?? "20") ?? 20
let csvPath = argument("--csv")
let gotoTarget = argument("--goto").flatMap(Int.init)
let gaps: [Double] = [0, 0.05, 0.10, 0.15, 0.25, 0.40]
/// Long enough that a missing notification really means nothing moved.
let generousTimeout = 2.5
/// Long enough that the previous slide has surely finished.
let restPause = 0.8

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("switch-timing: \(message)\n".utf8))
    exit(1)
}

// MARK: - Events

// Print each line as it happens, also through a pipe (tee), so a long run shows progress.
setvbuf(stdout, nil, _IOLBF, 0)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.finishLaunching()

/// Notification arrival times, appended on the main thread while events are pumped.
var arrivals: [Double] = []
let clockStart = Date()
func now() -> Double { Date().timeIntervalSince(clockStart) }

let observer = NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: nil) { _ in arrivals.append(now()) }

func pump(for duration: Double, until done: () -> Bool = { false }) {
    let deadline = now() + duration
    while now() < deadline && !done() {
        if let event = NSApp.nextEvent(matching: .any, until: Date().addingTimeInterval(0.005), inMode: .default, dequeue: true) {
            NSApp.sendEvent(event)
        }
    }
}

enum Direction { case left, right }

/// Presses the shortcut; returns the press time.
func press(_ direction: Direction) -> Double {
    let key: CGKeyCode = direction == .left ? 123 : 124
    let source = CGEventSource(stateID: .hidSystemState)
    let pressedAt = now()
    for down in [true, false] {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
        event.flags = [.maskControl, .maskSecondaryFn, .maskNumericPad]
        event.post(tap: .cghidEventTap)
        usleep(20_000)
    }
    return pressedAt
}

struct StepResult {
    var latency: Double?   // seconds from press to first notification, nil if none
    var notifications: Int // how many arrived within the timeout
}

/// One step: press, then wait up to `timeout` for the notification. With `collectAll`, keeps listening for the
/// whole timeout to catch doubled or late notifications.
func step(_ direction: Direction, timeout: Double = generousTimeout, collectAll: Bool = false) -> StepResult {
    let before = arrivals.count
    let pressedAt = press(direction)
    pump(for: timeout) { !collectAll && arrivals.count > before }
    let mine = arrivals[before...]
    return StepResult(latency: mine.first.map { $0 - pressedAt }, notifications: mine.count)
}

// MARK: - Displays

struct Screen {
    var name: String
    var isMain: Bool
    var center: CGPoint   // Quartz coordinates
}

func screens() -> [Screen] {
    let all = NSScreen.screens
    guard let mainFrame = all.first?.frame else { return [] }
    return all.enumerated().map { index, screen in
        Screen(name: screen.localizedName, isMain: index == 0,
               center: CGPoint(x: screen.frame.midX, y: mainFrame.maxY - screen.frame.midY))
    }
}

func chosenScreens() -> [Screen] {
    let all = screens()
    switch displayChoice {
    case "all": return all
    case "main": return all.filter(\.isMain)
    default:
        let matches = all.filter { $0.name.localizedCaseInsensitiveContains(displayChoice) }
        guard matches.count == 1 else { fail("--display \(displayChoice) matches \(matches.count) displays") }
        return matches
    }
}

func pointAt(_ screen: Screen) {
    CGWarpMouseCursorPosition(screen.center)
    pump(for: 0.3)
}

// MARK: - Statistics and output

func percentile(_ values: [Double], _ fraction: Double) -> Double {
    let sorted = values.sorted()
    guard !sorted.isEmpty else { return .nan }
    let index = min(sorted.count - 1, max(0, Int((Double(sorted.count - 1) * fraction).rounded())))
    return sorted[index]
}

func ms(_ seconds: Double) -> String { seconds.isNaN ? "-" : String(format: "%.0f", seconds * 1000) }

func summary(_ values: [Double]) -> String {
    guard !values.isEmpty else { return "no samples" }
    return "min \(ms(values.min()!)) / median \(ms(percentile(values, 0.5))) / p95 \(ms(percentile(values, 0.95))) / max \(ms(values.max()!)) ms (n=\(values.count))"
}

func environment() -> [(String, String)] {
    var size = 0
    var chip = "unknown"
    if sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 1 {
        var bytes = [CChar](repeating: 0, count: size)
        if sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0) == 0 {
            chip = String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
    }
    let version = ProcessInfo.processInfo.operatingSystemVersion
    return [
        ("macos", "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"),
        ("chip", chip),
        ("displays", "\(NSScreen.screens.count)"),
        ("separate_spaces", "\(NSScreen.screensHaveSeparateSpaces)"),
        ("reduce_motion", "\(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)"),
    ]
}

var csvRows: [String] = []
let csvContext = environment().map(\.1).joined(separator: ",")
func record(_ display: String, _ measure: String, _ gap: Double?, _ sample: Int, _ result: StepResult) {
    csvRows.append([csvContext, "\"\(display)\"", measure, gap.map { String(format: "%.2f", $0) } ?? "",
                    "\(sample)", result.latency.map { String(format: "%.1f", $0 * 1000) } ?? "",
                    "\(result.notifications)"].joined(separator: ","))
}

/// Appends this display's rows to the CSV file now, so an interrupted run keeps what it measured.
func flushCSV() {
    guard let csvPath, !csvRows.isEmpty else { return }
    var text = csvRows.joined(separator: "\n") + "\n"
    if !FileManager.default.fileExists(atPath: csvPath) {
        text = environment().map(\.0).joined(separator: ",") + ",display,measure,gap_s,sample,latency_ms,notifications\n" + text
        FileManager.default.createFile(atPath: csvPath, contents: nil)
    }
    if let handle = FileHandle(forWritingAtPath: csvPath) {
        handle.seekToEndOfFile()
        handle.write(Data(text.utf8))
        handle.closeFile()
    }
    csvRows.removeAll()
}

// MARK: - Navigation

/// Steps left until nothing moves; returns how many steps moved (the start position is that + 1).
func walkToFirst() -> Int {
    var moved = 0
    while moved < 32 && step(.left).latency != nil {
        moved += 1
        pump(for: restPause)
    }
    return moved
}

/// Steps right from Desktop 1 until nothing moves; returns the number of Desktops (ends on the last one).
func countDesktops() -> Int {
    var count = 1
    while count < 32 && step(.right).latency != nil {
        count += 1
        pump(for: restPause)
    }
    return count
}

/// Walks right to the last Desktop with generous waits, to re-anchor the position after an unconfirmed step.
func walkToLast() {
    var moved = 0
    while moved < 32 && step(.right).latency != nil {
        moved += 1
        pump(for: restPause)
    }
}

func move(from position: Int, to target: Int) {
    var at = position
    while at != target {
        let direction: Direction = target < at ? .left : .right
        guard step(direction).latency != nil else { fail("a step was not confirmed while moving to Desktop \(target)") }
        at += direction == .left ? -1 : 1
        pump(for: restPause)
    }
}

// MARK: - Main

guard AXIsProcessTrusted() else {
    fail("the app running this needs the Accessibility permission (System Settings > Privacy & Security > Accessibility on macOS 26, Device Control and Data Access on macOS 27)")
}
let savedPointer = CGEvent(source: nil)?.location ?? .zero

if let gotoTarget {
    // Helper for the live script: leave one display on a given Desktop.
    guard let screen = chosenScreens().first, displayChoice != "all" else { fail("--goto needs --display main or a name") }
    pointAt(screen)
    _ = walkToFirst()
    move(from: 1, to: gotoTarget)
    CGWarpMouseCursorPosition(savedPointer)
    exit(0)
}

print("switch-timing: " + environment().map { "\($0.0)=\($0.1)" }.joined(separator: ", "))
print("samples=\(samples), gaps=\(gaps.map { ms($0) }.joined(separator: "/")) ms")

for screen in chosenScreens() {
    print("\n== \(screen.name)\(screen.isMain ? " (main)" : "")")
    pointAt(screen)
    let origin = walkToFirst() + 1
    let desktops = countDesktops()
    guard desktops >= 2 else {
        // Skip it and go on: macOS moves Desktops between displays when monitors change.
        print("skipped: one Desktop (or the shortcuts are off); add Desktops in Mission Control to measure it")
        continue
    }
    print("started on Desktop \(origin) of \(desktops)")
    var position = desktops

    // Bounces between Desktop 1 and the last, so every step can move.
    func nextDirection() -> Direction {
        position == 1 ? .right : position == desktops ? .left : (position % 2 == 0 ? .left : .right)
    }

    // 1. Confirm latency with a rest between steps.
    var latencies: [Double] = []
    for sample in 1...samples {
        let direction = nextDirection()
        let result = step(direction, timeout: generousTimeout, collectAll: true)
        record(screen.name, "confirm", nil, sample, result)
        if let latency = result.latency {
            latencies.append(latency)
            position += direction == .left ? -1 : 1
        }
        pump(for: restPause)
    }
    print("confirm latency: \(summary(latencies)), unconfirmed \(samples - latencies.count)")

    // 2. Gaps: the next press comes `gap` seconds after the previous confirmation.
    for gap in gaps {
        // Re-anchor at the last Desktop before each gap.
        walkToLast()
        position = desktops
        var lost = 0, doubled = 0
        var gapLatencies: [Double] = []
        for sample in 1...samples {
            let direction = nextDirection()
            let result = step(direction)
            record(screen.name, "gap", gap, sample, result)
            if let latency = result.latency {
                gapLatencies.append(latency)
                position += direction == .left ? -1 : 1
                // Catch a doubled notification during the gap.
                let before = arrivals.count
                pump(for: gap)
                if arrivals.count > before { doubled += arrivals.count - before }
            } else {
                lost += 1
                // Where the display is now is uncertain: re-anchor.
                pump(for: restPause)
                walkToLast()
                position = desktops
            }
        }
        print("gap \(ms(gap)) ms: lost \(lost), doubled \(doubled), latency \(summary(gapLatencies))")
    }

    // 3. Edge: at Desktop 1, a left press should move nothing; listen for late notifications.
    walkToLast()
    move(from: desktops, to: 1)
    var late = 0
    for sample in 1...min(samples, 5) {
        let result = step(.left, timeout: generousTimeout, collectAll: true)
        record(screen.name, "edge", nil, sample, result)
        late += result.notifications
        pump(for: restPause)
    }
    print("edge: \(late) notification(s) in \(min(samples, 5)) presses that should move nothing (wait \(ms(generousTimeout)) ms)")

    move(from: 1, to: origin)
    print("returned to Desktop \(origin)")
    flushCSV()
}

CGWarpMouseCursorPosition(savedPointer)
NSWorkspace.shared.notificationCenter.removeObserver(observer)
if let csvPath {
    flushCSV()
    print("\nCSV: \(csvPath)")
}
