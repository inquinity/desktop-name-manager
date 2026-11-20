import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Whether a wallpaper can be labeled (FR-014). Decided from the file itself.
public enum WallpaperKind: Equatable, Sendable {
    case supported(URL)
    case unsupported(reason: String)

    /// Where macOS reports a stand-in still instead of the real wallpaper (spec 015). On macOS 27 an Apple dynamic
    /// wallpaper is reported as this file, an ordinary still that cannot be told apart by its contents.
    /// Knowing this undocumented location is a maintainer-approved deviation from constitution principle I
    /// (spec 015 Q1, plan Complexity Tracking): it is only compared with what the public reader reports, never
    /// opened, listed or followed. Revisit on each macOS release.
    static let standInLocations = [URL(fileURLWithPath: "/System/Library/CoreServices/DefaultDesktop.heic")]

    /// Classifies what a display currently shows.
    /// - Parameter standIns: locations refused as stand-ins; tests replace it (spec 015 FR-007).
    /// - Throws: `.accessDenied` or `.originalMissing` when the file cannot be read, with the system's wording.
    static func classify(_ current: CurrentWallpaper, standIns: [URL] = standInLocations) throws -> WallpaperKind {
        guard let url = current.url else {
            return .unsupported(reason: "the system reports no wallpaper file for this Desktop (it may be a solid color, a full-screen app, or a wallpaper type that is not supported)")
        }
        // Compared by location only, before anything is read (spec 015 FR-003, FR-004): normalized, links not followed.
        // A different spelling macOS does not report (another letter case, a file reference URL) is not matched and
        // falls through to the 0.3.0 behavior.
        let path = url.standardizedFileURL.path
        if standIns.contains(where: { $0.standardizedFileURL.path == path }) {
            return .unsupported(reason: "macOS reports the default wallpaper when dynamic or unsupported wallpapers are selected")
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
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return .unsupported(reason: "\(url.lastPathComponent) is not an image the tool can read")
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
