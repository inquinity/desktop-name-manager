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

/// Which picture a preview is made from: the Desktop's original and the display's geometry (spec 014). Made on the
/// thread that may read the wallpaper system; turned into a `PreviewSource` on any thread.
public struct PreviewOrigin: Sendable {
    let original: Original
    let geometry: DisplayGeometry
}

extension DesktopLabeler {
    /// Loads the image `setLabel` would stamp for the Desktop on screen of `display` (the recorded original when the
    /// Desktop is labeled), composed for the display at no more than `maxPixelWidth`. Throws as `setLabel` would for
    /// a wallpaper that cannot be labeled, a missing original or a stamp from another store. Reads only.
    public func previewSource(on display: Display, maxPixelWidth: Int) throws -> PreviewSource {
        try Self.previewSource(from: previewOrigin(on: display), maxPixelWidth: maxPixelWidth)
    }

    /// The cheap half of `previewSource(on:maxPixelWidth:)`: which picture the preview is made from. It reads the
    /// wallpaper system, so it runs where that system may be used (the main thread for the real one); the expensive
    /// half, `previewSource(from:maxPixelWidth:)`, can then run on any thread. Throws as `previewSource` does.
    public func previewOrigin(on display: Display) throws -> PreviewOrigin {
        let current = try system.currentWallpaper(on: display)
        let (original, _) = try labelingSource(current, in: try store.readManifest())
        return PreviewOrigin(original: original, geometry: display.geometry)
    }

    /// Loads and composes the picture of `origin`. Touches neither the wallpaper system nor the store, so it is safe
    /// off the main thread.
    public static func previewSource(from origin: PreviewOrigin, maxPixelWidth: Int) throws -> PreviewSource {
        let base = try Backdrop.loadImage(at: try resolve(origin.original))
        let placement = Backdrop.Placement(placement(of: origin.original))
        // The full-size composition is made once, only to sample it, and then released.
        let sampler = Sampler(backdrop: try Backdrop.compose(base: base, placement: placement, geometry: origin.geometry))
        let geometry = previewGeometry(origin.geometry, maxPixelWidth: maxPixelWidth)
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
