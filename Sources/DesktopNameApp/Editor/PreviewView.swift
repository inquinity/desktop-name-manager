import CoreGraphics
import DesktopNameCore
import SwiftUI

/// The live preview: this Desktop's wallpaper with the label as it would be applied (FR-005, research R6).
struct PreviewView: View {
    let image: CGImage?
    let description: String

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle().fill(.quaternary).aspectRatio(16 / 10, contentMode: .fit)
                    .overlay { ProgressView().controlSize(.small) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
        .accessibilityElement()
        .accessibilityLabel("Preview")
        .accessibilityValue(description)
    }
}
