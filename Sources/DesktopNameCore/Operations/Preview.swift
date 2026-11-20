import CoreGraphics
import Foundation

/// What the editor asks to see: a label's text and options at the preview's width (spec 014, contracts/core-additions.md §1).
public struct PreviewRequest: Sendable {
    public var text: LabelText
    public var options: LabelOptions
    public var maxPixelWidth: Int

    public init(text: LabelText, options: LabelOptions, maxPixelWidth: Int) {
        self.text = text
        self.options = options
        self.maxPixelWidth = maxPixelWidth
    }
}

/// The image `setLabel` would stamp for one Desktop, composed for its display and scaled to the preview's width.
/// Load it once when the editor opens; every preview of that Desktop renders over it.
public struct PreviewSource: @unchecked Sendable {
    // Immutable after creation; CGImage is thread-safe to read.
    let backdrop: CGImage
    /// The display's geometry with the same points and a smaller scale, so the layout (in points) matches the full
    /// image and only the pixel density differs.
    let geometry: DisplayGeometry
    /// Made from the full-size backdrop, as `setLabel` makes it: judging a downscaled copy smooths out texture and
    /// chose a lighter automatic style in about one case in seven over the local samples (research R6, spike S2).
    let sampler: Sampler

    /// The preview's size in pixels.
    public var pixelWidth: Int { backdrop.width }
    public var pixelHeight: Int { backdrop.height }

    /// The Desktop's picture without a label, as the editor shows it before anything is typed.
    public var image: CGImage { backdrop }

    /// The same source at a smaller width (the editor's style chips), judged with the same full-size sample. Cheap:
    /// it scales this source's image, it does not load the wallpaper again.
    public func scaled(toWidth width: Int) -> PreviewSource {
        let geometry = DesktopLabeler.previewGeometry(self.geometry, maxPixelWidth: width)
        guard geometry.pixelWidth < backdrop.width,
              let context = CGContext(data: nil, width: geometry.pixelWidth, height: geometry.pixelHeight, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: backdrop.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return self }
        context.interpolationQuality = .high
        context.draw(backdrop, in: CGRect(x: 0, y: 0, width: geometry.pixelWidth, height: geometry.pixelHeight))
        guard let image = context.makeImage() else { return self }
        return PreviewSource(backdrop: image, geometry: geometry, sampler: sampler)
    }
}

extension DesktopLabeler {
    /// Loads the image `setLabel` would stamp for the Desktop on screen of `display` (the recorded original when the
    /// Desktop is labeled), composed for the display at no more than `maxPixelWidth`. Throws as `setLabel` would for
    /// a wallpaper that cannot be labeled, a missing original or a stamp from another store. Reads only.
    public func previewSource(on display: Display, maxPixelWidth: Int) throws -> PreviewSource {
        let current = try system.currentWallpaper(on: display)
        let (original, _) = try labelingSource(current, in: try store.readManifest())
        let base = try Backdrop.loadImage(at: try Self.resolve(original))
        let placement = Backdrop.Placement(Self.placement(of: original))
        // The full-size composition is made once, only to sample it, and then released.
        let sampler = Sampler(backdrop: try Backdrop.compose(base: base, placement: placement, geometry: display.geometry))
        let geometry = Self.previewGeometry(display.geometry, maxPixelWidth: maxPixelWidth)
        let backdrop = try Backdrop.compose(base: base, placement: placement, geometry: geometry)
        return PreviewSource(backdrop: backdrop, geometry: geometry, sampler: sampler)
    }

    /// The display's geometry scaled down to fit `maxPixelWidth` (never up).
    static func previewGeometry(_ geometry: DisplayGeometry, maxPixelWidth: Int) -> DisplayGeometry {
        var scaled = geometry
        let factor = min(1, Double(max(1, maxPixelWidth)) / Double(max(1, geometry.pixelWidth)))
        scaled.scale = geometry.scale * factor
        return scaled
    }
}

/// Renders previews with the same pipeline as `setLabel`.
public enum LabelPreview {
    /// The preview image and the label it would record, so the editor can show what Automatic chose. Pure; safe off
    /// the main thread.
    public static func render(_ request: PreviewRequest, source: PreviewSource) throws -> (image: CGImage, label: Label) {
        let rendered = try LabelRenderer.render(backdrop: source.backdrop, text: request.text, options: request.options,
                                                geometry: source.geometry, sampler: source.sampler)
        return (rendered.image, rendered.label)
    }
}
