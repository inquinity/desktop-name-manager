import CoreGraphics
import DesktopNameCore
import DNMTestSupport
import Foundation
import Testing

/// The editor's preview against the full render (spec 014, constitution VII, research R6). Local only: runs over the
/// untracked `wallpaper-samples/` folder on a 5K display, and reports as skipped when the folder is absent. For every
/// sample, position and size, the preview at the editor's width must choose the same automatic look and text color as
/// `setLabel`'s full-size render, and put the label in the same place (within one preview pixel).
/// Run with `just test --filter PreviewSnapshot`.
@Suite struct PreviewSnapshotTests {
    /// The editor's preview width in pixels (about 400 points on a 2x display).
    static let previewWidth = 800

    @Test(.enabled(if: LegibilitySweepTests.samplesDirectory != nil))
    func previewsAgreeWithTheFullRender() throws {
        let files = LegibilitySweepTests.samples()
        try #require(!files.isEmpty, "wallpaper-samples/ holds no images")
        let geometry = LegibilitySweepTests.geometry
        let display = Display(name: "Studio Display", uuid: "DISPLAY-5K", isMain: true, geometry: geometry)
        let text = try LabelText("Status Report")
        var disagreements: [String] = []
        var placement: [String] = []
        var slowest = 0.0, compared = 0

        for (index, file) in files.enumerated() {
            let system = FakeWallpaperSystem(displays: [display])
            system.show(file, placement: WallpaperPlacement(scaling: 3, clipping: true, fillColor: nil), on: display)
            let root = try SyntheticImages.temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            let labeler = DesktopLabeler(system: system, store: Store(directory: root.appendingPathComponent("store", isDirectory: true)))
            let source = try labeler.previewSource(on: display, maxPixelWidth: Self.previewWidth)
            let full = try Legibility.backdrop(for: file, geometry: geometry)

            for position in Position.allCases {
                for size in Size.allCases {
                    let options = LabelOptions(position: position, size: size)
                    let started = Date()
                    let preview = try LabelPreview.render(PreviewRequest(text: text, options: options, maxPixelWidth: Self.previewWidth),
                                                          source: source)
                    slowest = max(slowest, Date().timeIntervalSince(started))
                    let applied = try LabelRenderer.render(backdrop: full, text: text, options: options, geometry: geometry)
                    compared += 1
                    let name = "sample \(index + 1) \(position.rawValue) \(size.rawValue)"
                    if preview.label.look != applied.label.look || preview.label.textColor != applied.label.textColor {
                        disagreements.append("\(name): preview \(preview.label.look)/\(preview.label.textColor), applied \(applied.label.look)/\(applied.label.textColor)")
                    }
                    // The label's box, in pixels of each image, compared at preview scale.
                    let factor = Double(source.pixelWidth) / Double(geometry.pixelWidth)
                    let previewGeometry = DisplayGeometry(pointWidth: geometry.pointWidth, pointHeight: geometry.pointHeight,
                                                          scale: geometry.scale * factor, insetTop: geometry.insetTop,
                                                          insetLeft: geometry.insetLeft, insetBottom: geometry.insetBottom,
                                                          insetRight: geometry.insetRight)
                    let small = Painter.layout(text: text.value, position: position, size: size, geometry: previewGeometry,
                                               look: preview.label.look).box
                    let large = Painter.layout(text: text.value, position: position, size: size, geometry: geometry,
                                               look: preview.label.look).box
                    let s = previewGeometry.scale, l = geometry.scale * factor
                    let offsets = [small.minX * s - large.minX * l, small.minY * s - large.minY * l,
                                   small.width * s - large.width * l, small.height * s - large.height * l]
                    if offsets.contains(where: { abs($0) > 1 }) { placement.append(name) }
                }
            }
        }
        print("preview snapshot: \(files.count) samples, \(compared) comparisons, \(disagreements.count) automatic-style disagreements, slowest preview \(String(format: "%.0f", slowest * 1000)) ms")
        disagreements.forEach { print("  disagreement: \($0)") }
        #expect(disagreements.isEmpty, "The preview chose a different automatic style: \(disagreements.joined(separator: "; "))")
        #expect(placement.isEmpty, "The label's place differs by more than one preview pixel: \(placement.joined(separator: "; "))")
    }
}
