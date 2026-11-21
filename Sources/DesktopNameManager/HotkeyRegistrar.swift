import AppKit
import Carbon.HIToolbox
import DesktopNameApp
import ServiceManagement

/// The system-wide hotkeys through Carbon's `RegisterEventHotKey` (spec 014, T044, T062, research R3): public,
/// documented, and needs no permission. One registration per kind, each under its own ID; registering a kind again
/// replaces its shortcut. macOS refuses few shortcuts (it does not report another app's), and Settings says so.
@MainActor
final class HotkeyRegistrar: HotkeyRegistering {
    /// Called on the main thread with the hotkey that was pressed.
    var onPress: ((HotkeyKind) -> Void)?
    private var references: [HotkeyKind: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private static let signature: OSType = 0x444E_4D48   // "DNMH"

    private static func id(of kind: HotkeyKind) -> UInt32 {
        switch kind {
        case .main: 1
        case .editor: 2
        }
    }

    func register(_ shortcut: Shortcut, for kind: HotkeyKind) -> Bool {
        installHandler()
        unregister(kind)
        var hotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
                                         EventHotKeyID(signature: Self.signature, id: Self.id(of: kind)),
                                         GetApplicationEventTarget(), 0, &hotKey)
        guard status == noErr, let hotKey else { return false }
        references[kind] = hotKey
        return true
    }

    func unregister(_ kind: HotkeyKind) {
        if let reference = references.removeValue(forKey: kind) { UnregisterEventHotKey(reference) }
    }

    private func installHandler() {
        guard handler == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return noErr }
            var pressed = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            guard status == noErr, pressed.signature == HotkeyRegistrar.signature,
                  let kind = HotkeyKind.allCases.first(where: { HotkeyRegistrar.id(of: $0) == pressed.id }) else { return noErr }
            let registrar = Unmanaged<HotkeyRegistrar>.fromOpaque(context).takeUnretainedValue()
            // Carbon calls this on the main thread, from the application's event loop.
            MainActor.assumeIsolated { registrar.onPress?(kind) }
            return noErr
        }, 1, &type, context, &handler)
    }
}

/// Open at login through `SMAppService.mainApp` (spec 014, T049, research R4). macOS shows its own notice.
@MainActor
final class MainAppLoginItem: LoginItem {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    func setEnabled(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}
