// EditorPrototype (spec 014, prototype stage 2, task T027): the real editor (EditorView, EditorDraft and the core's
// preview) over a fake wallpaper system and a temporary store. It cannot change the real wallpaper or the real label
// store: there is no code path here to SystemWallpaperSystem or Store.defaultDirectory() (FR-003).
//
//   swift run --scratch-path build.noindex EditorPrototype            a window with the editor and a sample picker
//   swift run --scratch-path build.noindex EditorPrototype --measure  no window: spike S2 timings and the automatic
//                                                                      style at preview and full size, per sample
//
// Pictures come from the local, untracked wallpaper-samples/ folder when it exists, else from synthetic images.

import AppKit
import DesktopNameApp
import DesktopNameCore
import DNMTestSupport
import SwiftUI

/// A 5K display: 2560 x 1440 points at 2x, as in the snapshot sweep.
let display = Display(name: "Studio Display", uuid: "PROTOTYPE-5K", isMain: true,
                      geometry: DisplayGeometry(pointWidth: 2560, pointHeight: 1440, scale: 2, insetTop: 30, insetBottom: 90))
let previewWidth = 800

/// A wallpaper to try: a local sample or a synthetic picture written to the temporary folder.
struct Sample: Hashable {
    var name: String
    var url: URL
}

