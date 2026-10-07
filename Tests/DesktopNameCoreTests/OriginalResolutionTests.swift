import Foundation
import Testing
@testable import DesktopNameCore

/// How a recorded original is found again (security plan S2 and S10).
@Suite struct OriginalResolutionTests {
    @Test func resolvingABookmarkNeverMountsAVolumeOrShowsUI() {
        #expect(DesktopLabeler.bookmarkResolution.contains(.withoutMounting))
        #expect(DesktopLabeler.bookmarkResolution.contains(.withoutUI))
    }

    @Test(arguments: ["notes.txt", "folder.png"])
    func anOriginalThatIsNotAnImageFileIsRefused(_ name: String) throws {
        let root = try SyntheticImages.temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent(name)
        if name.hasPrefix("folder") {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } else {
            try Data("not an image".utf8).write(to: url)
        }
        let original = Original(path: url.path, bookmark: nil, scaling: 0, clipping: true, fillColor: nil)
        #expect(throws: DnmError.self) { try DesktopLabeler.resolve(original) }
    }

    @Test func anImageWithoutAnExtensionIsAccepted() throws {
        let root = try SyntheticImages.temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let png = try SyntheticImages.write(SyntheticImages.gradient(), to: root.appendingPathComponent("picture.png"))
        let bare = root.appendingPathComponent("picture")
        try FileManager.default.moveItem(at: png, to: bare)
        let original = Original(path: bare.path, bookmark: nil, scaling: 0, clipping: true, fillColor: nil)
        #expect(try DesktopLabeler.resolve(original).path == bare.path)
    }

    @Test func theBookmarkStillFollowsAMovedOriginal() throws {
        let root = try SyntheticImages.temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let first = try SyntheticImages.write(SyntheticImages.gradient(), to: root.appendingPathComponent("first.png"))
        let original = Original(path: first.path, bookmark: try first.bookmarkData(), scaling: 0, clipping: true, fillColor: nil)
        let moved = root.appendingPathComponent("moved.png")
        try FileManager.default.moveItem(at: first, to: moved)
        #expect(try DesktopLabeler.resolve(original).resolvingSymlinksInPath().path == moved.resolvingSymlinksInPath().path)
    }
}
