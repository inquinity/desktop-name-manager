import AppKit
import Carbon.HIToolbox
import DesktopNameApp
import ServiceManagement

/// The system-wide hotkey through Carbon's `RegisterEventHotKey` (spec 014, T044, research R3): public, documented,
/// and needs no permission. One hotkey at a time; registering another replaces it. A shortcut another app holds is
/// refused (`eventHotKeyExistsErr`), and Settings says so.
@MainActor
final class HotkeyRegistrar: HotkeyRegistering {
    /// Called on the main thread when the hotkey is pressed.
    var onPress: (() -> Void)?
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private static let signature: OSType = 0x444E_4D48   // "DNMH"

    func register(_ shortcut: Shortcut) -> Bool {
        installHandler()
        unregister()
        var hotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: Self.signature, id: 1),
                                         GetApplicationEventTarget(), 0, &hotKey)
        guard status == noErr, let hotKey else { return false }
        reference = hotKey
        return true
    }

    func unregister() {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
    }

    private func installHandler() {
        guard handler == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return noErr }
            let registrar = Unmanaged<HotkeyRegistrar>.fromOpaque(context).takeUnretainedValue()
            // Carbon calls this on the main thread, from the application's event loop.
            MainActor.assumeIsolated { registrar.onPress?() }
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
