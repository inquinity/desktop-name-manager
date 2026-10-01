import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct SetLabelOrderTests {
    struct Boom: Error {}

    @Test func stampFileAndManifestEntryExistBeforeTheWallpaperIsSet() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        var observedFiles: [String] = []
        var observedActive = 0
        h.system.beforeSet = {
            observedFiles = h.storeFiles
            observedActive = ((try? h.manifest().stamps) ?? []).filter(\.isActive).count
        }
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        #expect(observedFiles.count == 1)
        #expect(observedActive == 1)
    }

    @Test func aFailureSettingTheWallpaperLeavesNothingBehind() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        h.system.setError = Boom()
        #expect(throws: DnmError.self) { try h.labeler.setLabel(LabelText("Email"), on: h.display) }
        let manifest = try h.manifest()
        #expect(manifest.stamps.isEmpty)
        #expect(manifest.changes.isEmpty)
        #expect(h.storeFiles.isEmpty)
        #expect(h.system.setCalls.isEmpty)
    }

    @Test func aFailedReplacementRestoresTheOldActiveStamp() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let before = try h.manifest()
        h.system.setError = Boom()
        #expect(throws: DnmError.self) { try h.labeler.setLabel(LabelText("Mail"), on: h.display) }
        #expect(try h.manifest() == before)
        #expect(h.storeFiles.count == 1)
    }

    @Test func anUnwritableStoreLeavesTheWallpaperUnchanged() throws {
        let h = try LabelerHarness(); defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: h.root.path)
            h.cleanUp()
        }
        try h.showOriginal()
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: h.root.path)   // store/ cannot be created
        do {
            try h.labeler.setLabel(LabelText("Email"), on: h.display)
            Issue.record("expected an error")
        } catch let error as DnmError {
            if case .storeNotWritable = error {} else { Issue.record("wrong error: \(error)") }
            #expect(error.exitCode == 1)
        }
        #expect(h.system.setCalls.isEmpty)
    }
}
