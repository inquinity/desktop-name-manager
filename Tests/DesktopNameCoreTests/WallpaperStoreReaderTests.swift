import Foundation
import Testing
@testable import DesktopNameCore

/// The reader is exercised on small synthetic stores built here, never copied from a real machine.
@Suite struct WallpaperStoreReaderTests {
    let stampName = "11111111-2222-3333-4444-555555555555.dnm.jpg"

    /// An entry shaped like macOS's: a nested property list, stored as data, holding a file URL.
    func entry(file: String) throws -> [String: Any] {
        let configuration = try PropertyListSerialization.data(
            fromPropertyList: ["url": ["relative": "file:///somewhere/\(file)"]] as [String: Any], format: .binary, options: 0)
        return ["Type": "individual", "Desktop": ["Content": ["Choices": [["Configuration": configuration]]]]]
    }

    func writeStore(_ root: [String: Any], in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("Index.plist")
        try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0).write(to: url)
        return url
    }

    func references(_ root: [String: Any]) throws -> StoreReferences? {
        let dir = try SyntheticImages.temporaryDirectory(); defer { try? FileManager.default.removeItem(at: dir) }
        return WallpaperStoreReader(url: try writeStore(root, in: dir)).references(to: stampName)
    }

    @Test func aStampOnOneDesktopOnlyIsNotASpread() throws {
        let root: [String: Any] = [
            "Spaces": ["SPACE-A": ["Default": try entry(file: stampName), "Displays": ["DISPLAY-1": try entry(file: stampName)]],
                       "SPACE-B": ["Default": try entry(file: "plain.png")]],
            "Displays": ["DISPLAY-1": try entry(file: "plain.png")],
        ]
        let found = try #require(try references(root))
        #expect(found == StoreReferences(desktopCount: 1, displayDefault: false, newDesktopTemplate: false))
        #expect(found.isReferenced && !found.spreadsBeyondOneDesktop)
    }

    @Test func aStampInADisplayDefaultIsASpread() throws {
        let root: [String: Any] = [
            "Spaces": ["SPACE-A": ["Default": try entry(file: stampName)]],
            "Displays": ["DISPLAY-1": try entry(file: stampName)],
        ]
        let found = try #require(try references(root))
        #expect(found.displayDefault && found.spreadsBeyondOneDesktop)
    }

    @Test func aStampInTheNewDesktopTemplateIsASpread() throws {
        let root: [String: Any] = ["Spaces": ["": ["Default": try entry(file: stampName)]]]
        let found = try #require(try references(root))
        #expect(found.newDesktopTemplate && found.desktopCount == 0 && found.spreadsBeyondOneDesktop)
    }

    @Test func aStampOnSeveralDesktopsIsASpread() throws {
        let root: [String: Any] = ["Spaces": ["A": ["Default": try entry(file: stampName)], "B": ["Default": try entry(file: stampName)]]]
        let found = try #require(try references(root))
        #expect(found.desktopCount == 2 && found.spreadsBeyondOneDesktop)
    }

    @Test func aStampThatIsNotReferencedIsReportedAsSuch() throws {
        let found = try #require(try references(["Spaces": ["A": ["Default": try entry(file: "plain.png")]]]))
        #expect(!found.isReferenced)
    }

    @Test func missingOrMalformedStoresMeanUnknown() throws {
        let dir = try SyntheticImages.temporaryDirectory(); defer { try? FileManager.default.removeItem(at: dir) }
        #expect(WallpaperStoreReader(url: dir.appendingPathComponent("absent.plist")).references(to: stampName) == nil)
        let bad = dir.appendingPathComponent("bad.plist")
        try Data("not a plist".utf8).write(to: bad)
        #expect(WallpaperStoreReader(url: bad).references(to: stampName) == nil)
    }

    @Test func theReaderNeverWrites() throws {
        let dir = try SyntheticImages.temporaryDirectory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = try writeStore(["Spaces": ["A": ["Default": try entry(file: stampName)]]], in: dir)
        let before = try Data(contentsOf: url)
        let dates = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        _ = WallpaperStoreReader(url: url).references(to: stampName)
        #expect(try Data(contentsOf: url) == before)
        #expect(try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == dates)
    }
}
