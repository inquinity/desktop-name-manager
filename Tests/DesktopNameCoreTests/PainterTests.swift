import CoreGraphics
import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct PainterTests {
    let geometry = DisplayGeometry(pointWidth: 800, pointHeight: 500, scale: 1, insetTop: 30, insetLeft: 0, insetBottom: 60, insetRight: 0)

    func screen(_ geometry: DisplayGeometry) -> CGRect { CGRect(x: 0, y: 0, width: geometry.pointWidth, height: geometry.pointHeight) }

    @Test(arguments: Position.allCases)
    func everyPositionKeepsTheBoxOnScreenClearOfTheMenuBarAndDock(_ position: Position) {
        for look in Look.allCases {
            let layout = Painter.layout(text: "Status Report", position: position, size: .large, geometry: geometry, look: look)
            #expect(screen(geometry).contains(layout.box), "\(position) \(look): \(layout.box)")
            #expect(layout.box.minY >= geometry.insetBottom - 0.5)
            #expect(layout.box.maxY <= geometry.pointHeight - geometry.insetTop + 0.5)
        }
    }

    @Test func aThirtyCharacterLabelAtLargeStaysOnTheSmallestDisplay() throws {
        let tiny = DisplayGeometry(pointWidth: 160, pointHeight: 600, scale: 1, insetTop: 24, insetBottom: 20)   // narrow: the text cannot fit at full size
        let text = String(repeating: "W", count: 30)
        _ = try LabelText(text)   // exactly at the limit is accepted
        let layout = Painter.layout(text: text, position: .bottomRight, size: .large, geometry: tiny, look: .frosted)
        #expect(screen(tiny).contains(layout.box))
        #expect(layout.font.pointSize < tiny.pointHeight * Painter.heightFraction(for: .large))   // scaled down to fit
    }

    @Test func emojiDrawWithoutClipping() throws {
        let backdrop = SyntheticImages.midGray()
        let text = try LabelText("Mail ✉️ 🎉")
        let result = try LabelRenderer.render(backdrop: backdrop, text: text, options: LabelOptions(look: .plain, textColor: .light), geometry: geometry)
        let layout = Painter.layout(text: text.value, position: .bottomLeft, size: .medium, geometry: geometry, look: .plain)

        // The measured text fits inside its rectangle, and something was drawn there.
        let measured = NSAttributedString(string: text.value, attributes: Painter.textAttributes(font: layout.font, alignment: layout.alignment)).size()
        #expect(measured.width <= layout.textRect.width + 2)
        #expect(measured.height <= layout.textRect.height + 2)
        #expect(try Self.differs(result.image, from: backdrop, inside: layout.box, geometry: geometry))
        // Nothing was drawn far from the label.
        let farAway = CGRect(x: 400, y: 300, width: 300, height: 150)
        #expect(try !Self.differs(result.image, from: backdrop, inside: farAway, geometry: geometry))
    }

    /// True if any pixel inside `rect` (points, origin bottom-left) differs between the two images.
    static func differs(_ a: CGImage, from b: CGImage, inside rect: CGRect, geometry: DisplayGeometry) throws -> Bool {
        func bytes(_ image: CGImage) -> [UInt8] {
            var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
            data.withUnsafeMutableBytes { buffer in
                CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
                    .draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            return data
        }
        let first = bytes(a), second = bytes(b), height = a.height, width = a.width
        let scale = CGFloat(geometry.scale)
        for pixelY in Int(rect.minY * scale)..<min(height, Int((rect.maxY * scale).rounded(.up))) {
            for pixelX in Int(rect.minX * scale)..<min(width, Int((rect.maxX * scale).rounded(.up))) {
                let offset = ((height - 1 - pixelY) * width + pixelX) * 4
                if abs(Int(first[offset]) - Int(second[offset])) > 3 { return true }
            }
        }
        return false
    }
}
