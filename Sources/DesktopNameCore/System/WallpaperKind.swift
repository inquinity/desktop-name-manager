import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Whether a wallpaper can be labeled (FR-014). Decided from the file itself.
public enum WallpaperKind: Equatable, Sendable {
    case supported(URL)
    case unsupported(reason: String)
    /// The system reports no wallpaper file: a solid color, a full-screen app's Space, or a type with no file.
    case noFile
    /// The file is there but is not a picture ImageIO can read; carries its file name.
    case unreadable(name: String)

    /// Classifies what a display currently shows.
    /// - Throws: `.accessDenied` or `.originalMissing` when the file cannot be read, with the system's wording.
    static func classify(_ current: CurrentWallpaper) throws -> WallpaperKind {
        guard let url = current.url else {
            return .noFile
        }
        if url.pathExtension.lowercased() == "madesktop" {
            return .unsupported(reason: "it is an Apple catalog wallpaper")
        }
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
        if values?.isDirectory == true {
            return .unsupported(reason: "it is a folder of pictures (a shuffling wallpaper)")
        }
        if let type = values?.contentType, type.conforms(to: .movie) || type.conforms(to: .audiovisualContent) {
            return .unsupported(reason: "it is a video (an aerial wallpaper)")
        }

        do {
            let handle = try FileHandle(forReadingFrom: url)
            try handle.close()
        } catch {
            throw Backdrop.mapReadError(error, url: url)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetType(source) != nil else {
            return .unreadable(name: url.lastPathComponent)
        }
        if CGImageSourceGetCount(source) > 1 {
            return .unsupported(reason: "it holds several images (a dynamic wallpaper)")
        }
        if let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
           let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag],
           tags.contains(where: { CGImageMetadataTagCopyPrefix($0) as String? == "apple_desktop" }) {
            return .unsupported(reason: "it carries dynamic wallpaper metadata")
        }
        return .supported(url)
    }
}
