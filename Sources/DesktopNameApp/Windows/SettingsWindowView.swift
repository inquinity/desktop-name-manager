import DesktopNameCore
import SwiftUI

/// The Settings window (spec 014, contracts/app-ui.md §Settings window, research R2): a sidebar of panes, as in System
/// Settings, and the selected pane as a grouped form.
public struct SettingsWindowView: View {
    @Bindable var model: SettingsModel

    public init(model: SettingsModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { model.pane }, set: { if let pane = $0 { model.show(pane) } })) {
                Section { row(.general); row(.cleanUp) }
                Section { row(.configuration); row(.displays); row(.labels) }
                Section { row(.about) }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
        } detail: {
            detail
                .navigationTitle(model.pane.title)
                .frame(minWidth: 460, minHeight: 420)
        }
        .onAppear { model.paneShown() }
    }

    private func row(_ pane: SettingsPane) -> some View {
        Label(pane.title, systemImage: pane.symbol).tag(pane)
    }

    @ViewBuilder private var detail: some View {
        switch model.pane {
        case .general: GeneralPane(model: model)
        case .cleanUp: CleanUpPane(model: model)
        case .configuration: ConfigurationPane(model: model)
        case .displays: DisplaysPane(model: model.displays)
        case .labels: LabelsPane(model: model)
        case .about: AboutPane(model: model)
        }
    }
}

/// A pane's red sentence, when it has one.
struct PaneMessage: View {
    let text: String?

    var body: some View {
        if let text { MessageLine(text: text) }
    }
}

// MARK: - General

