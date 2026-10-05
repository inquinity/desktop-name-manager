import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct AccessDeniedTests {
    @Test func anUnreadableWallpaperShowsTheSystemsErrorAndChangesNothing() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: original.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: original.path) }

        do {
            try h.labeler.setLabel(LabelText("Email"), on: h.display)
            Issue.record("expected an error")
        } catch let error as DnmError {
            if case .accessDenied(let message) = error {
                #expect(message.localizedCaseInsensitiveContains("permission"))   // the system's own wording
            } else { Issue.record("wrong error: \(error)") }
            #expect(error.exitCode == 1)
            #expect((error.errorDescription ?? "").contains("Nothing was changed"))
        }
        #expect(h.system.setCalls.isEmpty)
        #expect(try h.manifest().stamps.isEmpty)
        #expect(h.storeFiles.isEmpty)
    }

    @Test func anOriginalThatBecomesUnreadableDuringAReplacementChangesNothing() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let before = try h.manifest()
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: original.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: original.path) }

        #expect(throws: DnmError.self) { try h.labeler.setLabel(LabelText("Mail"), on: h.display) }
        #expect(try h.manifest() == before)
        #expect(h.system.setCalls.count == 2)   // the first label: re-apply the wallpaper, then the stamp
    }

    @Test func theToolNeverRetriesWithAWorkaround() throws {
        // A denial is reported once; nothing else is attempted, so the wallpaper system is never called.
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: original.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: original.path) }
        _ = try? h.labeler.setLabel(LabelText("Email"), on: h.display)
        #expect(h.system.setCalls.isEmpty)
    }
}
