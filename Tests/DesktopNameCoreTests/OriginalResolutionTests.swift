import Foundation
import Testing
@testable import DesktopNameCore

/// How a recorded original is found again (security plan S2 and S10).
@Suite struct OriginalResolutionTests {
    @Test func resolvingABookmarkNeverMountsAVolumeOrShowsUI() {
        #expect(DesktopLabeler.bookmarkResolution.contains(.withoutMounting))
        #expect(DesktopLabeler.bookmarkResolution.contains(.withoutUI))
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
