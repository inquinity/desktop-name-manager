import Foundation

/// Where in the wallpaper store a stamp file is referenced.
public struct StoreReferences: Equatable, Sendable {
    /// Desktops (Spaces) with their own entry that points at the file.
    public var desktopCount: Int
    /// A display's default entry (used for new Desktops) points at the file.
    public var displayDefault: Bool
    /// The template entry for new Desktops points at the file.
    public var newDesktopTemplate: Bool

    public init(desktopCount: Int, displayDefault: Bool, newDesktopTemplate: Bool) {
        self.desktopCount = desktopCount
        self.displayDefault = displayDefault
        self.newDesktopTemplate = newDesktopTemplate
    }

    /// Anything points at the file.
    public var isReferenced: Bool { desktopCount > 0 || displayDefault || newDesktopTemplate }

    /// The file is used beyond a single Desktop: it has become a default, or is shown on several Desktops.
    public var spreadsBeyondOneDesktop: Bool { displayDefault || newDesktopTemplate || desktopCount > 1 }
}

/// Lets the tool ask where macOS references a stamp file. Optional: `nil` means "cannot tell".
public protocol WallpaperStoreInspector {
    func references(to fileName: String) -> StoreReferences?
}

/// Reads macOS's wallpaper store, READ-ONLY, to see whether a stamp has become a default for new Desktops
/// or spread to other Desktops (known issue KI-1).
///
/// This is the one place the tool looks at a private, undocumented macOS file, as the constitution allows
/// (principle I): it only reads, it is optional (any failure means "unknown" and never blocks labeling),
/// and it is isolated in this file. Nothing here writes to the store.
public struct WallpaperStoreReader: WallpaperStoreInspector {
    let url: URL

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.apple.wallpaper/Store/Index.plist")
    }

    public init(url: URL = WallpaperStoreReader.defaultURL) {
        self.url = url
    }

    public func references(to fileName: String) -> StoreReferences? {
        guard let data = try? Data(contentsOf: url),
              let root = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return nil }

        var desktops = Set<String>()
        var template = false
        var displayDefault = false
        if let spaces = root["Spaces"] as? [String: Any] {
            for (id, entry) in spaces where Self.contains(entry, fileName) {
                if id.isEmpty { template = true } else { desktops.insert(id) }
            }
        }
        if let displays = root["Displays"] as? [String: Any] {
            for (_, entry) in displays where Self.contains(entry, fileName) { displayDefault = true }
        }
        for key in ["AllSpacesAndDisplays", "SystemDefault"] where Self.contains(root[key], fileName) {
            displayDefault = true
        }
        return StoreReferences(desktopCount: desktops.count, displayDefault: displayDefault, newDesktopTemplate: template)
    }

    /// True if any string inside `value` (including inside nested property lists stored as data) holds `needle`.
    private static func contains(_ value: Any?, _ needle: String, depth: Int = 0) -> Bool {
        guard depth < 10, let value else { return false }
        switch value {
        case let string as String: return string.contains(needle)
        case let dictionary as [String: Any]: return dictionary.values.contains { contains($0, needle, depth: depth + 1) }
        case let array as [Any]: return array.contains { contains($0, needle, depth: depth + 1) }
        case let data as Data:
            if let nested = try? PropertyListSerialization.propertyList(from: data, format: nil) {
                return contains(nested, needle, depth: depth + 1)
            }
            return data.range(of: Data(needle.utf8)) != nil
        default: return false
        }
    }
}
