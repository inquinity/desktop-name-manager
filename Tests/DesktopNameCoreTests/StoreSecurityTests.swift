import Foundation
import Testing
@testable import DesktopNameCore

/// Findings from the first security pass (review-notes.md): the manifest is data on disk that another
/// process of the same user could edit, so nothing in it may steer a delete or write outside the store.
@Suite struct StoreSecurityTests {
    func makeStore() throws -> (Store, URL) {
        let root = try SyntheticImages.temporaryDirectory()
        return (Store(directory: root.appendingPathComponent("store", isDirectory: true)), root)
    }

    /// Writes a manifest whose single stamp is long retired and carries the given file name.
    func plantHostileManifest(_ store: Store, fileName: String) throws {
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        var stamp = Fixtures.stamp(state: .retired(at: Date(timeIntervalSince1970: 0), reason: .removed))
        stamp.fileName = fileName
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(Manifest(stamps: [stamp])).write(to: store.manifestURL)
    }

    @Test(arguments: ["../victim.txt", "../../victim.txt", "/etc/hosts", "sub/\(UUID().uuidString).dnm.jpg", "..", "victim.txt"])
    func aManifestNamingAFileOutsideTheStoreIsRefusedAndNothingIsDeleted(_ fileName: String) throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let victim = root.appendingPathComponent("victim.txt")
        try Data("precious".utf8).write(to: victim)
        try plantHostileManifest(store, fileName: fileName)
        let manifestBefore = try Data(contentsOf: store.manifestURL)

        #expect(throws: DnmError.self) { try store.readManifest() }
        try? Cleanup.run(store: store, now: Date())   // would have deleted the victim before the fix
        #expect(try Data(contentsOf: victim) == Data("precious".utf8))
        #expect(try Data(contentsOf: store.manifestURL) == manifestBefore)   // left alone
    }

    @Test func removeFileIgnoresNamesCarryingAPath() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let victim = root.appendingPathComponent("victim.txt")
        try Data("precious".utf8).write(to: victim)
        store.removeFile(named: "../victim.txt")
        #expect(FileManager.default.fileExists(atPath: victim.path))
        #expect(!store.stampFileExists(named: "../victim.txt"))
    }

    @Test func writeStampFileRefusesNamesThatAreNotOurs() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: DnmError.self) { try store.writeStampFile(Data([1]), named: "../evil.txt") }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("evil.txt").path))
    }

    @Test func theStoreIsOwnerOnly() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        try store.transaction { _ in }
        let name = "\(UUID().uuidString).dnm.jpg"
        try store.writeStampFile(Data([1, 2]), named: name)
        func mode(_ url: URL) throws -> Int {
            (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue ?? -1
        }
        #expect(try mode(store.directory) == 0o700)
        #expect(try mode(store.manifestURL) == 0o600)
        #expect(try mode(store.fileURL(named: name)) == 0o600)
    }

    @Test func aPlantedSymlinkAsTheLockFileIsNotFollowed() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("target.txt")
        try Data("untouched".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: store.lockURL, withDestinationURL: target)
        #expect(throws: DnmError.self) { try store.transaction { _ in } }
        #expect(try Data(contentsOf: target) == Data("untouched".utf8))
    }
}
