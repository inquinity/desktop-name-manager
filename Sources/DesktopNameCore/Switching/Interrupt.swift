import Darwin
import Synchronization

/// Ctrl-C during `cleanup --scan` (spec 012 FR-015, research R4). The first one only raises a flag, which the walk
/// checks before each step: it then returns the display to where it started and stops. A second one, while the
/// display is returning, prints a line prepared in advance and exits 130 at once.
///
/// The handler does only async-signal-safe work: an atomic exchange, `write(2)` of bytes already in place, and
/// `_exit`. The handler is installed only around the walk, so Ctrl-C at a question ends the command as usual.
public enum Interrupt {
    private static let maximumMessage = 1024
    /// The line for a second Ctrl-C, filled in by `prepare` before each walk; never allocated in the handler.
    private nonisolated(unsafe) static let message = UnsafeMutablePointer<UInt8>.allocate(capacity: maximumMessage)
    private static let messageLength = Atomic<Int>(0)
    private static let requested = Atomic<Bool>(false)
    private nonisolated(unsafe) static var previous = sigaction()

    /// Whether Ctrl-C was pressed since `install`.
    public static var isRequested: Bool { requested.load(ordering: .acquiring) }

    /// Starts catching Ctrl-C; call `restore` afterwards.
    public static func install() {
        // Set up every static the handler reads now, so the handler never runs their one-time initialization.
        messageLength.store(0, ordering: .releasing)
        message.initialize(repeating: 0, count: maximumMessage)
        requested.store(false, ordering: .releasing)
        var action = sigaction()
        action.__sigaction_u.__sa_handler = { _ in
            if Interrupt.requested.exchange(true, ordering: .acquiringAndReleasing) {
                let length = Interrupt.messageLength.load(ordering: .acquiring)
                if length > 0 { _ = write(STDERR_FILENO, Interrupt.message, length) }
                _exit(130)
            }
        }
        sigemptyset(&action.sa_mask)
        action.sa_flags = 0
        sigaction(SIGINT, &action, &previous)
    }

    /// Puts back what Ctrl-C did before `install`.
    public static func restore() {
        sigaction(SIGINT, &previous, nil)
        requested.store(false, ordering: .releasing)
    }

    /// Names the display being walked in the line a second Ctrl-C prints.
    public static func prepare(display: String) {
        let bytes = Array(secondInterruptLine(display: display).utf8.prefix(maximumMessage))
        messageLength.store(0, ordering: .releasing)
        bytes.withUnsafeBufferPointer { message.update(from: $0.baseAddress!, count: bytes.count) }
        messageLength.store(bytes.count, ordering: .releasing)
    }

    static func secondInterruptLine(display: String) -> String {
        "\ndnm: Stopped; \(display) may be on another Desktop. Nothing was deleted.\n"
    }
}
