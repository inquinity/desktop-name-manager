import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct WallpaperKindTests {
    func current(_ url: URL?) -> CurrentWallpaper { CurrentWallpaper(url: url, placement: FakeWallpaperSystem.defaultPlacement) }

    @Test func aPlainImageIsSupported() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let url = try h.showOriginal()
        #expect(try WallpaperKind.classify(current(url)) == .supported(url))
    }

    @Test func noFileReportedIsUnsupported() throws {
        guard case .unsupported = try WallpaperKind.classify(current(nil)) else { Issue.record("expected unsupported"); return }
    }

    @Test(arguments: ["Tahoe.madesktop", "Aerial.mov", "Loop.mp4"])
    func catalogAndVideoFilesAreUnsupported(_ name: String) throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let url = h.root.appendingPathComponent(name)
        try Data([0, 1, 2]).write(to: url)
        guard case .unsupported = try WallpaperKind.classify(current(url)) else { Issue.record("expected unsupported for \(name)"); return }
    }

    @Test func aFolderIsUnsupported() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let folder = h.root.appendingPathComponent("Shuffle", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard case .unsupported = try WallpaperKind.classify(current(folder)) else { Issue.record("expected unsupported"); return }
    }

    @Test func aMultiFrameImageIsUnsupported() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let url = try SyntheticImages.writeMultiFrame(to: h.root.appendingPathComponent("Dynamic.tiff"))
        guard case .unsupported(let reason) = try WallpaperKind.classify(current(url)) else { Issue.record("expected unsupported"); return }
        #expect(reason.contains("dynamic"))
    }

    @Test func aMissingFileIsReportedAsMissing() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        #expect(throws: DnmError.originalMissing("gone.png")) { try WallpaperKind.classify(current(h.root.appendingPathComponent("gone.png"))) }
    }

    @Test(arguments: ["Tahoe.madesktop", "Aerial.mov"])
    func settingALabelOnAnUnsupportedWallpaperChangesNothing(_ name: String) throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let url = h.root.appendingPathComponent(name)
        try Data([0, 1, 2]).write(to: url)
        h.system.show(url, on: h.display)
        do {
            try h.labeler.setLabel(LabelText("Email"), on: h.display)
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 3)
            if case .unsupportedWallpaper = error {} else { Issue.record("wrong error: \(error)") }
        }
        #expect(h.system.setCalls.isEmpty)
        #expect(try h.manifest().stamps.isEmpty)
        #expect(h.storeFiles.isEmpty)
    }

    @Test func noWallpaperFileMapsToExitCodeThree() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        h.system.show(nil, on: h.display)
        do { try h.labeler.setLabel(LabelText("Email"), on: h.display) } catch let error as DnmError { #expect(error.exitCode == 3) }
        #expect(h.system.setCalls.isEmpty)
    }
}
