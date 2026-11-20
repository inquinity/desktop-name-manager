import CoreGraphics
import Foundation
import Testing
@testable import DesktopNameCore
import DNMTestSupport

/// The editor's preview (spec 014, contracts/core-additions.md §1): the same choices as `setLabel`, over the same image.
@Suite struct PreviewTests {
    static let backdrops: [(String, CGImage)] = [
        ("light", SyntheticImages.bright()), ("dark", SyntheticImages.dark()), ("busy", SyntheticImages.noise()),
    ]

    @Test(arguments: [0, 1, 2], [Position.bottomLeft, .top, .bottomRight])
    func choosesWhatSetLabelChooses(_ index: Int, _ position: Position) throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal(Self.backdrops[index].1)
        let text = try LabelText("Q4 budget")
        let options = LabelOptions(position: position)

        let source = try h.labeler.previewSource(on: h.display, maxPixelWidth: 800)
        let preview = try LabelPreview.render(PreviewRequest(text: text, options: options, maxPixelWidth: 800), source: source)
        let applied = try h.labeler.setLabel(text, options: options, on: h.display)

        #expect(preview.label == applied.label, "\(Self.backdrops[index].0) at \(position)")
    }

    @Test func aSmallerPreviewIsScaledDownWithTheSameAspect() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        let source = try h.labeler.previewSource(on: h.display, maxPixelWidth: 400)
        #expect(source.pixelWidth == 400 && source.pixelHeight == 250)
        let preview = try LabelPreview.render(PreviewRequest(text: LabelText("Q4 budget"), options: LabelOptions(), maxPixelWidth: 400),
                                              source: source)
        #expect(preview.image.width == 400 && preview.image.height == 250)
    }

    @Test func aPreviewIsNeverLargerThanTheDisplay() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        let source = try h.labeler.previewSource(on: h.display, maxPixelWidth: 5_000)
        #expect(source.pixelWidth == 800)
    }

    @Test func aLabeledDesktopPreviewsOverItsOriginalNotTheStamp() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal(SyntheticImages.bright())
        try h.labeler.setLabel(LabelText("Q4 budget"), options: LabelOptions(look: .frosted), on: h.display)

        let source = try h.labeler.previewSource(on: h.display, maxPixelWidth: 800)
        // The original is a flat light gray everywhere; the stamp would have the frosted label in it.
        #expect(Self.isFlat(source.backdrop))
    }

    @Test func anUnsupportedWallpaperThrowsAsSetLabelDoes() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let url = try SyntheticImages.writeMultiFrame(to: h.root.appendingPathComponent("Dynamic.tiff"))
        h.system.show(url, on: h.display)
        #expect(throws: DnmError.unsupportedWallpaper("it holds several images (a dynamic wallpaper)")) {
            try h.labeler.previewSource(on: h.display, maxPixelWidth: 400)
        }
        h.system.show(nil, on: h.display)
        #expect(throws: DnmError.noWallpaperFile) { try h.labeler.previewSource(on: h.display, maxPixelWidth: 400) }
    }

    @Test func itChangesNothing() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        _ = try h.labeler.previewSource(on: h.display, maxPixelWidth: 400)
        #expect(h.system.setCalls.isEmpty)
        #expect(!h.store.hasManifest)
        #expect(h.storeFiles.isEmpty)
    }

    @Test func rendersOffTheMainThread() async throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        let source = try h.labeler.previewSource(on: h.display, maxPixelWidth: 400)
        let request = PreviewRequest(text: try LabelText("Q4 budget"), options: LabelOptions(), maxPixelWidth: 400)
        let (width, onMain) = try await Task.detached(priority: .userInitiated) {
            try Self.renderNoting(request, source: source)
        }.value
        #expect(width == 400)
        #expect(!onMain)
    }

    /// Renders and says whether it ran on the main thread (synchronous, so it may ask).
    static func renderNoting(_ request: PreviewRequest, source: PreviewSource) throws -> (Int, Bool) {
        (try LabelPreview.render(request, source: source).image.width, Thread.isMainThread)
    }

    /// True when every sampled pixel has the same color (a solid image).
    static func isFlat(_ image: CGImage) -> Bool {
        let width = image.width, height = image.height
        let context = SyntheticImages.context(width: width, height: height)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return false }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        let first = (pixels[0], pixels[1], pixels[2])
        for y in stride(from: 0, to: height, by: 7) {
            for x in stride(from: 0, to: width, by: 7) {
                let i = (y * width + x) * 4
                if abs(Int(pixels[i]) - Int(first.0)) > 2 || abs(Int(pixels[i + 1]) - Int(first.1)) > 2 ||
                    abs(Int(pixels[i + 2]) - Int(first.2)) > 2 { return false }
            }
        }
        return true
    }
}
