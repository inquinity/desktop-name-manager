import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Generated images for tests. Committed tests never use personal wallpapers.
enum SyntheticImages {
    static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

    static func context(width: Int, height: Int) -> CGContext {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }

    static func solid(width: Int, height: Int, gray: CGFloat) -> CGImage {
        let ctx = context(width: width, height: height)
        ctx.setFillColor(CGColor(colorSpace: srgb, components: [gray, gray, gray, 1])!)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    static func bright(width: Int = 800, height: Int = 500) -> CGImage { solid(width: width, height: height, gray: 0.95) }
    static func dark(width: Int = 800, height: Int = 500) -> CGImage { solid(width: width, height: height, gray: 0.05) }
    static func midGray(width: Int = 800, height: Int = 500) -> CGImage { solid(width: width, height: height, gray: 0.5) }

    static func gradient(width: Int = 800, height: Int = 500) -> CGImage {
        let ctx = context(width: width, height: height)
        let colors = [CGColor(colorSpace: srgb, components: [0.05, 0.1, 0.4, 1])!,
                      CGColor(colorSpace: srgb, components: [0.95, 0.9, 0.7, 1])!] as CFArray
        let gradient = CGGradient(colorsSpace: srgb, colors: colors, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        return ctx.makeImage()!
    }

    /// Repeatable noise, for busy backdrops.
    static func noise(width: Int = 800, height: Int = 500, seed: UInt64 = 42) -> CGImage {
        var state = seed
        func next() -> UInt8 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return UInt8(truncatingIfNeeded: state >> 33)
        }
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for i in 0..<(width * height) {
            let v = next()
            pixels[i * 4] = v; pixels[i * 4 + 1] = v; pixels[i * 4 + 2] = v
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: srgb, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    @discardableResult
    static func write(_ image: CGImage, to url: URL, type: UTType = .png) throws -> URL {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return url
    }

    /// A two-frame TIFF, standing in for a dynamic wallpaper.
    @discardableResult
    static func writeMultiFrame(to url: URL) throws -> URL {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.tiff.identifier as CFString, 2, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, bright(width: 64, height: 40), nil)
        CGImageDestinationAddImage(destination, dark(width: 64, height: 40), nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return url
    }

    /// A fresh temporary directory, removed by the caller.
    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dnm-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
