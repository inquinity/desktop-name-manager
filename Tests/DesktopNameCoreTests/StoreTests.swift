import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct StoreTests {
    func makeStore() throws -> (Store, URL) {
        let dir = try SyntheticImages.temporaryDirectory().appendingPathComponent("store", isDirectory: true)
        return (Store(directory: dir), dir)
    }

    @Test func missingManifestReadsAsEmpty() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        #expect(try store.readManifest() == Manifest())
        #expect(!FileManager.default.fileExists(atPath: dir.path))   // reading creates nothing
    }

    @Test func transactionRoundTrips() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        try store.transaction { $0.changes.append(Fixtures.change()) }
        let manifest = try store.readManifest()
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.changes.count == 1)
    }

    @Test func storeNameHasDebugSuffixInDebugBuilds() {
        #if DEBUG
        #expect(Store.storeName == "com.altmansoftwaredesign.desktop-name-manager.dev")
        #else
        #expect(Store.storeName == "com.altmansoftwaredesign.desktop-name-manager")
        #endif
    }

    @Test func overrideVariableWins() {
        let url = Store.defaultDirectory(environment: ["DNM_STORE_DIR": "/tmp/dnm-override"])
        #expect(url.path == "/tmp/dnm-override")
        #expect(Store.defaultDirectory(environment: [:]).lastPathComponent == Store.storeName)
    }

    @Test func concurrentTransactionsDoNotLoseUpdates() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        let runs = 20
        DispatchQueue.concurrentPerform(iterations: runs) { _ in
            try? store.transaction { $0.changes.append(Fixtures.change()) }
        }
        #expect(try store.readManifest().changes.count == runs)
    }

    @Test func newerSchemaVersionIsReadOnly() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let original = Data(#"{"schemaVersion": 99, "stamps": [], "changes": [], "future": true}"#.utf8)
        try original.write(to: store.manifestURL)
        #expect(throws: DnmError.newerManifest(found: 99, supported: 1)) { try store.readManifest() }
        #expect(throws: DnmError.newerManifest(found: 99, supported: 1)) { try store.transaction { $0.stamps = [] } }
        #expect(try Data(contentsOf: store.manifestURL) == original)   // untouched
    }

    @Test func unwritableStoreFailsBeforeAnythingElse() throws {
        let root = try SyntheticImages.temporaryDirectory()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: root.path)
        let store = Store(directory: root.appendingPathComponent("store"))
        do {
            try store.transaction { _ in }
            Issue.record("expected an error")
        } catch let error as DnmError {
            if case .storeNotWritable = error {} else { Issue.record("wrong error: \(error)") }
            #expect(error.exitCode == 1)
        }
        #expect(throws: DnmError.self) { try store.writeStampFile(Data([1]), named: "x.dnm.jpg") }
    }

    @Test func damagedManifestIsLeftAlone() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.manifestURL)
        #expect(throws: DnmError.self) { try store.readManifest() }
        #expect(try Data(contentsOf: store.manifestURL) == Data("not json".utf8))
    }
}
