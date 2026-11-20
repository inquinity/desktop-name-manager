import CoreGraphics
import DesktopNameApp
import DesktopNameCore
import DNMTestSupport
import Foundation

/// A fake wallpaper system, a temporary store, a fake clock and private user defaults, for the app's models.
@MainActor
final class AppRig {
    let root: URL
    let display: Display
    let system: FakeWallpaperSystem
    let clock = FakeTimeSource()
    let store: Store
    let labeler: DesktopLabeler
    let controller: LabelingController
    let defaults: UserDefaults
    let suite: String
    let wallpaper: URL

    init(displays: [Display]? = nil, image: CGImage = SyntheticImages.gradient()) throws {
        root = try SyntheticImages.temporaryDirectory()
        let list = displays ?? [FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "DISPLAY-A", isMain: true,
                                                                 width: 800, height: 500, scale: 1)]
        display = list[0]
        system = FakeWallpaperSystem(displays: list)
        store = Store(directory: root.appendingPathComponent("store", isDirectory: true))
        labeler = DesktopLabeler(system: system, store: store, time: clock)
        controller = LabelingController(labeler: labeler)
        suite = "dnm-app-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        wallpaper = try SyntheticImages.write(image, to: root.appendingPathComponent("wallpaper.png"))
        for one in list { system.show(wallpaper, on: one) }
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }

    func settings() -> AppSettings { AppSettings(defaults: defaults) }

    /// The bytes of the image showing on `display`.
    func shownBytes(on display: Display? = nil) throws -> Data? {
        guard let url = try system.currentWallpaper(on: display ?? self.display).url else { return nil }
        return try Data(contentsOf: url)
    }
}

/// A login item that records what it was told.
@MainActor
final class FakeLoginItem: LoginItem {
    var isEnabled = false
    var failure: Error?

    func setEnabled(_ enabled: Bool) throws {
        if let failure { throw failure }
        isEnabled = enabled
    }
}

/// A hotkey registrar where some shortcuts are held by "another app".
@MainActor
final class FakeRegistrar: HotkeyRegistering {
    var heldElsewhere: Set<Shortcut> = []
    private(set) var registered: Shortcut?

    func register(_ shortcut: Shortcut) -> Bool {
        registered = nil
        guard !heldElsewhere.contains(shortcut) else { return false }
        registered = shortcut
        return true
    }

    func unregister() { registered = nil }
}
