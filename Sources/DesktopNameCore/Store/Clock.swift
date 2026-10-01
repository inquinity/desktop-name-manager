import Foundation

/// The current time, behind a protocol so cleanup and undo can be tested with advanced time.
public protocol TimeSource {
    var now: Date { get }
}

public struct SystemTimeSource: TimeSource {
    public init() {}
    public var now: Date { Date() }
}
