import AppKit
import CoreGraphics
import Foundation
import ImageIO

/// Loading the wallpaper and composing it exactly as macOS shows it on a display.
enum Backdrop {
    /// The system's placement options as drawing values.
    struct Placement {
        var scaling: NSImageScaling
        var clipping: Bool
        var fill: NSColor?

        init(_ placement: WallpaperPlacement) {
            scaling = NSImageScaling(rawValue: placement.scaling) ?? .scaleProportionallyUpOrDown
            clipping = placement.clipping
            fill = placement.fillColor.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: $0) }
        }
    }

    /// Reads an image file with EXIF orientation applied. Access problems carry the system's message.
    static func loadImage(at url: URL) throws -> CGImage {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            try handle.close()
        } catch {
            throw mapReadError(error, url: url)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw DnmError.failure("Cannot read the image \(url.lastPathComponent).")
        }
        let index = CGImageSourceGetPrimaryImageIndex(source)
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw DnmError.failure("Cannot read the size of the image \(url.lastPathComponent).")
        }
        // A full-size "thumbnail" is the simplest way to get the orientation applied.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else {
            throw DnmError.failure("Cannot decode the image \(url.lastPathComponent).")
        }
        return image
    }

    /// Turns a file-read failure into the tool's error, keeping the system's own wording for denials.
    static func mapReadError(_ error: Error, url: URL) -> DnmError {
        let nsError = error as NSError
        let denied = (nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError)
            || (nsError.domain == NSPOSIXErrorDomain && (nsError.code == Int(EACCES) || nsError.code == Int(EPERM)))
            || ((nsError.userInfo[NSUnderlyingErrorKey] as? NSError).map { $0.domain == NSPOSIXErrorDomain && ($0.code == Int(EACCES) || $0.code == Int(EPERM)) } ?? false)
        if denied { return .accessDenied(error.localizedDescription) }
        if nsError.domain == NSCocoaErrorDomain && (nsError.code == NSFileReadNoSuchFileError || nsError.code == NSFileNoSuchFileError) {
            return .originalMissing(url.lastPathComponent)
        }
        return .failure("Cannot read \(url.lastPathComponent): \(error.localizedDescription)")
    }

    /// Where the wallpaper image lands on a canvas, mirroring macOS's placement options.
    static func imageRect(image: CGSize, canvas: CGSize, placement: Placement) -> CGRect {
        let fitScale = min(canvas.width / image.width, canvas.height / image.height)
        let fillScale = max(canvas.width / image.width, canvas.height / image.height)
        let scale: CGFloat
        switch placement.scaling {
        case .scaleAxesIndependently: return CGRect(origin: .zero, size: canvas)
        case .scaleNone: scale = 1
        case .scaleProportionallyDown: scale = min(1, fitScale)
        default: scale = placement.clipping ? fillScale : fitScale
        }
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    static func makeContext(width: Int, height: Int, colorSpace: CGColorSpace) throws -> CGContext {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            throw DnmError.failure("Cannot create a \(width)x\(height) drawing surface.")
        }
        context.interpolationQuality = .high
        return context
    }

    /// The wallpaper exactly as macOS would show it on this display, at the display's pixel size.
    static func compose(base: CGImage, placement: Placement, geometry: DisplayGeometry) throws -> CGImage {
        let colorSpace = base.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let context = try makeContext(width: geometry.pixelWidth, height: geometry.pixelHeight, colorSpace: colorSpace)
        let canvas = CGSize(width: geometry.pixelWidth, height: geometry.pixelHeight)
        context.setFillColor((placement.fill ?? .black).usingColorSpace(.sRGB)?.cgColor ?? NSColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: canvas))
        context.draw(base, in: imageRect(image: CGSize(width: base.width, height: base.height), canvas: canvas, placement: placement))
        guard let image = context.makeImage() else { throw DnmError.failure("Rendering failed.") }
        return image
    }
}
