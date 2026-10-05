import Foundation
@testable import DesktopNameCore

/// A wallpaper-store view backed by the fake system: it knows what each display currently shows and what it
/// last wrote as the display default.
final class FakeStoreInspector: WallpaperStoreInspector {
    let system: FakeWallpaperSystem
    /// When true, behaves like an unreadable store.
    var unreadable = false

    init(system: FakeWallpaperSystem) { self.system = system }

    func references(to fileName: String) -> StoreReferences? {
        if unreadable { return nil }
        let desktops = system.connectedDisplays.filter { (try? system.currentWallpaper(on: $0).url?.lastPathComponent) == fileName }.count
        let isDefault = system.displayDefaultFile.values.contains(fileName)
        return StoreReferences(desktopCount: desktops, displayDefault: isDefault, newDesktopTemplate: false)
    }
}
