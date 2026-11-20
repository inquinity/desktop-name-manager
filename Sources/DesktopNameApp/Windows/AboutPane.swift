import AppKit
import DesktopNameCore
import SwiftUI

/// A third-party component shipped in the app bundle, as the About pane's acknowledgements list it (prototype review
/// round 4, after CodexBar): its name, authors and license identifier, with the license text from the bundle.
public struct AppAcknowledgement: Equatable, Sendable {
    public var name: String
    public var authors: String
    /// The SPDX identifier, shown on the right.
    public var license: String
    /// The file in `Contents/Resources/Licenses/`.
    public var licenseFile: String

    /// One entry per component of `About.acknowledgements` (everything compiled into the bundle's executables:
    /// `dnm` carries swift-argument-parser), in the same order. A test checks the two lists match.
    public static let all: [AppAcknowledgement] = About.acknowledgements.map { component in
        AppAcknowledgement(name: component.name, authors: authors[component.name] ?? "", license: spdx[component.name] ?? component.license,
                           licenseFile: "\(component.name)-LICENSE.txt")
    }

    static let authors = ["swift-argument-parser": "Apple Inc. and the Swift project authors"]
    static let spdx = ["swift-argument-parser": "Apache-2.0"]

    /// The license text from the bundle, or nil outside it.
    public var licenseText: String? {
        Bundle.main.url(forResource: licenseFile, withExtension: nil, subdirectory: "Licenses")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }
}

/// The app's version as About shows it: "Version 0.4.0 (34)" from the bundle, else the build stamp's.
public enum AppVersion {
    public static var text: String {
        let info = Bundle.main.infoDictionary
        if let version = info?["CFBundleShortVersionString"] as? String, let build = info?["CFBundleVersion"] as? String {
            return "Version \(version) (\(build))"
        }
        return "Version \(DesktopNameCoreInfo.displayVersion)"
    }
}

struct AboutPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        if model.showingAcknowledgements {
            AcknowledgementsView { model.showingAcknowledgements = false }
        } else {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(nsImage: NSApplication.shared.applicationIconImage)
                            .resizable().frame(width: 64, height: 64).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppInfo.displayName).font(.title3.bold())
                            Text(AppVersion.text).foregroundStyle(.secondary).textSelection(.enabled)
                            Text("Labels for your Desktops, right in the wallpaper.").foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Privacy") {
                    Promise(title: "Needs no permissions", detail: "Labeling a Desktop asks macOS for nothing.")
                    Promise(title: "Never connects", detail: "No network access and no telemetry.")
                }
                Section("Links") {
                    Link(destination: URL(string: About.source)!) {
                        LabeledContent("GitHub") { Image(systemName: "arrow.up.right") }
                    }
                    LinkRow(title: "Acknowledgements", value: "") { model.showingAcknowledgements = true }
                }
            }
            .formStyle(.grouped)
        }
    }
}

/// One of About's two promises, with a check symbol.
struct Promise: View {
    let title: String
    let detail: String

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The acknowledgements, with a back button: one row per component, each expanding to its license text.
struct AcknowledgementsView: View {
    let onBack: () -> Void

    var body: some View {
        Form {
            Section {
                Button(action: onBack) { Label("About", systemImage: "chevron.left") }
                    .buttonStyle(.borderless)
            }
            Section("Acknowledgements") {
                ForEach(AppAcknowledgement.all, id: \.name) { component in
                    DisclosureGroup {
                        ScrollView {
                            Text(component.licenseText ?? "The license text is in the app's Resources/Licenses folder.")
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 220)
                    } label: {
                        LabeledContent {
                            Text(component.license)
                        } label: {
                            Text(component.name)
                            Text(component.authors)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
