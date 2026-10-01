import CoreGraphics
import Foundation

/// Statistics about the area a label would cover.
struct RegionStats: Equatable {
    var meanLuminance: Double   // WCAG relative luminance
    var busyness: Double        // mean change in lightness between neighbouring samples
    var badWhite: Double        // share of the area where white text would fall under 3:1 contrast
    var badBlack: Double        // same for black text
}

/// A small sRGB copy of the backdrop, for judging how legible a label would be at its spot.
struct Sampler {
    let width: Int, height: Int
    let luminance: [Float]       // WCAG relative luminance, 0...1
    let lightness: [Float]       // CIE L*, 0...1

    init(backdrop: CGImage) {
        let width = 1024
        let height = max(1, Int((Double(backdrop.height) * 1024 / Double(backdrop.width)).rounded()))
        self.width = width
        self.height = height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: srgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            context.interpolationQuality = .medium
            context.draw(backdrop, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let linear = (0..<256).map { value -> Float in
            let channel = Float(value) / 255
            return channel <= 0.04045 ? channel / 12.92 : powf((channel + 0.055) / 1.055, 2.4)
        }
        var luminanceValues = [Float](repeating: 0, count: width * height)
        var lightnessValues = luminanceValues
        for index in 0..<(width * height) {
            let y = 0.2126 * linear[Int(pixels[index * 4])] + 0.7152 * linear[Int(pixels[index * 4 + 1])] + 0.0722 * linear[Int(pixels[index * 4 + 2])]
            luminanceValues[index] = y
            lightnessValues[index] = (y > 0.008856 ? 1.16 * cbrtf(y) - 0.16 : 9.033 * y)
        }
        luminance = luminanceValues
        lightness = lightnessValues
    }

    /// Statistics for a rectangle given as fractions of the screen, origin at the bottom left.
    func stats(_ unit: CGRect) -> RegionStats {
        let x0 = max(0, Int(unit.minX * CGFloat(width))), x1 = min(width - 1, Int(unit.maxX * CGFloat(width)))
        let y0 = max(0, Int((1 - unit.maxY) * CGFloat(height))), y1 = min(height - 1, Int((1 - unit.minY) * CGFloat(height)))
        var sum: Float = 0, gradient: Float = 0, badWhite = 0, badBlack = 0, samples = 0
        for y in y0...max(y0, y1) {
            for x in x0...max(x0, x1) {
                let index = y * width + x
                let value = luminance[index]
                sum += value; samples += 1
                if x < x1 && y < y1 {
                    gradient += abs(lightness[index + 1] - lightness[index]) + abs(lightness[index + width] - lightness[index])
                }
                if 1.05 / (value + 0.05) < 3 { badWhite += 1 }        // white text contrast under 3:1
                if (value + 0.05) / 0.05 < 3 { badBlack += 1 }        // black text contrast under 3:1
            }
        }
        let count = Float(max(samples, 1))
        let mean = sum / count
        return RegionStats(meanLuminance: Double(mean), busyness: Double(gradient / count), badWhite: Double(badWhite) / Double(count),
                           badBlack: Double(badBlack) / Double(count))
    }
}
