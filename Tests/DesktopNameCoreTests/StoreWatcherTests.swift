import Foundation
import Testing
@testable import DesktopNameCore
import DNMTestSupport

/// The store watcher (spec 014, contracts/core-additions.md §3).
@MainActor
@Suite(.serialized) struct StoreWatcherTests {
    /// Long enough for the coalescing delay and the folder event to arrive.
    static let settle: Duration = .milliseconds(500)

    func makeStore() throws -> (Store, URL) {
        let root = try SyntheticImages.temporaryDirectory()
        let store = Store(directory: root.appendingPathComponent("store", isDirectory: true))
        try store.transaction { _ in }   // create the folder and a manifest
        return (store, root)
    }

    @Test func oneTransactionGivesOneCall() async throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        var calls = 0
        let watcher = try StoreWatcher(store: store) { calls += 1 }
        defer { watcher.stop() }
        try await Task.sleep(for: Self.settle)
        try store.transaction { $0.stamps.append(Fixtures.stamp()) }
        try await Task.sleep(for: Self.settle)
        #expect(calls == 1)
    }

    @Test func aBurstGivesOneCall() async throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        var calls = 0
        // A long gathering time, so a slow machine cannot split the burst.
        let watcher = try StoreWatcher(store: store, coalescingDelay: 1) { calls += 1 }
        defer { watcher.stop() }
        try await Task.sleep(for: Self.settle)
        for _ in 0..<5 { try store.transaction { $0.stamps.append(Fixtures.stamp()) } }
        try await Task.sleep(for: .milliseconds(1_600))
        #expect(calls == 1)
    }

    @Test func aReplacedFolderIsWatchedAgain() async throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        var calls = 0
        let watcher = try StoreWatcher(store: store) { calls += 1 }
        defer { watcher.stop() }
        try await Task.sleep(for: Self.settle)
        try FileManager.default.removeItem(at: store.directory)   // the manifest goes with it: one call
        try await Task.sleep(for: Self.settle)
        #expect(calls == 1)
        try store.transaction { $0.stamps.append(Fixtures.stamp()) }   // a new folder and manifest
        try await Task.sleep(for: .milliseconds(1_800))   // the reopen check runs once a second
        try store.transaction { $0.stamps.append(Fixtures.stamp()) }
        try await Task.sleep(for: Self.settle)
        #expect(calls >= 2)
    }

    @Test func droppingTheWatcherEndsTheWatch() async throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        var calls = 0
        var watcher: StoreWatcher? = try StoreWatcher(store: store) { calls += 1 }
        _ = watcher
        watcher = nil
        try await Task.sleep(for: Self.settle)
        try store.transaction { $0.stamps.append(Fixtures.stamp()) }
        try await Task.sleep(for: Self.settle)
        #expect(calls == 0)
    }

    @Test func aStampImageAloneGivesNoCall() async throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        var calls = 0
        let watcher = try StoreWatcher(store: store) { calls += 1 }
        defer { watcher.stop() }
        try await Task.sleep(for: Self.settle)
        try store.writeStampFile(Data([1, 2, 3]), named: "\(UUID().uuidString).dnm.jpg")
        try await Task.sleep(for: Self.settle)
        #expect(calls == 0)
    }

    @Test func removingTheManifestGivesACall() async throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        var calls = 0
        let watcher = try StoreWatcher(store: store) { calls += 1 }
        defer { watcher.stop() }
        try await Task.sleep(for: Self.settle)
        try FileManager.default.removeItem(at: store.manifestURL)
        try await Task.sleep(for: Self.settle)
        #expect(calls == 1)
    }

    @Test func afterStopThereAreNoCalls() async throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        var calls = 0
        let watcher = try StoreWatcher(store: store) { calls += 1 }
        try store.transaction { $0.stamps.append(Fixtures.stamp()) }
        watcher.stop()   // before the coalescing delay: the scheduled call is dropped too
        try await Task.sleep(for: Self.settle)
        try store.transaction { $0.stamps.append(Fixtures.stamp()) }
        try await Task.sleep(for: Self.settle)
        #expect(calls == 0)
    }

    @Test func aMissingFolderThrows() throws {
        let root = try SyntheticImages.temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = Store(directory: root.appendingPathComponent("never-made", isDirectory: true))
        #expect(throws: DnmError.self) { _ = try StoreWatcher(store: store) {} }
    }
}