struct GeneralPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section("System") {
                Toggle("Open at login", isOn: Binding(get: { model.opensAtLogin }, set: { model.setOpensAtLogin($0) }))
                Picker("Menu bar shows", selection: Binding(get: { model.settings.menuBarMode }, set: { model.setMenuBarMode($0) })) {
                    Text("Icon and text").tag(MenuBarMode.iconAndText)
                    Text("Icon").tag(MenuBarMode.icon)
                    Text("Nothing (hidden)").tag(MenuBarMode.hidden)
                }
                .id(model.menuBarRefusals)
                PaneMessage(text: model.message)
            }
            Section("Hotkeys") {
                ForEach(HotkeyKind.allCases, id: \.self) { kind in
                    LabeledContent(kind == .main ? "Open the main window" : "Open Style and Preview") {
                        ShortcutRecorder(shortcut: model.hotkey.shortcut(for: kind), onRecord: { model.hotkey.record($0, for: kind) },
                                         onClear: { model.hotkey.clear(kind) },
                                         onRecordingChange: { model.hotkey.recording($0) })
                    }
                    PaneMessage(text: model.hotkey.message(for: kind))
                }
            }
            Section("New Labels") {
                Picker("Style", selection: Binding(get: { model.settings.defaultLook }, set: { model.settings.defaultLook = $0 })) {
                    Text("Automatic").tag(Look?.none)
                    ForEach(Look.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(Look?.some($0)) }
                }
                ColorDefault(settings: model.settings)
                Picker("Position", selection: Binding(get: { model.settings.defaultPosition }, set: { model.settings.defaultPosition = $0 })) {
                    ForEach(Position.allCases, id: \.self) { Text(PositionName.of($0)).tag($0) }
                }
                Picker("Size", selection: Binding(get: { model.settings.defaultSize }, set: { model.settings.defaultSize = $0 })) {
                    ForEach(Size.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// The default color: Automatic, Light, Dark or Custom with a color well (stored as `#RRGGBB`).
struct ColorDefault: View {
    let settings: AppSettings

    private enum Choice: Hashable { case automatic, light, dark, custom }

    private var choice: Choice {
        switch settings.defaultColor {
        case nil: .automatic
        case .light?: .light
        case .dark?: .dark
        case .custom?: .custom
        }
    }

    private var customColor: Color {
        if case let .custom(red, green, blue)? = settings.defaultColor { return Color(red: red, green: green, blue: blue) }
        return Color(red: 1, green: 0.82, blue: 0.4)
    }

    var body: some View {
        LabeledContent("Color") {
            HStack {
                Picker("Color", selection: Binding(get: { choice }, set: { set($0) })) {
                    Text("Automatic").tag(Choice.automatic)
                    Text("Light").tag(Choice.light)
                    Text("Dark").tag(Choice.dark)
                    Text("Custom").tag(Choice.custom)
                }
                .labelsHidden()
                .fixedSize()
                if choice == .custom {
                    ColorPicker("Custom color", selection: Binding(get: { customColor }, set: { setCustom($0) }), supportsOpacity: false)
                        .labelsHidden()
                }
            }
        }
    }

    private func set(_ choice: Choice) {
        switch choice {
        case .automatic: settings.defaultColor = nil
        case .light: settings.defaultColor = .light
        case .dark: settings.defaultColor = .dark
        case .custom: setCustom(customColor)
        }
    }

    private func setCustom(_ color: Color) {
        let rgb = NSColor(color).usingColorSpace(.sRGB) ?? .white
        settings.defaultColor = .custom(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
    }
}

/// Positions as the editor names them.
enum PositionName {
    static func of(_ position: Position) -> String {
        switch position {
        case .topLeft: "Top left"
        case .top: "Top"
        case .topRight: "Top right"
        case .bottomLeft: "Bottom left"
        case .bottom: "Bottom"
        case .bottomRight: "Bottom right"
        }
    }
}

// MARK: - Clean Up

struct CleanUpPane: View {
    @Bindable var model: SettingsModel
    @State private var confirming = false

    private var cleanUp: CleanUpModel { model.cleanUp }

    var body: some View {
        Form {
            if model.storage.cleanUpWarning {
                Section {
                    MessageLine(text: "Old labeled images use \(StorageSummary.format(model.storage.oldImages)).")
                }
            }
            Section("Space") {
                LabeledContent("Labeled images use", value: StorageSummary.format(model.storage.spaceUsed))
                LabeledContent("Older than") {
                    HStack(spacing: 4) {
                        TextField("Days", value: days, format: .number)
                            .labelsHidden()
                            .frame(width: 56)
                            .multilineTextAlignment(.trailing)
                        Text("days")
                        Stepper("Days", value: days, in: AppSettings.cleanUpDaysRange).labelsHidden()
                    }
                }
            }
            // Above the list, so a failed deletion's sentence is in view however long the list is.
            PaneMessage(text: cleanUp.message ?? model.message)
            Section {
                if cleanUp.candidates.isEmpty {
                    Text("No old images.").foregroundStyle(.secondary)
                } else {
                    ForEach(cleanUp.candidates, id: \.stampID) { candidate in
                        Toggle(isOn: Binding(get: { cleanUp.selection.contains(candidate.stampID) },
                                             set: { on in
                                                 if on { cleanUp.selection.insert(candidate.stampID) } else { cleanUp.selection.remove(candidate.stampID) }
                                             })) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(candidate.label)
                                    Text("\(candidate.displayName) · \(candidate.reason.phrase)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(StorageSummary.format(candidate.bytes)).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            } header: {
                Text(cleanUp.candidates.isEmpty ? "Old labeled images" : "Old labeled images: \(cleanUp.candidates.count)")
            }
        }
        .formStyle(.grouped)
        // However long the list, Select all, the selection and Delete Selected… stay in view under it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !cleanUp.candidates.isEmpty { actionBar }
        }
        .confirmationDialog(cleanUp.confirmation, isPresented: $confirming) {
            Button("Delete", role: .destructive) { cleanUp.deleteSelected(); model.paneShown() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The labeled images are deleted. Labels in use are never deleted.")
        }
    }

    private var days: Binding<Int> {
        Binding(get: { model.settings.cleanUpDays }, set: { model.setCleanUpDays($0) })
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Toggle("Select all", isOn: Binding(get: { cleanUp.allSelected }, set: { cleanUp.selectAll($0) }))
                    .toggleStyle(.checkbox)
                Text(cleanUp.summary).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Button("Delete Selected…") { confirming = true }.disabled(!cleanUp.canDelete)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }
}

// MARK: - Configuration

struct ConfigurationPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            if let configuration = model.configuration {
                Section("This Mac") {
                    LabeledContent("macOS", value: configuration.macOS)
                    LabeledContent("Separate Spaces") {
                        Label(configuration.separateSpaces ? "On" : "Off",
                              systemImage: configuration.separateSpaces ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    }
                    LinkRow(title: "Displays", value: "\(configuration.displayCount)") { model.show(.displays) }
                }
                Section("Storage") {
                    LinkRow(title: "Labels in use", value: "\(model.storage.labelsInUse), \(StorageSummary.format(model.storage.spaceUsed))") {
                        model.show(.labels)
                    }
                    LabeledContent("Old labeled images") {
                        HStack {
                            Text(StorageSummary.format(model.storage.oldImages))
                            Button("Clean Up…") { model.show(.cleanUp) }
                        }
                    }
                    LabeledContent("Data folder") {
                        HStack {
                            Text(configuration.dataFolder).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([configuration.dataFolderURL]) }
                        }
                    }
                }
            }
            PaneMessage(text: model.message)
        }
        .formStyle(.grouped)
    }
}

/// A row that opens another pane: its title, its value and an arrow.
struct LinkRow: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            LabeledContent(title) {
                HStack(spacing: 4) {
                    Text(value)
                    Image(systemName: "chevron.right").font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Displays

struct DisplaysPane: View {
    @Bindable var model: DisplaysModel

    var body: some View {
        Form {
            ForEach(model.rows) { row in
                Section {
                    DisplayRow(row: row, model: model)
                    if let note = model.note, note.displayUUID == row.display.uuid {
                        if note.isError { MessageLine(text: note.text) } else { Text(note.text).foregroundStyle(.secondary) }
                    }
                }
            }
            if let note = model.note, note.displayUUID.isEmpty { MessageLine(text: note.text) }
        }
        .formStyle(.grouped)
    }
}

struct DisplayRow: View {
    let row: DisplaysModel.Row
    let model: DisplaysModel
    @State private var newAlias = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text(row.display.name)
                if row.display.isMain { Text("Main display").font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            ForEach(row.aliases, id: \.self) { alias in
                HStack(spacing: 2) {
                    Text(alias)
                    Button { model.remove(alias, from: row.display) } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove alias \(alias)")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
            TextField("Add alias", text: $newAlias)
                .frame(width: 90)
                .onSubmit(add)
                .accessibilityLabel("Add alias to \(row.display.name)")
            Button(action: add) { Image(systemName: "plus") }
                .disabled(newAlias.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Add alias")
        }
    }

    private func add() {
        model.add(newAlias, to: row.display)
        if model.note?.isError != true { newAlias = "" }
    }
}

// MARK: - Labels

struct LabelsPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                if model.labels.isEmpty {
                    Text("No labels in use.").foregroundStyle(.secondary)
                }
                ForEach(model.labels) { label in
                    LabeledContent {
                        Text(StorageSummary.format(label.bytes))
                    } label: {
                        Text(label.label)
                        Text(label.connected ? label.displayName : "\(label.displayName) (not connected)")
                    }
                }
            } footer: {
                if !model.labels.isEmpty {
                    Text("\(model.labels.count) label\(model.labels.count == 1 ? "" : "s"), \(StorageSummary.format(model.labelsTotal))")
                        .foregroundStyle(.secondary)
                }
            }
            PaneMessage(text: model.message)
        }
        .formStyle(.grouped)
    }
}
