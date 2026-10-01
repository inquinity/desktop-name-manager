import Foundation
@testable import DesktopNameCore

/// Builders for model values used across tests.
enum Fixtures {
    static let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    static func label(_ text: String = "Email") -> Label {
        Label(text: try! LabelText(text), look: .plain, textColor: .light, position: .bottomLeft, size: .medium, automatic: [.look, .textColor])
    }

    static func original(path: String = "/tmp/original.png") -> Original {
        Original(path: path, bookmark: nil, scaling: 3, clipping: true, fillColor: nil)
    }

    static func stamp(id: UUID = UUID(), ext: String = "jpg", state: StampState = .active, display: String = "DISPLAY-A") -> Stamp {
        Stamp(id: id, fileName: "\(id.uuidString).dnm.\(ext)", label: label(), original: original(), displayUUID: display,
              pixelWidth: 2880, pixelHeight: 1800, createdAt: epoch, state: state)
    }

    static func change(display: String = "DISPLAY-A", at: Date = epoch) -> ChangeRecord {
        ChangeRecord(displayUUID: display, kind: .set, at: at, produced: .stamp(id: UUID()), before: .original(original()))
    }
}
