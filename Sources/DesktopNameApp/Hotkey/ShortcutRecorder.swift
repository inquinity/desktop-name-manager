import AppKit
import Observation
import SwiftUI

/// Claims and releases the system-wide hotkey (the app's `HotkeyRegistrar`, over `RegisterEventHotKey`; a fake in
/// tests). `register` makes `shortcut` the one hotkey, replacing any other, and returns false when it cannot be claimed
/// (another app holds it), leaving none.
@MainActor
public protocol HotkeyRegistering: AnyObject {
    func register(_ shortcut: Shortcut) -> Bool
    func unregister()
}

/// The hotkey setting (spec 014, FR-014, FR-015): a shortcut is stored only after it was claimed; one that cannot be
/// claimed is shown with its sentence and not stored, and the previous one stays.
@MainActor
@Observable
public final class HotkeySetting {
    public static let inUse = "Another app is using this shortcut. Choose another."

    public private(set) var message: String?
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let registrar: HotkeyRegistering

    public init(settings: AppSettings, registrar: HotkeyRegistering) {
        self.settings = settings
        self.registrar = registrar
    }

    public var shortcut: Shortcut? { settings.hotkey }

    /// Claims the stored shortcut at launch. One that cannot be claimed any more is kept, so it works again once the
    /// other app lets it go; Settings says so.
    public func registerStored() {
        guard let shortcut = settings.hotkey else { message = nil; return }
        message = registrar.register(shortcut) ? nil : Self.inUse
    }

    public func record(_ shortcut: Shortcut) {
        if let problem = shortcut.problem {
            message = problem
            return
        }
        let previous = settings.hotkey
        if registrar.register(shortcut) {
            settings.hotkey = shortcut
            message = nil
        } else {
            if let previous { _ = registrar.register(previous) }
            message = Self.inUse
        }
    }

    /// While a new shortcut is being recorded, the current one is let go, so pressing it is recorded rather than
    /// opening the main window; it is claimed again afterwards unless something replaced it.
    public func recording(_ on: Bool) {
        if on {
            registrar.unregister()
        } else {
            registerStored()
        }
    }

    public func clear() {
        registrar.unregister()
        settings.hotkey = nil
        message = nil
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
