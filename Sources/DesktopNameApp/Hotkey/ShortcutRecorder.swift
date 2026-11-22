import AppKit
import Observation
import SwiftUI

/// The two hotkeys (FR-014): one opens the main window, one opens the editor ("Style and Preview").
public enum HotkeyKind: CaseIterable, Sendable {
    case main
    case editor
}

/// Claims and releases the system-wide hotkeys (the app's `HotkeyRegistrar`, over `RegisterEventHotKey`; a fake in
/// tests). `register(_:for:)` makes `shortcut` that kind's hotkey, replacing its previous one, and returns false when
/// macOS refuses it, leaving that kind with none.
@MainActor
public protocol HotkeyRegistering: AnyObject {
    func register(_ shortcut: Shortcut, for kind: HotkeyKind) -> Bool
    func unregister(_ kind: HotkeyKind)
}

/// The hotkey settings (spec 014, FR-014, FR-015): a shortcut is stored only after it was claimed; one that cannot be
/// claimed, or that the other hotkey uses, is shown with its sentence and not stored, and the previous one stays.
@MainActor
@Observable
public final class HotkeySetting {
    public static let inUse = "Another app is using this shortcut. Choose another."

    /// The sentence for a shortcut the other hotkey already uses.
    public static func usedBy(_ kind: HotkeyKind) -> String {
        switch kind {
        case .main: "This shortcut opens the main window. Choose another."
        case .editor: "This shortcut opens Style and Preview. Choose another."
        }
    }

    private var messages: [HotkeyKind: String] = [:]
    @ObservationIgnored private var activeRecorders = 0
    /// The kinds whose stored shortcut is claimed (kept through a release while recording).
    @ObservationIgnored private var claimed: Set<HotkeyKind> = []
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let registrar: HotkeyRegistering

    public init(settings: AppSettings, registrar: HotkeyRegistering) {
        self.settings = settings
        self.registrar = registrar
    }

    public func shortcut(for kind: HotkeyKind) -> Shortcut? { settings.shortcut(for: kind) }

    public func message(for kind: HotkeyKind) -> String? { messages[kind] }

    /// Claims the stored shortcuts at launch. One that cannot be claimed any more is kept, so it works again once
    /// macOS lets it go; Settings says so.
    public func registerStored() {
        for kind in HotkeyKind.allCases { registerStored(kind) }
    }

    private func registerStored(_ kind: HotkeyKind) {
        guard let shortcut = settings.shortcut(for: kind) else { messages[kind] = nil; claimed.remove(kind); return }
        messages[kind] = claim(shortcut, for: kind) ? nil : Self.inUse
    }

    /// Registers `shortcut` and records whether that kind's hotkey now works.
    private func claim(_ shortcut: Shortcut, for kind: HotkeyKind) -> Bool {
        let ok = registrar.register(shortcut, for: kind)
        if ok { claimed.insert(kind) } else { claimed.remove(kind) }
        return ok
    }

    public func record(_ shortcut: Shortcut, for kind: HotkeyKind) {
        if let problem = shortcut.problem {
            messages[kind] = problem
            return
        }
        if let other = HotkeyKind.allCases.first(where: { $0 != kind && settings.shortcut(for: $0) == shortcut }) {
            messages[kind] = Self.usedBy(other)
            return
        }
        let previous = settings.shortcut(for: kind)
        if claim(shortcut, for: kind) {
            settings.setShortcut(shortcut, for: kind)
            messages[kind] = nil
        } else {
            if let previous { _ = claim(previous, for: kind) }
            messages[kind] = Self.inUse   // about the shortcut just pressed
            if activeRecorders == 0 { keepAWayToSettingsNow() }
        }
    }

    /// While a new shortcut is being recorded, both hotkeys are let go, so pressing either is recorded (and the other's
    /// is refused with its sentence) rather than opening a window; they are claimed again once no recorder is
    /// recording. Counted, because moving from one recorder to the other starts the second before the first stops.
    public func recording(_ on: Bool) {
        if on {
            activeRecorders += 1
            if activeRecorders == 1 { for kind in HotkeyKind.allCases { registrar.unregister(kind) } }
        } else if activeRecorders > 0 {
            activeRecorders -= 1
            if activeRecorders == 0 { claimAgain() }
        }
    }

    /// The Settings window closed: no recorder is recording any more, whatever the views reported.
    public func endRecording() {
        guard activeRecorders > 0 else { return }
        activeRecorders = 0
        claimAgain()
    }

    /// After recording: the stored shortcuts are claimed again. The sentence a key press just set stays; only a
    /// shortcut that cannot be claimed again gets one.
    private func claimAgain() {
        for kind in HotkeyKind.allCases {
            guard let shortcut = settings.shortcut(for: kind) else { continue }
            if !claim(shortcut, for: kind) { messages[kind] = Self.inUse }
        }
        keepAWayToSettingsNow()
    }

