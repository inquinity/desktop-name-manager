import CoreGraphics
import DesktopNameCore
import DNMTestSupport
import Foundation
import Testing

/// SC-002 and the image-quality check (research R7): runs the product's own rendering over the local,
/// untracked `wallpaper-samples/` folder on a 5K display. The folder is personal and never committed;
/// when it is absent this suite reports as skipped.
@Suite struct LegibilitySweepTests {
    static let samplesDirectory: URL? = {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
                let candidate = directory.appendingPathComponent("wallpaper-samples", isDirectory: true)
                return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }()

    static func samples() -> [URL] {
        guard let directory = samplesDirectory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        let extensions: Set<String> = ["jpg", "jpeg", "png", "heic", "tif", "tiff"]
        return files.filter { extensions.contains($0.pathExtension.lowercased()) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// A 5K display: 2560 x 1440 points at 2x.
    static let geometry = DisplayGeometry(pointWidth: 2560, pointHeight: 1440, scale: 2, insetTop: 30, insetBottom: 90)

    @Test(.enabled(if: LegibilitySweepTests.samplesDirectory != nil))
    func everySampleIsLegibleAndSurvivesJPEGEncoding() throws {
        let files = Self.samples()
        try #require(!files.isEmpty, "wallpaper-samples/ holds no images")
        if files.count < 20 {
            print("note: SC-002 asks for at least 20 varied wallpapers; wallpaper-samples/ holds \(files.count)")
        }
        var failures: [String] = []
        var worstShare = 1.0, worstDifference = 0.0
        for file in files {
            let backdrop = try Legibility.backdrop(for: file, geometry: Self.geometry)
            let result = try Legibility.evaluate(backdrop: backdrop, text: LabelText("Status Report"), options: LabelOptions(), geometry: Self.geometry)
            worstShare = min(worstShare, result.share)
            worstDifference = max(worstDifference, result.jpegDifference)
            if result.share < Legibility.requiredShare {
                failures.append("sample \(files.firstIndex(of: file)! + 1): \(String(format: "%.1f", result.share * 100))% legible (\(result.label.look))")
            }
        }
        print("legibility sweep: \(files.count) samples, worst legible share \(String(format: "%.1f", worstShare * 100))%, worst JPEG difference \(String(format: "%.4f", worstDifference))")
        #expect(failures.isEmpty, "Below the 95% rule: \(failures.joined(separator: "; "))")
        #expect(worstDifference < 0.02, "JPEG encoding changed the picture by more than 2% on average")
    }
}
