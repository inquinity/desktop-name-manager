// space-observer: RESEARCH TOOL, never part of the product.
//
// Watches how macOS associates Desktops (Spaces) with wallpaper images, so the product's design can rest on
// facts. It reads three things and never changes anything:
//   1. Mission Control's Space list, through a PRIVATE SkyLight call (read-only);
//   2. macOS's wallpaper store, a PRIVATE file (read-only);
//   3. dnm's own manifest (read-only), to name our stamps.
// The product must not use private interfaces; this tool exists only to learn.
//
// Build and run (from the repository root):
//   swiftc -O -o build.noindex/research/space-observer prototype/space-observer.swift
//   build.noindex/research/space-observer            # interactive: describe an action, do it, see what changed
//   build.noindex/research/space-observer --once     # print one snapshot
// Options: --log FILE (default working-notes/research/observations-<date>.md, untracked)
//          --store DIR (dnm store to read; default: DNM_STORE_DIR or the release store)

import AppKit
import Foundation

// MARK: - Helpers

func short(_ s: String) -> String { s.isEmpty ? "''" : String(s.prefix(4)) }

let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f
}()

func argument(_ name: String) -> String? {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

// MARK: - dnm manifest (read-only)

let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
let dnmStore: URL = {
    if let explicit = argument("--store") { return URL(fileURLWithPath: explicit) }
    if let env = ProcessInfo.processInfo.environment["DNM_STORE_DIR"], !env.isEmpty { return URL(fileURLWithPath: env) }
    return supportDirectory.appendingPathComponent("com.altmansoftwaredesign.desktop-name-manager")
}()

func manifestStamps() -> [String: String] {
    guard let data = try? Data(contentsOf: dnmStore.appendingPathComponent("manifest.json")),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
    var result: [String: String] = [:]
    for stamp in (root["stamps"] as? [[String: Any]]) ?? [] {
        let label = ((stamp["label"] as? [String: Any])?["text"] as? String) ?? "?"
        let state: String = {
            if let s = stamp["state"] as? String { return s }
            if let d = stamp["state"] as? [String: Any], let retired = d["retired"] as? [String: Any] {
                return "retired(\(retired["reason"] as? String ?? "?"))"
            }
            return "active"
        }()
        result[stamp["fileName"] as? String ?? ""] = "\"\(label)\" \(state)"
    }
    return result
}

// MARK: - Wallpaper store (private file, read-only)

let storeURL = supportDirectory.appendingPathComponent("com.apple.wallpaper/Store/Index.plist")

func fileNames(_ value: Any?, depth: Int = 0) -> [String] {
    guard depth < 12, let value else { return [] }
    switch value {
    case let s as String: return s.hasPrefix("file://") ? [URL(string: s)?.lastPathComponent ?? s] : []
    case let d as [String: Any]: return d.values.flatMap { fileNames($0, depth: depth + 1) }
    case let a as [Any]: return a.flatMap { fileNames($0, depth: depth + 1) }
    case let data as Data:
        guard let nested = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return [] }
        return fileNames(nested, depth: depth + 1)
    default: return []
    }
}

/// Describes the Desktop part of a store entry (not the idle or lock-screen part).
func describeDesktop(_ entry: Any?, stamps: [String: String]) -> String {
    guard let entry = entry as? [String: Any], let desktop = entry["Desktop"] as? [String: Any] else { return "(none)" }
    let choices = ((desktop["Content"] as? [String: Any])?["Choices"] as? [[String: Any]]) ?? []
    let parts = choices.map { choice -> String in
        let provider = (choice["Provider"] as? String ?? "?").replacingOccurrences(of: "com.apple.wallpaper.choice.", with: "")
        let names = Array(Set(fileNames(choice["Configuration"]) + fileNames(choice["Files"]))).sorted()
        if names.isEmpty { return provider }
        return names.map { name in
            if name.contains(".dnm.") { return "stamp \(short(name)) \(stamps[name] ?? "(not in this dnm store)")" }
            let shown = name.count > 22 ? String(name.prefix(20)) + "…" : name
            return provider == "image" ? "image \(shown)" : "\(provider) \(shown)"
        }.joined(separator: " + ")
    }
    let set = (desktop["LastSet"] as? Date).map { " [set \(timeFormatter.string(from: $0))]" } ?? ""
    return (parts.isEmpty ? "(empty)" : parts.joined(separator: "; ")) + set
}

