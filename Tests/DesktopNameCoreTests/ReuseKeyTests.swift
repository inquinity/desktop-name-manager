import Foundation
import Testing
@testable import DesktopNameCore

/// Spec 009: what makes two label requests "the same", so that an existing image can be used again.
@Suite struct ReuseKeyTests {
    let display = FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "DISPLAY-A", isMain: true)

    func key(original: Original = Fixtures.original(), url: URL? = nil, text: String = "Mail", options: LabelOptions = LabelOptions(),
             display: Display? = nil) throws -> String {
        ReuseKey.make(original: original, originalURL: url, text: try LabelText(text), options: options, display: display ?? self.display)
    }

    @Test func theSameRequestHasTheSameKey() throws {
        #expect(try key() == key())
        #expect(try key().count == 64 && key().allSatisfy(\.isHexDigit))
    }

    @Test func eachPartOfTheRequestChangesTheKey() throws {
        let base = try key()
        #expect(try key(text: "Notes") != base)
        #expect(try key(options: LabelOptions(look: .halo)) != base)
        #expect(try key(options: LabelOptions(textColor: .dark)) != base)
        #expect(try key(options: LabelOptions(position: .topRight)) != base)
        #expect(try key(options: LabelOptions(size: .large)) != base)
        #expect(try key(original: Fixtures.original(path: "/tmp/other.png")) != base)
        #expect(try key(original: Original(path: "/tmp/original.png", bookmark: nil, scaling: 1, clipping: true, fillColor: nil)) != base)
        #expect(try key(original: Original(path: "/tmp/original.png", bookmark: nil, scaling: 3, clipping: false, fillColor: nil)) != base)
        #expect(try key(original: Original(path: "/tmp/original.png", bookmark: nil, scaling: 3, clipping: true, fillColor: Data([1, 2]))) != base)
    }

    @Test func theDisplayAndItsSizeAreInTheKey() throws {
        let base = try key()
        #expect(try key(display: FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "DISPLAY-B", isMain: true)) != base)
        #expect(try key(display: FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "DISPLAY-A", isMain: true, width: 1920, height: 1080)) != base)
        #expect(try key(display: FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "DISPLAY-A", isMain: true, scale: 1)) != base)
        // A display's name is not part of it.
        #expect(try key(display: FakeWallpaperSystem.makeDisplay(name: "Renamed", uuid: "DISPLAY-A", isMain: true)) == base)
    }

    @Test func automaticIsNotTheSameAsAnExplicitChoice() throws {
        #expect(try key(options: LabelOptions()) != key(options: LabelOptions(look: .plain)))
    }

    @Test func theOriginalFileContentsAreInTheKey() throws {
        let root = try SyntheticImages.temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let url = try SyntheticImages.write(SyntheticImages.gradient(), to: root.appendingPathComponent("a.png"))
        let before = try key(url: url)
        #expect(try key(url: url) == before)
        // A different image at the same path: its size and modification time differ.
        _ = try SyntheticImages.write(SyntheticImages.noise(width: 640, height: 400), to: url)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 3600)], ofItemAtPath: url.path)
        #expect(try key(url: url) != before)
    }

    @Test func fieldsCannotRunTogether() throws {
        // "Mail" + "x" must not read like "Mai" + "lx": every field is length-prefixed.
        #expect(try key(text: "ab", options: LabelOptions()) != key(text: "a", options: LabelOptions()))
    }
}
