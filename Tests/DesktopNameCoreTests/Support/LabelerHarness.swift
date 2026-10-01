import CoreGraphics
import Foundation
@testable import DesktopNameCore

/// A labeler wired to a fake wallpaper system, a temporary store and a fake clock.
final class LabelerHarness {
    let root: URL
    let store: Store
    let system: FakeWallpaperSystem
    let clock = FakeTimeSource()
    let display: Display
    let labeler: DesktopLabeler

    init(extraDisplays: [Display] = []) throws {
        root = try SyntheticImages.temporaryDirectory()
        store = Store(directory: root.appendingPathComponent("store", isDirectory: true))
        display = FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "DISPLAY-A", isMain: true, width: 800, height: 500, scale: 1)
        system = FakeWallpaperSystem(displays: [display] + extraDisplays)
        labeler = DesktopLabeler(system: system, store: store, time: clock)
    }

    func cleanUp() { try? FileManager.default.removeItem(at: root) }

    /// Writes a wallpaper image into the temporary folder and makes `display` show it.
    @discardableResult
    func showOriginal(_ image: CGImage = SyntheticImages.gradient(), name: String = "original.png",
                      placement: WallpaperPlacement = FakeWallpaperSystem.defaultPlacement) throws -> URL {
        let url = try SyntheticImages.write(image, to: root.appendingPathComponent(name))
        system.show(url, placement: placement, on: display)
        return url
    }

    func manifest() throws -> Manifest { try store.readManifest() }

    var storeFiles: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: store.directory.path)) ?? []).filter(Cleanup.isOurFileName)
    }
}
