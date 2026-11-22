import CoreGraphics
import DesktopNameCore
import SwiftUI

/// Automatic, Plain, Halo and Frosted, each a small render over this wallpaper (FR-006, contracts/app-ui.md §Editor).
struct StyleChips: View {
    let selected: EditorDraft.StyleChoice
    let chips: [EditorDraft.StyleChoice: CGImage]
    let position: Position
    let select: (EditorDraft.StyleChoice) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(EditorDraft.StyleChoice.allCases, id: \.self) { choice in
                Button { select(choice) } label: {
                    VStack(spacing: 4) {
                        chipImage(choice)
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text(Self.name(choice)).font(.caption)
                    }
                    .padding(3)
                    .overlay(RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(choice == selected ? Color.accentColor : .clear, lineWidth: 2))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.name(choice))
                .accessibilityAddTraits(choice == selected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private func chipImage(_ choice: EditorDraft.StyleChoice) -> some View {
        if let image = chips[choice] {
            // Show the part of the Desktop where the label sits.
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Self.alignment(position))
        } else {
            Rectangle().fill(.quaternary)
        }
    }

    static func name(_ choice: EditorDraft.StyleChoice) -> String {
        switch choice {
        case .automatic: "Automatic"
        case .plain: "Plain"
        case .halo: "Halo"
        case .frosted: "Frosted"
        }
    }

    static func alignment(_ position: Position) -> Alignment {
        switch position {
        case .topLeft: .topLeading
        case .top: .top
        case .topRight: .topTrailing
        case .bottomLeft: .bottomLeading
        case .bottom: .bottom
        case .bottomRight: .bottomTrailing
        }
    }
}