/// The temporary folder for this run: the store and the synthetic pictures. Removed when the prototype quits.
let workFolder: URL = {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("dnm-editor-prototype-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}()

func samplesFolder() -> URL? {
    var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while directory.path != "/" {
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
            let candidate = directory.appendingPathComponent("wallpaper-samples", isDirectory: true)
            return FileManager.default.fileExists(atPath: candidate.path) ? candidate.resolvingSymlinksInPath() : nil
        }
        directory = directory.deletingLastPathComponent()
    }
    return nil
}

func loadSamples() throws -> [Sample] {
    let extensions: Set<String> = ["jpg", "jpeg", "png", "heic", "tif", "tiff"]
    if let folder = samplesFolder(),
       let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
        let pictures = files.filter { extensions.contains($0.pathExtension.lowercased()) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        // Numbered, not named: the samples are personal and their names stay out of any output.
        if !pictures.isEmpty { return pictures.enumerated().map { Sample(name: "Sample \($0.offset + 1)", url: $0.element) } }
    }
    let synthetic: [(String, CGImage)] = [
        ("Synthetic light", SyntheticImages.bright(width: 2560, height: 1440)),
        ("Synthetic dark", SyntheticImages.dark(width: 2560, height: 1440)),
        ("Synthetic gradient", SyntheticImages.gradient(width: 2560, height: 1440)),
        ("Synthetic busy", SyntheticImages.noise(width: 2560, height: 1440)),
    ]
    return try synthetic.map { name, image in
        Sample(name: name, url: try SyntheticImages.write(image, to: workFolder.appendingPathComponent("\(name).png")))
    }
}

let samples: [Sample]
do { samples = try loadSamples() } catch {
    print("EditorPrototype: cannot prepare the pictures: \(error)")
    exit(1)
}
let system = FakeWallpaperSystem(displays: [display])
let store = Store(directory: workFolder.appendingPathComponent("store", isDirectory: true))
let labeler = DesktopLabeler(system: system, store: store)

func millis(_ seconds: Double) -> String { String(format: "%.0f ms", seconds * 1000) }

// MARK: - Spike S2 (--measure)

/// For each sample: how long the editor takes to open (loading the source), how long a preview and the four chips take,
/// and whether the automatic style at preview size agrees with the full render for each position.
@MainActor func measure() throws {
    let text = try LabelText("Status Report")
    print("Spike S2: \(samples.count) pictures, 5K display, \(previewWidth)-pixel preview")
    var worstOpen = 0.0, worstPreview = 0.0, worstAll = 0.0, disagreements = 0, comparisons = 0
    for sample in samples {
        system.show(sample.url, on: display)
        var started = Date()
        let source = try labeler.previewSource(on: display, maxPixelWidth: previewWidth)
        let chipSource = source.scaled(toWidth: 240)
        let open = Date().timeIntervalSince(started)
        var previewTime = 0.0, allTime = 0.0
        var line: [String] = []
        for position in Position.allCases {
            let options = LabelOptions(position: position)
            started = Date()
            let preview = try LabelPreview.render(PreviewRequest(text: text, options: options, maxPixelWidth: previewWidth), source: source)
            previewTime = max(previewTime, Date().timeIntervalSince(started))
            for look in [nil, Look.plain, .halo, .frosted] {
                var chip = options
                chip.look = look
                _ = try LabelPreview.render(PreviewRequest(text: text, options: chip, maxPixelWidth: 240), source: chipSource)
            }
            allTime = max(allTime, Date().timeIntervalSince(started))
            let full = try labeler.setLabel(text, options: options, on: display)
            try labeler.removeLabel(on: display)
            comparisons += 1
            if full.label.look != preview.label.look || full.label.textColor != preview.label.textColor {
                disagreements += 1
                line.append("\(position.rawValue): preview \(preview.label.look), applied \(full.label.look)")
            }
        }
        worstOpen = max(worstOpen, open); worstPreview = max(worstPreview, previewTime); worstAll = max(worstAll, allTime)
        print("  \(sample.name): open \(millis(open)), preview \(millis(previewTime)), preview and chips \(millis(allTime))"
              + (line.isEmpty ? "" : "; disagrees: " + line.joined(separator: "; ")))
    }
    print("Worst: open \(millis(worstOpen)), preview \(millis(worstPreview)), preview and chips \(millis(worstAll)) (SC-002: 250 ms)")
    print("Automatic style, preview against applied: \(disagreements) of \(comparisons) disagree")
}

if CommandLine.arguments.contains("--measure") {
    do { try measure() } catch { print("EditorPrototype: \(MessageWording.sentence(for: error))") }
    try? FileManager.default.removeItem(at: workFolder)
    exit(0)
}

// MARK: - The window

/// Which picture the fake Desktop shows, and the editor open over it. Apply and Remove change only the fake
/// wallpaper system and the temporary store; "Reopen" opens the editor again to see the result.
@MainActor
@Observable
final class PrototypeModel {
    var sample: Sample
    var draft: EditorDraft?
    var status = ""

    init() {
        sample = samples[0]
        show(sample)
    }

    func show(_ sample: Sample) {
        self.sample = sample
        system.show(sample.url, on: display)
        reopen()
    }

    func reopen() {
        let current = try? labeler.currentLabel(on: display)
        let started = Date()
        let draft = EditorDraft(display: display, currentLabel: current, defaults: LabelOptions(), actions: EditorActions(
            apply: { text, options in
                let started = Date()
                let result = try labeler.setLabel(text, options: options, on: display)
                self.status = "Applied in \(millis(Date().timeIntervalSince(started))): \(result.label.look.rawValue), "
                    + "\(result.label.position.rawValue), \(result.label.size.rawValue) (fake wallpaper, temporary store)"
            },
            remove: {
                try labeler.removeLabel(on: display)
                self.status = "Removed (fake wallpaper, temporary store)"
            }), previewWidth: previewWidth)
        draft.load { try labeler.previewSource(on: display, maxPixelWidth: previewWidth) }
        status = "Opened in \(millis(Date().timeIntervalSince(started)))"
        self.draft = draft
    }

    func closed() { draft = nil }
}

struct PrototypeView: View {
    @State private var model = PrototypeModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Wallpaper", selection: Binding(get: { model.sample }, set: { model.show($0) })) {
                    ForEach(samples, id: \.self) { Text($0.name).tag($0) }
                }
                .frame(maxWidth: 260)
                Spacer()
                Button("Reopen the editor") { model.reopen() }
            }
            Text("Prototype: a fake Desktop and a temporary store. Your wallpaper and labels are never changed.")
                .font(.caption).foregroundStyle(.secondary)
            if let draft = model.draft {
                EditorView(draft: draft) { model.closed() }
                    .id(ObjectIdentifier(draft))
                if let seconds = draft.lastRenderSeconds {
                    Text("Last preview: \(millis(seconds))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            } else {
                Text("The editor is closed.").foregroundStyle(.secondary).frame(width: 420, height: 120)
            }
            Text(model.status).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

@MainActor
final class PrototypeDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: PrototypeView()))
        window.title = "Editor prototype (spec 014, stage 2)"
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        try? FileManager.default.removeItem(at: workFolder)
    }
}

let application = NSApplication.shared
let delegate = PrototypeDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
