import Foundation
import Testing
@testable import DesktopNameCore
import DNMTestSupport

@Suite struct WallpaperKindTests {
    func current(_ url: URL?) -> CurrentWallpaper { CurrentWallpaper(url: url, placement: FakeWallpaperSystem.defaultPlacement) }

    @Test func aPlainImageIsSupported() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let url = try h.showOriginal()
        #expect(try WallpaperKind.classify(current(url)) == .supported(url))
    }

    @Test func noFileReportedIsNoFile() throws {
        #expect(try WallpaperKind.classify(current(nil)) == .noFile)
    }

    @Test func aFileThatIsNotAPictureIsUnreadable() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let url = h.root.appendingPathComponent("Lake.heic")
        try Data("not a picture".utf8).write(to: url)
        #expect(try WallpaperKind.classify(current(url)) == .unreadable(name: "Lake.heic"))
    }

    @Test func theTwoNewSentences() {
        #expect(DnmError.noWallpaperFile.errorDescription == "This Desktop has no wallpaper picture to label. Nothing was changed.")
        #expect(DnmError.unreadableWallpaper("Lake.heic").errorDescription == "Cannot read wallpaper 'Lake.heic'. Nothing was changed.")
        #expect(DnmError.noWallpaperFile.exitCode == 3)
        #expect(DnmError.unreadableWallpaper("x").exitCode == 3)
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

    // Spec 015: macOS 27 reports a fixed stand-in still for Apple dynamic wallpapers.
    static let standInReason = "macOS reports the default wallpaper when dynamic or unsupported wallpapers are selected"

    @Test(arguments: [
        "/System/Library/CoreServices/DefaultDesktop.heic",
        "/System//Library/CoreServices/./DefaultDesktop.heic",
        "/System/Library/Elsewhere/../CoreServices/DefaultDesktop.heic",
    ])
    func theStandInLocationIsUnsupported(_ path: String) throws {
        // Only the location is compared: nothing at the real path is opened.
        #expect(try WallpaperKind.classify(current(URL(fileURLWithPath: path))) == .unsupported(reason: Self.standInReason))
    }

    @Test func theStandInIsRefusedWithoutBeingOpened() throws {
        // A missing file would throw `.originalMissing` if anything tried to read it: only the location decides.
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let missing = h.root.appendingPathComponent("CoreServices/DefaultDesktop.heic")
        #expect(try WallpaperKind.classify(current(missing), standIns: [missing]) == .unsupported(reason: Self.standInReason))
    }

    @Test func aReadableStillAtTheStandInLocationIsStillRefused() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let still = try h.showOriginal()
        #expect(try WallpaperKind.classify(current(still), standIns: [still]) == .unsupported(reason: Self.standInReason))
    }

    @Test func theSamePictureElsewhereIsSupported() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let still = try h.showOriginal(name: "DefaultDesktop.heic.png")
        let standIn = h.root.appendingPathComponent("CoreServices/DefaultDesktop.heic")
        #expect(try WallpaperKind.classify(current(still), standIns: [standIn]) == .supported(still))
    }

    @Test func settingALabelOnTheStandInChangesNothingAndExitsThree() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        h.system.show(URL(fileURLWithPath: "/System/Library/CoreServices/DefaultDesktop.heic"), on: h.display)
        do {
            try h.labeler.setLabel(LabelText("Email"), on: h.display)
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 3)
            #expect(error == .unsupportedWallpaper(Self.standInReason))
            #expect(error.errorDescription == "This wallpaper is not supported: \(Self.standInReason). Nothing was changed.")
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