    /// During a session: when the main hotkey stops working while the item is hidden, the item is shown again.
    private func keepAWayToSettingsNow() {
        if keepAWayToSettings() { onMenuBarModeForced?() }
    }

    /// FR-014a: with the menu-bar item hidden, the main window's shortcut is the way to Settings.
    public static let onlyWayToSettings = "With the menu bar item hidden, this shortcut is the way to Settings. Show the item first."

    /// True when the main window's hotkey is stored and its last claim succeeded (a release while recording does not
    /// count).
    public var opensMainWindow: Bool { settings.hotkey != nil && claimed.contains(.main) }

    /// Called when the item was shown again because the main hotkey stopped working (FR-014a).
    @ObservationIgnored public var onMenuBarModeForced: (@MainActor () -> Void)?

    /// A hidden item with no working main hotkey would leave no way to Settings, so the item is shown again (FR-014a):
    /// at launch after `registerStored()`, and in a session after a claim fails. Returns true when it changed the
    /// setting.
    @discardableResult
    public func keepAWayToSettings() -> Bool {
        guard settings.menuBarMode == .hidden, !opensMainWindow else { return false }
        settings.menuBarMode = .iconAndText
        return true
    }

    public func clear(_ kind: HotkeyKind) {
        if kind == .main, settings.menuBarMode == .hidden {
            messages[.main] = Self.onlyWayToSettings
            return
        }
        registrar.unregister(kind)
        claimed.remove(kind)
        settings.setShortcut(nil, for: kind)
        messages[kind] = nil
    }
}

/// A control that captures one key with its modifiers while it is recording (research R3). Empty, it reads "Record
/// Shortcut"; with a shortcut it shows it and a clear button.
public struct ShortcutRecorder: View {
    let shortcut: Shortcut?
    let onRecord: (Shortcut) -> Void
    let onClear: () -> Void
    let onRecordingChange: (Bool) -> Void
    @State private var recording = false

    public init(shortcut: Shortcut?, onRecord: @escaping (Shortcut) -> Void, onClear: @escaping () -> Void,
                onRecordingChange: @escaping (Bool) -> Void = { _ in }) {
        self.shortcut = shortcut
        self.onRecord = onRecord
        self.onClear = onClear
        self.onRecordingChange = onRecordingChange
    }

    public var body: some View {
        HStack(spacing: 4) {
            Button { recording.toggle() } label: {
                Text(recording ? "Type Shortcut…" : (shortcut?.displayString ?? "Record Shortcut"))
                    .frame(minWidth: 110)
            }
            .background(KeyCatcher(active: $recording, onKey: { onRecord($0) }).frame(width: 0, height: 0))
            .accessibilityLabel(shortcut.map { "Shortcut \($0.displayString)" } ?? "Record Shortcut")
            .onChange(of: recording) { _, on in onRecordingChange(on) }
            // Settings closed or another pane chosen while recording: the hotkey is claimed again.
            .onDisappear { if recording { onRecordingChange(false) } }
            if shortcut != nil, !recording {
                Button(action: onClear) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Clear Shortcut")
            }
        }
    }
}

/// While `active`, takes the keyboard focus and turns the next key press with modifiers into a `Shortcut`. Escape
/// alone stops recording.
private struct KeyCatcher: NSViewRepresentable {
    @Binding var active: Bool
    let onKey: (Shortcut) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onKey = onKey
        view.onEnd = { if active { active = false } }
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onKey = onKey
        view.onEnd = { if active { active = false } }
        if active, view.window?.firstResponder !== view {
            DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        } else if !active, view.window?.firstResponder === view {
            DispatchQueue.main.async { view.window?.makeFirstResponder(nil) }   // not during the view update
        }
    }

    final class CatcherView: NSView {
        var onKey: ((Shortcut) -> Void)?
        var onEnd: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func resignFirstResponder() -> Bool {
            let onEnd = onEnd
            DispatchQueue.main.async { onEnd?() }   // never a state change during a view update
            return super.resignFirstResponder()
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard window?.firstResponder === self else { return false }
            keyDown(with: event)
            return true
        }

        override func keyDown(with event: NSEvent) {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 53, flags.isEmpty {   // Escape
                window?.makeFirstResponder(nil)
                return
            }
            onKey?(Shortcut(keyCode: UInt32(event.keyCode), modifiers: Self.carbonMask(flags)))
            window?.makeFirstResponder(nil)
        }

        static func carbonMask(_ flags: NSEvent.ModifierFlags) -> UInt32 {
            var mask: UInt32 = 0
            if flags.contains(.command) { mask |= Shortcut.Modifier.command }
            if flags.contains(.shift) { mask |= Shortcut.Modifier.shift }
            if flags.contains(.option) { mask |= Shortcut.Modifier.option }
            if flags.contains(.control) { mask |= Shortcut.Modifier.control }
            return mask
        }
    }
}
