import AppKit
import CoreImage
import Foundation

/// Layout and drawing of a single-line label, ported from the prototype
/// (plain, halo and frosted looks; the "pill" look and automatic position are not part of this spec).
package enum Painter {
    static let opacity: CGFloat = 0.85

    /// Font size as a fraction of the display height.
    static func heightFraction(for size: Size) -> CGFloat {
        switch size {
        case .small: 0.022
        case .medium: 0.030
        case .large: 0.040
        }
    }

    package struct Layout {
        package var box: CGRect          // points, origin bottom-left
        package var textRect: CGRect
        package var font: NSFont
        package var alignment: NSTextAlignment
    }

    package static func textAttributes(font: NSFont, alignment: NSTextAlignment) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byClipping
        return [.font: font, .kern: font.pointSize * 0.01, .paragraphStyle: paragraph]
    }

    static func alignment(for position: Position) -> NSTextAlignment {
        switch position {
        case .bottomRight, .topRight: .right
        case .bottom, .top: .center
        default: .left
        }
    }

    /// Places the label's box. The box always stays on screen, clear of the menu bar and Dock;
    /// a label too wide for the display is scaled down to fit.
    package static func layout(text: String, position: Position, size: Size, geometry: DisplayGeometry, look: Look) -> Layout {
        let width = CGFloat(geometry.pointWidth), height = CGFloat(geometry.pointHeight)
        let alignment = alignment(for: position)
        let backed = look == .frosted
        let margin = height * 0.035
        let availableWidth = max(1, width - CGFloat(geometry.insetLeft + geometry.insetRight) - margin * 2)

        var fontSize = height * heightFraction(for: size)
        func measure(_ fontSize: CGFloat) -> (font: NSFont, text: CGSize, padX: CGFloat, padY: CGFloat) {
            let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
            // Measure with exactly the attributes used to draw.
            let textSize = NSAttributedString(string: text, attributes: textAttributes(font: font, alignment: alignment))
                .boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                              options: [.usesLineFragmentOrigin, .usesFontLeading]).size
            return (font, textSize, backed ? fontSize * 0.55 : 0, backed ? fontSize * 0.3 : 0)
        }
        var measured = measure(fontSize)
        let boxWidth = ceil(measured.text.width) + 2 + measured.padX * 2
        if boxWidth > availableWidth {
            fontSize *= availableWidth / boxWidth * 0.99
            measured = measure(fontSize)
        }
        let box = CGSize(width: ceil(measured.text.width) + 2 + measured.padX * 2, height: ceil(measured.text.height) + measured.padY * 2)

        let left = CGFloat(geometry.insetLeft) + margin
        let right = width - CGFloat(geometry.insetRight) - margin - box.width
        let bottom = CGFloat(geometry.insetBottom) + margin
        let top = height - max(CGFloat(geometry.insetTop), 40) - margin - box.height
        let middle = (width - box.width) / 2
        let origin: CGPoint
        switch position {
        case .bottomLeft: origin = CGPoint(x: left, y: bottom)
        case .bottomRight: origin = CGPoint(x: right, y: bottom)
        case .bottom: origin = CGPoint(x: middle, y: bottom)
        case .topLeft: origin = CGPoint(x: left, y: top)
        case .topRight: origin = CGPoint(x: right, y: top)
        case .top: origin = CGPoint(x: middle, y: top)
        }
        // Clamp so the box is fully on screen even on tiny displays.
        let clamped = CGPoint(x: min(max(0, origin.x), max(0, width - box.width)),
                              y: min(max(0, origin.y), max(0, height - box.height)))
        let boxRect = CGRect(origin: clamped, size: box)
        return Layout(box: boxRect, textRect: boxRect.insetBy(dx: measured.padX, dy: measured.padY), font: measured.font, alignment: alignment)
    }

    /// Draws the label over the backdrop and returns the finished image.
    static func draw(backdrop: CGImage, text: String, treatment: Treatment, layout: Layout, geometry: DisplayGeometry) throws -> CGImage {
        let colorSpace = backdrop.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let context = try Backdrop.makeContext(width: backdrop.width, height: backdrop.height, colorSpace: colorSpace)
        context.draw(backdrop, in: CGRect(x: 0, y: 0, width: backdrop.width, height: backdrop.height))
        let scale = CGFloat(geometry.scale)
        let fontSize = layout.font.pointSize
        let radius = layout.box.height * 0.3

        if treatment.look == .frosted {
            // Blur what is behind the box, then tint it, like a macOS material.
            let pixelBox = CGRect(x: layout.box.minX * scale, y: layout.box.minY * scale, width: layout.box.width * scale, height: layout.box.height * scale)
            let blurred = CIImage(cgImage: backdrop).clampedToExtent()
                .applyingGaussianBlur(sigma: Double(fontSize * 0.5 * scale))
                .cropped(to: CGRect(x: 0, y: 0, width: backdrop.width, height: backdrop.height))
            if let blurImage = CIContext(options: [.workingColorSpace: colorSpace]).createCGImage(blurred, from: pixelBox) {
                context.saveGState()
                context.addPath(CGPath(roundedRect: pixelBox, cornerWidth: radius * scale, cornerHeight: radius * scale, transform: nil))
                context.clip()
                context.draw(blurImage, in: pixelBox)
                context.restoreGState()
            }
        }

        context.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }

        let light = treatment.lightText
        var attributes = textAttributes(font: layout.font, alignment: layout.alignment)
        switch treatment.textColor {
        case .custom(let red, let green, let blue): attributes[.foregroundColor] = NSColor(srgbRed: red, green: green, blue: blue, alpha: opacity)
        default: attributes[.foregroundColor] = light ? NSColor(white: 1, alpha: opacity) : NSColor(white: 0, alpha: opacity * 0.85)
        }

        switch treatment.look {
        case .frosted:
            let shape = NSBezierPath(roundedRect: layout.box, xRadius: radius, yRadius: radius)
            (light ? NSColor(white: 0, alpha: 0.28) : NSColor(white: 1, alpha: 0.40)).setFill()
            shape.fill()
            (light ? NSColor(white: 1, alpha: 0.12) : NSColor(white: 0, alpha: 0.08)).setStroke()
            shape.lineWidth = 1 / scale
            shape.stroke()
        case .plain, .halo:
            let shadow = NSShadow()
            let strong = treatment.look == .halo
            shadow.shadowColor = light ? NSColor(white: 0, alpha: strong ? 0.8 : 0.5) : NSColor(white: 1, alpha: strong ? 0.85 : 0.5)
            shadow.shadowBlurRadius = fontSize * (strong ? 0.4 : 0.22) * scale   // shadows ignore the CTM, so work in pixels
            shadow.shadowOffset = NSSize(width: 0, height: strong ? 0 : -fontSize * 0.03 * scale)
            attributes[.shadow] = shadow
        }
        NSAttributedString(string: text, attributes: attributes).draw(with: layout.textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        if treatment.look == .halo {
            // A second pass tightens the glow right around the letters.
            var tight = attributes
            let inner = NSShadow()
            inner.shadowColor = (attributes[.shadow] as? NSShadow)?.shadowColor
            inner.shadowBlurRadius = fontSize * 0.1 * scale
            tight[.shadow] = inner
            NSAttributedString(string: text, attributes: tight).draw(with: layout.textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        }

        guard let image = context.makeImage() else { throw DnmError.failure("Rendering failed.") }
        return image
    }
}
