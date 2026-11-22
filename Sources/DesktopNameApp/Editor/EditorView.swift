import DesktopNameCore
import SwiftUI

/// The label editor (spec 014 FR-004 to FR-009, contracts/app-ui.md §Editor, the approved mockups): the field, the
/// live preview, the style chips, color, position and size (always shown, prototype review round 9), and Remove
/// Label, Cancel and Apply.
public struct EditorView: View {
    @Bindable var draft: EditorDraft
    let onClose: () -> Void
    @FocusState private var fieldFocused: Bool
    @State private var customColor = Color(red: 1, green: 0.82, blue: 0.4)

    public init(draft: EditorDraft, onClose: @escaping () -> Void) {
        self.draft = draft
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            field
            if let message = draft.message { messageLine(message) }
            PreviewView(image: draft.preview, description: previewDescription)
            if draft.state != .unsupported { options }
            buttons
        }
        .padding(16)
        .frame(width: 420)
        .onAppear { fieldFocused = true }
        .onExitCommand { close { draft.cancel() } }
        .onChange(of: draft.state) { _, state in if state == .closed { onClose() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Label this Desktop").font(.headline)
            Text(draft.display.name).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var field: some View {
        TextField("Label this Desktop", text: Binding(get: { draft.text }, set: { draft.setText($0) }))
            .textFieldStyle(.roundedBorder)
            .focused($fieldFocused)
            .disabled(draft.state == .unsupported || draft.state == .applying || draft.state == .removing)
            .onSubmit { Task { await draft.apply() } }
            .accessibilityLabel("Label")
    }

    private func messageLine(_ message: String) -> some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.callout)
        .foregroundStyle(.red)
        .accessibilityElement(children: .combine)
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            StyleChips(selected: draft.style, chips: draft.chips, position: draft.position) { draft.setStyle($0) }
            if draft.style == .automatic, let look = draft.automaticLook {
                Text("Automatic picks \(look.rawValue.capitalized) for this spot")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LabeledContent("Color") { colorControl }
            LabeledContent("Position") { PositionGrid(selected: draft.position) { draft.setPosition($0) } }
            LabeledContent("Size") {
                Picker("Size", selection: Binding(get: { draft.size }, set: { draft.setSize($0) })) {
                    Text("Small").tag(Size.small)
                    Text("Medium").tag(Size.medium)
                    Text("Large").tag(Size.large)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private enum ColorChoice: Hashable { case automatic, light, dark, custom }

    private var colorChoice: ColorChoice {
        switch draft.color {
        case nil: .automatic
        case .light?: .light
        case .dark?: .dark
        case .custom?: .custom
        }
    }

    private var colorControl: some View {
        HStack {
            Picker("Color", selection: Binding(get: { colorChoice }, set: { choose($0) })) {
                Text("Automatic").tag(ColorChoice.automatic)
                Text("Light").tag(ColorChoice.light)
                Text("Dark").tag(ColorChoice.dark)
                Text("Custom").tag(ColorChoice.custom)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if colorChoice == .custom {
                ColorPicker("Custom color", selection: Binding(get: { customColor }, set: { customColor = $0; choose(.custom) }),
                            supportsOpacity: false)
                    .labelsHidden()
            }
        }
    }

    private func choose(_ choice: ColorChoice) {
        switch choice {
        case .automatic: draft.setColor(nil)
        case .light: draft.setColor(.light)
        case .dark: draft.setColor(.dark)
        case .custom:
            let rgb = NSColor(customColor).usingColorSpace(.sRGB) ?? .white
            draft.setColor(.custom(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent)))
        }
    }

    private var buttons: some View {
        HStack {
            if draft.currentLabel != nil {
                Button("Remove Label") { Task { await draft.remove() } }.disabled(!draft.canRemove)
            }
            Spacer()
            Button("Cancel") { close { draft.cancel() } }
                .keyboardShortcut(.cancelAction)
            Button("Apply") { Task { await draft.apply() } }
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.canApply)
        }
    }

    private func close(_ action: () -> Void) { action() }

    private var previewDescription: String {
        let text = draft.text.isEmpty ? "No label" : "\u{201C}\(draft.text)\u{201D}"
        let look = draft.style == .automatic ? (draft.automaticLook?.rawValue ?? "automatic") : StyleChips.name(draft.style).lowercased()
        return "\(text), \(look), \(draft.position.rawValue), \(draft.size.rawValue)"
    }
}

/// The six positions as a small grid (contracts/app-ui.md §Editor).
struct PositionGrid: View {
    let selected: Position
    let select: (Position) -> Void
    private static let rows: [[Position]] = [[.topLeft, .top, .topRight], [.bottomLeft, .bottom, .bottomRight]]

    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(Self.rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { position in
                        Button { select(position) } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(position == selected ? Color.accentColor : Color.secondary.opacity(0.25))
                                .frame(width: 26, height: 16)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(position.rawValue.replacingOccurrences(of: "-", with: " "))
                        .accessibilityAddTraits(position == selected ? .isSelected : [])
                    }
                }
            }
        }
    }
}
