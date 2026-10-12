import Foundation
@testable import DesktopNameCore

/// Adds labels straight to a store: a record in the manifest and a file of a given size (sparse, so big sizes cost nothing).
extension LabelerHarness {
    @discardableResult
    func addStamp(_ text: String = "Old", state: StampState = .active, lastSeen: Date? = nil, createdAt: Date? = nil,
                  bytes: Int = 1_000, displayName: String = "Display A") throws -> Stamp {
        let id = UUID()
        let created = createdAt ?? clock.now
        let stamp = Stamp(id: id, fileName: "\(id.uuidString).dnm.jpg", label: Fixtures.label(text), original: Fixtures.original(),
                          displayUUID: display.uuid, displayName: displayName, pixelWidth: 800, pixelHeight: 500,
                          createdAt: created, state: state, reuseKey: nil, lastSeen: lastSeen)
        try store.transaction { $0.stamps.append(stamp) }
        try store.writeStampFile(Data(), named: stamp.fileName)
        let handle = try FileHandle(forWritingTo: store.fileURL(named: stamp.fileName))
        try handle.truncate(atOffset: UInt64(bytes))
        try handle.close()
        return stamp
    }

    func days(_ count: Double) -> Date { clock.now.addingTimeInterval(-count * 86_400) }
}
