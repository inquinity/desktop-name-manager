import Darwin
import Foundation

/// An advisory lock on `manifest.lock`, held for the life of the object. It keeps two runs of the
/// tool (or later the app and the tool) from corrupting the manifest.
final class StoreLock {
    private let descriptor: Int32

    init(at url: URL) throws {
        descriptor = open(url.path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else {
            throw DnmError.storeNotWritable("cannot open \(url.lastPathComponent): \(String(cString: strerror(errno)))")
        }
        guard flock(descriptor, LOCK_EX) == 0 else {
            let message = String(cString: strerror(errno))
            close(descriptor)
            throw DnmError.storeNotWritable("cannot lock \(url.lastPathComponent): \(message)")
        }
    }

    deinit {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}
