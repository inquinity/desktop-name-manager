import Foundation
@testable import DesktopNameCore

/// A clock the test advances by hand.
final class FakeTimeSource: TimeSource {
    var now: Date

    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) { now = start }

    func advance(minutes: Double) { now = now.addingTimeInterval(minutes * 60) }
}
