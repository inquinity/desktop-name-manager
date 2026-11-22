import Foundation
import DesktopNameCore

/// A clock the test advances by hand.
public final class FakeTimeSource: TimeSource {
    public var now: Date

    public init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) { now = start }

    public func advance(minutes: Double) { now = now.addingTimeInterval(minutes * 60) }

    public func advance(seconds: Double) { now = now.addingTimeInterval(seconds) }
}
