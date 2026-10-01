import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct HandChangedWallpaperTests {
    @Test func aWallpaperChosenInSystemSettingsBecomesTheNewOriginal() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let first = try h.showOriginal(name: "first.png")
        try h.labeler.setLabel(LabelText("Email"), on: h.display)

        // The user picks another picture in System Settings: the Desktop no longer shows our stamp.
        let second = try h.showOriginal(SyntheticImages.dark(), name: "second.png")
        let result = try h.labeler.setLabel(LabelText("Mail"), on: h.display)

        #expect(!result.replaced)
        let stamps = try h.manifest().stamps
        #expect(stamps.count == 2)
        let newest = try #require(stamps.last)
        #expect(URL(fileURLWithPath: newest.original.path).resolvingSymlinksInPath() == second.resolvingSymlinksInPath())
        #expect(URL(fileURLWithPath: newest.original.path).resolvingSymlinksInPath() != first.resolvingSymlinksInPath())
    }
}
