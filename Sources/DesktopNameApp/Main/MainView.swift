import DesktopNameCore
import SwiftUI

/// The main window, under the menu-bar item (spec 014, contracts/app-ui.md §Main window, FR-013, FR-013a, FR-016b).
public struct MainView: View {
    @Bindable var model: MainWindowModel
    @FocusState private var fieldFocused: Bool

    public init(model: MainWindowModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            desktopLine
            labelField
            if let message = model.quick.message ?? model.message { MessageLine(text: message) }
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                MenuRow(title: "Style and Preview…") { model.actions.openEditor() }
                if model.state.currentLabel != nil {
                    MenuRow(title: "Remove Label") { Task { await model.remove() } }.disabled(model.working)
                }
                if let undo = model.state.undo {
                    MenuRow(title: undo.title) { Task { await model.undo() } }.disabled(model.working)
                }
            }
            Divider()
            labelsRow
            storageRow
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                MenuRow(title: "Settings…", shortcut: "⌘,") { model.actions.openSettings(.general) }
                    .keyboardShortcut(",", modifiers: .command)
                MenuRow(title: "Configuration…") { model.actions.openSettings(.configuration) }
                MenuRow(title: "About \(AppInfo.displayName)") { model.actions.openSettings(.about) }
                MenuRow(title: "Quit", shortcut: "⌘Q") { model.actions.quit() }
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { fieldFocused = true }
        .onExitCommand { model.actions.close() }
        .onChange(of: model.quick.state) { _, state in if state == .closed { model.actions.close() } }
    }

    private var desktopLine: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.display.name).font(.caption).foregroundStyle(.secondary)
            Text(model.state.currentLabel?.text.value ?? "No label")
                .font(.headline)
                .foregroundStyle(model.state.currentLabel == nil ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)   // the label whole, wrapping if needed
                .accessibilityLabel(model.state.currentLabel.map { "Label: \($0.text.value)" } ?? "No label")
        }
    }

    private var labelField: some View {
        HStack(spacing: 8) {
            TextField("Label this Desktop", text: Binding(get: { model.quick.text }, set: { model.quick.setText($0) }))
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit { Task { await model.quick.apply() } }
                .disabled(model.quick.state == .applying)
                .accessibilityLabel("Label")
            Button("Apply") { Task { await model.quick.apply() } }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.quick.canApply)
        }
    }

    private var labelsRow: some View {
        Button { model.actions.openSettings(.labels) } label: {
            HStack {
                Text("Labels in use")
                Spacer()
                Text(model.labelsInUseText).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var storageRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Space used: \(StorageSummary.format(model.storage.spaceUsed))")
                if model.storage.cleanUpWarning {
                    Label("\(StorageSummary.format(model.storage.oldImages)) in old images", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .accessibilityLabel("Warning: \(StorageSummary.format(model.storage.oldImages)) in old images")
                } else {
                    Text("\(StorageSummary.format(model.storage.oldImages)) in old images").foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            Spacer()
            Button("Clean Up…") { model.actions.openSettings(.cleanUp) }
        }
        .padding(.vertical, 4)
    }
}

/// A row that acts like a menu item: the title, an optional shortcut on the right, highlighted on hover.
struct MenuRow: View {
    let title: String
    var shortcut: String?
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let shortcut { Text(shortcut).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(hovering && isEnabled ? Color.accentColor.opacity(0.18) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// One red sentence with a warning symbol, so color is not the only cue (FR-027).
struct MessageLine: View {
    let text: String

    var body: some View {
        Label { Text(text).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
            .font(.callout)
            .foregroundStyle(.red)
            .accessibilityElement(children: .combine)
    }
}
