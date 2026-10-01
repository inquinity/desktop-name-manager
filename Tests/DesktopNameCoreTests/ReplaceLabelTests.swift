import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct ReplaceLabelTests {
    @Test func theReplacementIsRenderedFromTheOriginalNotThePreviousStamp() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let first = try #require(try h.manifest().stamps.first)

        // The Desktop now shows our stamp. Remove the stamp file: a replacement must still work,
        // which proves it does not read the previous stamp.
        h.store.removeFile(named: first.fileName)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)

        let stamps = try h.manifest().stamps
        let second = try #require(stamps.first { $0.id != first.id })
        #expect(URL(fileURLWithPath: second.original.path).resolvingSymlinksInPath() == original.resolvingSymlinksInPath())
        #expect(h.storeFiles == [second.fileName])
    }

    @Test func aMissingOriginalFailsAndChangesNothing() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let before = try h.manifest()
        let callsBefore = h.system.setCalls.count

        try FileManager.default.removeItem(at: original)
        do {
            try h.labeler.setLabel(LabelText("Mail"), on: h.display)
            Issue.record("expected an error")
        } catch let error as DnmError {
            if case .originalMissing = error {} else { Issue.record("wrong error: \(error)") }
        }
        #expect(try h.manifest() == before)
        #expect(h.system.setCalls.count == callsBefore)
    }

    @Test func aMovedOriginalIsFoundThroughItsBookmark() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)

        let moved = h.root.appendingPathComponent("moved.png")
        try FileManager.default.moveItem(at: original, to: moved)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)

        #expect(try h.manifest().stamps.count == 2)
    }
}
