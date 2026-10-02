import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Encodes a stamp. The tool chooses the format, not the source image: version 1 writes JPEG,
/// which keeps a 5K stamp at a few MB. The extension is stored with each stamp, so the format can
/// change later without breaking cleanup.
package enum ImageWriter {
    static let fileExtension = "jpg"
    static let quality = 0.92

    package static func encode(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw DnmError.failure("Cannot encode the labeled image.")
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw DnmError.failure("Cannot encode the labeled image.") }
        return data as Data
    }
}
