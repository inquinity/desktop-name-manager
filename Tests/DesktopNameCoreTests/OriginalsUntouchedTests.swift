import CryptoKit
import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct OriginalsUntouchedTests {
    func digest(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }

    @Test func originalFilesAreByteIdenticalAfterEveryOperation() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        let checksum = try digest(original)
        let modified = try original.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        #expect(try digest(original) == checksum)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        #expect(try digest(original) == checksum)
        try h.labeler.removeLabel(on: h.display)
        #expect(try digest(original) == checksum)
        try h.labeler.undoLastChange(on: h.display)
        #expect(try digest(original) == checksum)
        try h.labeler.removeLabel(on: h.display)
        #expect(try digest(original) == checksum)

        #expect(try original.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == modified)
    }

    @Test func theOriginalIsNeverWrittenInsideTheStore() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        #expect(original.deletingLastPathComponent().resolvingSymlinksInPath() != h.store.directory.resolvingSymlinksInPath())
        #expect(h.storeFiles.allSatisfy { $0.hasSuffix(".dnm.jpg") })
    }
}
