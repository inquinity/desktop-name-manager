import AppKit
import CoreGraphics
import Foundation
@testable import DesktopNameCore

/// The legibility measure from the spec (SC-002): in the finished image, the text has a contrast
/// ratio of at least 3:1 against the pixels directly behind it, for at least 95% of them,
/// after any halo or frosted backing.
enum Legibility {
    static let requiredRatio = 3.0
    static let requiredShare = 0.95

    /// The share of background pixels inside the label's box that meet the contrast ratio.
    /// Glyph pixels are found by drawing the same text, in white, onto black, and excluded.
    static func legibleShare(image: CGImage, rendered: LabelRenderer.Rendered, geometry: DisplayGeometry) throws -> Double {
        let text = rendered.label.text.value
        let layout = Painter.layout(text: text, position: rendered.label.position, size: rendered.label.size,
                                    geometry: geometry, look: rendered.label.look)
        let width = image.width, height = image.height
        let scale = CGFloat(geometry.scale)

        // Mask: same layout, white text on black.
        let gray = CGColorSpaceCreateDeviceGray()
        let maskContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: gray,
                                    bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        maskContext.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: maskContext, flipped: false)
        var attributes = Painter.textAttributes(font: layout.font, alignment: layout.alignment)
        attributes[.foregroundColor] = NSColor.white
        NSAttributedString(string: text, attributes: attributes).draw(with: layout.textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.restoreGraphicsState()
        let mask = maskContext.data!.assumingMemoryBound(to: UInt8.self)

        // Finished image as sRGB bytes.
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: srgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        func linear(_ value: UInt8) -> Double {
            let channel = Double(value) / 255
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let textLuminance: Double = {
            switch rendered.label.textColor {
            case .light: return 1
            case .dark: return 0
            case .custom(let red, let green, let blue): return 0.2126 * red + 0.7152 * green + 0.0722 * blue
            }
        }()

        let box = CGRect(x: layout.box.minX * scale, y: layout.box.minY * scale, width: layout.box.width * scale, height: layout.box.height * scale)
        var total = 0, legible = 0
        for pixelY in Int(box.minY)..<min(height, Int(box.maxY.rounded(.up))) {
            for pixelX in Int(box.minX)..<min(width, Int(box.maxX.rounded(.up))) {
                // Context rows count from the bottom; the bytes in memory run top to bottom.
                let rowFromTop = height - 1 - pixelY
                if mask[rowFromTop * width + pixelX] > 0 { continue }
                let offset = (rowFromTop * width + pixelX) * 4
                let luminance = 0.2126 * linear(pixels[offset]) + 0.7152 * linear(pixels[offset + 1]) + 0.0722 * linear(pixels[offset + 2])
                let ratio = (max(luminance, textLuminance) + 0.05) / (min(luminance, textLuminance) + 0.05)
                total += 1
                if ratio >= requiredRatio { legible += 1 }
            }
        }
        return total == 0 ? 0 : Double(legible) / Double(total)
    }
}
