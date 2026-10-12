import CryptoKit
import Foundation

/// What an existing labeled image was made from (spec 009 data model §2). Two requests with the same key are expected
/// to render the same image, so `set` can use the existing one. The request's options are used as given, with `nil`
/// meaning automatic, because the automatic choices follow the original and so need no rendering to compare.
enum ReuseKey {
    static func make(original: Original, originalURL: URL?, text: LabelText, options: LabelOptions, display: Display) -> String {
        let attributes = originalURL.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path) }
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? -1
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let geometry = display.geometry
        let fields: [String] = [
            "renderer \(LabelRenderer.version)",
            originalURL?.path ?? original.path,
            "\(size)", "\(modified)",
            "\(original.scaling)", "\(original.clipping)", original.fillColor?.base64EncodedString() ?? "",
            text.value,
            options.look?.rawValue ?? "auto", options.textColor.map(\.description) ?? "auto",
            options.position?.rawValue ?? "auto", options.size?.rawValue ?? "auto",
            display.uuid, "\(geometry.pointWidth)", "\(geometry.pointHeight)", "\(geometry.scale)",
            "\(geometry.insetTop)", "\(geometry.insetLeft)", "\(geometry.insetBottom)", "\(geometry.insetRight)",
        ]
        // Each field is length-prefixed so that two different lists can never read the same.
        let canonical = fields.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
        return SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
