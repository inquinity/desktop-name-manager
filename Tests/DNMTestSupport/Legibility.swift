import AppKit
import CoreGraphics
import DesktopNameCore
import Foundation
@testable import DesktopNameCore

/// The legibility measure from the spec (SC-002): in the finished image, the text has a contrast
/// ratio of at least 3:1 against the pixels directly behind it, for at least 95% of them,
/// after any halo or frosted backing. Used by the unit tests and the local snapshot sweep.
public enum Legibility {
    public static let requiredRatio = 3.0
    public static let requiredShare = 0.95

    public struct Evaluation {
        public var share: Double
        public var label: Label
        /// Mean absolute difference (0...1) between the finished image, after JPEG encoding, and the
        /// composed backdrop, measured away from the label (research R7, scenario 18).
        public var jpegDifference: Double
    }

    /// Renders a label over `backdrop` with the product's own pipeline and measures the result.
    public static func evaluate(backdrop: CGImage, text: LabelText, options: LabelOptions, geometry: DisplayGeometry) throws -> Evaluation {
        let rendered = try LabelRenderer.render(backdrop: backdrop, text: text, options: options, geometry: geometry)
        let layout = Painter.layout(text: text.value, position: rendered.label.position, size: rendered.label.size,
                                    geometry: geometry, look: rendered.label.look)
        let share = try legibleShare(image: rendered.image, label: rendered.label, layout: layout, geometry: geometry)
        let difference = try jpegDifference(backdrop: backdrop, finished: rendered.image, layout: layout, geometry: geometry)
        return Evaluation(share: share, label: rendered.label, jpegDifference: difference)
    }

    /// The wallpaper composed for a display, as the tool would see it (scale to fill, black behind).
    public static func backdrop(for wallpaper: URL, geometry: DisplayGeometry) throws -> CGImage {
        let base = try Backdrop.loadImage(at: wallpaper)
        let placement = WallpaperPlacement(scaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue, clipping: true, fillColor: nil)
        return try Backdrop.compose(base: base, placement: Backdrop.Placement(placement), geometry: geometry)
    }

    // MARK: - Measurement

    /// Pixels as sRGB bytes, rows running top to bottom.
    private static func pixels(of image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                    bytesPerRow: image.width * 4, space: srgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    private static func linear(_ value: UInt8) -> Double {
        let channel = Double(value) / 255
        return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    static func legibleShare(image: CGImage, label: Label, layout: Painter.Layout, geometry: DisplayGeometry) throws -> Double {
        let text = label.text.value
        let width = image.width, height = image.height
        let scale = CGFloat(geometry.scale)

        // Mask: same layout, white text on black. Glyph pixels are excluded from the measure.
        let maskContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        maskContext.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: maskContext, flipped: false)
        var attributes = Painter.textAttributes(font: layout.font, alignment: layout.alignment)
        attributes[.foregroundColor] = NSColor.white
        NSAttributedString(string: text, attributes: attributes).draw(with: layout.textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.restoreGraphicsState()
        let mask = maskContext.data!.assumingMemoryBound(to: UInt8.self)

        let bytes = pixels(of: image)
        let textLuminance: Double = {
            switch label.textColor {
            case .light: return 1
            case .dark: return 0
            case .custom(let red, let green, let blue): return 0.2126 * red + 0.7152 * green + 0.0722 * blue
            }
        }()

        let box = CGRect(x: layout.box.minX * scale, y: layout.box.minY * scale, width: layout.box.width * scale, height: layout.box.height * scale)
        var total = 0, legible = 0
        for pixelY in Int(box.minY)..<min(height, Int(box.maxY.rounded(.up))) {
            for pixelX in Int(box.minX)..<min(width, Int(box.maxX.rounded(.up))) {
                let rowFromTop = height - 1 - pixelY   // context rows count from the bottom
                if mask[rowFromTop * width + pixelX] > 0 { continue }
                let offset = (rowFromTop * width + pixelX) * 4
                let luminance = 0.2126 * linear(bytes[offset]) + 0.7152 * linear(bytes[offset + 1]) + 0.0722 * linear(bytes[offset + 2])
                let ratio = (max(luminance, textLuminance) + 0.05) / (min(luminance, textLuminance) + 0.05)
                total += 1
                if ratio >= requiredRatio { legible += 1 }
            }
        }
        return total == 0 ? 0 : Double(legible) / Double(total)
    }

    static func jpegDifference(backdrop: CGImage, finished: CGImage, layout: Painter.Layout, geometry: DisplayGeometry) throws -> Double {
        let data = try ImageWriter.encode(finished)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw DnmError.failure("cannot decode the encoded stamp")
        }
        let a = pixels(of: backdrop), b = pixels(of: decoded)
        let width = backdrop.width, height = backdrop.height
        let scale = CGFloat(geometry.scale)
        let keepOut = layout.box.insetBy(dx: -layout.box.height, dy: -layout.box.height)
        var sum = 0.0, count = 0.0
        // Every 4th pixel is plenty for a mean.
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                let pointX = CGFloat(x) / scale, pointY = CGFloat(height - 1 - y) / scale
                if keepOut.contains(CGPoint(x: pointX, y: pointY)) { continue }
                let offset = (y * width + x) * 4
                sum += (abs(Double(a[offset]) - Double(b[offset])) + abs(Double(a[offset + 1]) - Double(b[offset + 1])) + abs(Double(a[offset + 2]) - Double(b[offset + 2]))) / (3 * 255)
                count += 1
            }
        }
        return count == 0 ? 0 : sum / count
    }
}