// MARK: - SkyLight Space list (private, read-only)

typealias MainConnection = @convention(c) () -> Int32
typealias CopySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?

func managedDisplaySpaces() -> [[String: Any]] {
    guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
          let connectionSymbol = dlsym(handle, "SLSMainConnectionID"),
          let copySymbol = dlsym(handle, "SLSCopyManagedDisplaySpaces") else { return [] }
    let connection = unsafeBitCast(connectionSymbol, to: MainConnection.self)()
    return (unsafeBitCast(copySymbol, to: CopySpaces.self)(connection)?.takeRetainedValue() as? [[String: Any]]) ?? []
}

// MARK: - Snapshot: an ordered list of (key, value) facts

typealias Snapshot = [(key: String, value: String)]

func takeSnapshot() -> Snapshot {
    var facts: Snapshot = []
    let stamps = manifestStamps()
    let store = ((try? Data(contentsOf: storeURL)).flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) } as? [String: Any]) ?? [:]
    let storeSpaces = store["Spaces"] as? [String: Any] ?? [:]
    let storeDisplays = store["Displays"] as? [String: Any] ?? [:]

    // Displays as the public API sees them.
    var names: [String: String] = [:]
    let mainID = CGMainDisplayID()
    for screen in NSScreen.screens {
        let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        let uuid = CGDisplayCreateUUIDFromDisplayID(id).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String } ?? ""
        names[uuid] = screen.localizedName
        let shown = NSWorkspace.shared.desktopImageURL(for: screen)?.lastPathComponent ?? "(none)"
        let label = shown.contains(".dnm.") ? "stamp \(short(shown)) \(stamps[shown] ?? "(not in this dnm store)")" : shown
        facts.append(("public: \(screen.localizedName)\(id == mainID ? " (main)" : "") shows", label))
    }

    // Settings that change how Spaces behave (public preferences).
    let mru = CFPreferencesCopyAppValue("mru-spaces" as CFString, "com.apple.dock" as CFString) as? Bool
    let spans = CFPreferencesCopyAppValue("spans-displays" as CFString, "com.apple.spaces" as CFString) as? Bool
    facts.append(("setting: rearrange Spaces by recent use (mru-spaces)", mru.map { $0 ? "on" : "off" } ?? "default (on)"))
    facts.append(("setting: displays have separate Spaces", spans.map { $0 ? "off (spans displays)" : "on" } ?? "default (on)"))

    // Each display's Desktops in Mission Control order, joined with the store.
    var listed = Set<String>()
    for display in managedDisplaySpaces() {
        let did = display["Display Identifier"] as? String ?? "?"
        let name = names[did] ?? "display \(short(did))"
        let current = (display["Current Space"] as? [String: Any])?["uuid"] as? String
        var number = 0
        var order: [String] = []
        for space in (display["Spaces"] as? [[String: Any]]) ?? [] {
            let uuid = space["uuid"] as? String ?? ""
            listed.insert(uuid)
            let fullScreen = (space["type"] as? Int ?? 0) != 0
            if !fullScreen { number += 1 }
            let id = "\(space["ManagedSpaceID"] ?? space["id64"] ?? "?")"
            let title = fullScreen ? "full-screen id \(id)" : "Desktop \(number) (id \(id), \(short(uuid)))"
            order.append(fullScreen ? "fs:\(id)" : "\(number)=id\(id)\(uuid == current ? "*" : "")")
            let entry = storeSpaces[uuid] as? [String: Any]
            if entry == nil {
                facts.append(("\(name) | \(title) | store entry", "(none)"))
            } else {
                facts.append(("\(name) | \(title) | own", describeDesktop((entry?["Displays"] as? [String: Any])?[did], stamps: stamps)))
                facts.append(("\(name) | \(title) | space default", describeDesktop(entry?["Default"], stamps: stamps)))
            }
        }
        facts.append(("\(name) | order (* = current)", order.joined(separator: " ")))
        facts.append(("\(name) | DISPLAY DEFAULT (new Desktops)", describeDesktop(storeDisplays[did], stamps: stamps)))
    }

    // Store-wide entries, and entries for Spaces that no longer exist.
    facts.append(("store: template for new Desktops ('')", describeDesktop((storeSpaces[""] as? [String: Any])?["Default"], stamps: stamps)))
    facts.append(("store: system default", describeDesktop(store["SystemDefault"], stamps: stamps)))
    let orphans = storeSpaces.keys.filter { !$0.isEmpty && !listed.contains($0) }.sorted()
    facts.append(("store: entries for Desktops not in Mission Control", orphans.isEmpty ? "none" : orphans.map(short).joined(separator: ", ")))
    for key in storeDisplays.keys.sorted() where names[key] == nil {
        facts.append(("store: default of a display not connected (\(short(key)))", describeDesktop(storeDisplays[key], stamps: stamps)))
    }
    for (file, info) in stamps.sorted(by: { $0.key < $1.key }) {
        facts.append(("dnm manifest: stamp \(short(file))", info))
    }
    return facts
}

