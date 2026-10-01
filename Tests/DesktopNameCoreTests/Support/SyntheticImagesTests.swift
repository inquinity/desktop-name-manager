import ImageIO
import Foundation
import Testing

@Suite struct SyntheticImagesTests {
    @Test func generatorsProduceExpectedSizes() throws {
        #expect(SyntheticImages.bright().width == 800)
        #expect(SyntheticImages.noise(width: 100, height: 50).height == 50)
    }

    @Test func multiFrameFileHasTwoFrames() throws {
        let dir = try SyntheticImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try SyntheticImages.writeMultiFrame(to: dir.appendingPathComponent("m.tiff"))
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        #expect(CGImageSourceGetCount(source) == 2)
    }
}
