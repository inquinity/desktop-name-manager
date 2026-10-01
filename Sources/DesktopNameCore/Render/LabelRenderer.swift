import CoreGraphics
import Foundation

/// The whole rendering pipeline behind one function: sample the backdrop, choose the look and text
/// color, lay the label out, and draw it.
enum LabelRenderer {
    struct Rendered {
        var image: CGImage
        var label: Label
    }

    static func render(backdrop: CGImage, text: LabelText, options: LabelOptions, geometry: DisplayGeometry) throws -> Rendered {
        let sampler = Sampler(backdrop: backdrop)
        let position = options.position ?? .default
        let size = options.size ?? .default

        // Judge a slightly larger area than the text itself; shadows and eyes spill over.
        let probe = Painter.layout(text: text.value, position: position, size: size, geometry: geometry, look: .frosted)
        let grown = probe.box.insetBy(dx: -probe.box.height * 0.4, dy: -probe.box.height * 0.4)
        let unit = CGRect(x: grown.minX / CGFloat(geometry.pointWidth), y: grown.minY / CGFloat(geometry.pointHeight),
                          width: grown.width / CGFloat(geometry.pointWidth), height: grown.height / CGFloat(geometry.pointHeight))
        let stats = sampler.stats(unit)
        let treatment = StylePicker.choose(stats, options: options)

        let layout = Painter.layout(text: text.value, position: position, size: size, geometry: geometry, look: treatment.look)
        let image = try Painter.draw(backdrop: backdrop, text: text.value, treatment: treatment, layout: layout, geometry: geometry)
        let label = Label(text: text, look: treatment.look, textColor: treatment.textColor, position: position, size: size,
                          automatic: treatment.automatic)
        return Rendered(image: image, label: label)
    }
}