// MARK: - Output and log

let logURL: URL = {
    if let explicit = argument("--log") { return URL(fileURLWithPath: explicit) }
    let day = DateFormatter()
    day.dateFormat = "yyyy-MM-dd"
    return URL(fileURLWithPath: "working-notes/research/observations-\(day.string(from: Date())).md")
}()

func log(_ text: String) {
    try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let handle = try? FileHandle(forWritingTo: logURL) {
        handle.seekToEndOfFile()
        handle.write(Data((text + "\n").utf8))
        try? handle.close()
    } else {
        try? Data((text + "\n").utf8).write(to: logURL)
    }
}

func render(_ snapshot: Snapshot) -> String {
    snapshot.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
}

func diff(_ before: Snapshot, _ after: Snapshot) -> String {
    let old = Dictionary(before.map { ($0.key, $0.value) }, uniquingKeysWith: { a, _ in a })
    let new = Dictionary(after.map { ($0.key, $0.value) }, uniquingKeysWith: { a, _ in a })
    var lines: [String] = []
    for (key, value) in after where old[key] != value {
        lines.append(old[key] == nil ? "  + \(key): \(value)" : "  ~ \(key):\n      was \(old[key]!)\n      now \(value)")
    }
    for (key, value) in before where new[key] == nil { lines.append("  - \(key): \(value)") }
    return lines.isEmpty ? "  (no change)" : lines.joined(separator: "\n")
}

// MARK: - Main

let stamp = { () -> String in let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f.string(from: Date()) }
var previous = takeSnapshot()
print("Snapshot \(stamp()):\n\(render(previous))")
log("\n## Session \(stamp())\n\nInitial snapshot:\n\n```\n\(render(previous))\n```")
if CommandLine.arguments.contains("--once") { exit(0) }

print("\nLog: \(logURL.path)")
var step = 1
while true {
    print("\nStep \(step). Describe the action you will do (or q to quit): ", terminator: "")
    guard let description = readLine(), description.lowercased() != "q" else { break }
    print("Do it now, then wait a couple of seconds and press Return: ", terminator: "")
    _ = readLine()
    let current = takeSnapshot()
    let changes = diff(previous, current)
    print("\nWhat changed after \"\(description)\":\n\(changes)")
    log("\n### Step \(step) (\(stamp())): \(description)\n\n```\n\(changes)\n```")
    previous = current
    step += 1
}
log("\nFinal snapshot:\n\n```\n\(render(previous))\n```")
print("Logged to \(logURL.path)")
