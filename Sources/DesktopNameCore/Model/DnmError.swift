import Foundation

/// Every failure the tool reports. `exitCode` follows contracts/cli.md.
public enum DnmError: Error, Equatable, Sendable {
    /// Bad label, bad option value, unknown or ambiguous `--display` (exit 2).
    case invalidInput(String)
    /// A wallpaper the tool will not change: dynamic, catalog, video, shuffle or none (exit 3).
    case unsupportedWallpaper(String)
    /// macOS denied access to a file the tool needs; carries the system's message (exit 1).
    case accessDenied(String)
    /// The recorded original image cannot be found (exit 1).
    case originalMissing(String)
    /// Undo is not possible: nothing to undo, expired, wallpaper changed, or a file is gone (exit 1).
    case cannotUndo(String)
    /// The manifest was written by a newer version of the tool (exit 1).
    case newerManifest(found: Int, supported: Int)
    /// The store directory cannot be written (exit 1).
    case storeNotWritable(String)
    /// Anything else that stops the command (exit 1).
    case failure(String)

    public var exitCode: Int32 {
        switch self {
        case .invalidInput: 2
        case .unsupportedWallpaper: 3
        default: 1
        }
    }
}

extension DnmError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message): message
        case .unsupportedWallpaper(let reason): "This wallpaper is not supported yet: \(reason). Nothing was changed."
        case .accessDenied(let message): "macOS denied access: \(message). Nothing was changed."
        case .originalMissing(let name): "The original wallpaper \(name) can no longer be found. Choose a wallpaper in System Settings > Wallpaper. Nothing was changed."
        case .cannotUndo(let reason): "Cannot undo: \(reason)."
        case .newerManifest(let found, let supported): "The stored data is format \(found), newer than this tool understands (\(supported)). Update the tool. Nothing was changed."
        case .storeNotWritable(let message): "Cannot write the tool's storage: \(message). Nothing was changed."
        case .failure(let message): message
        }
    }
}
