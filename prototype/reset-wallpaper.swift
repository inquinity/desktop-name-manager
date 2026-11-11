// reset-wallpaper: RESEARCH TOOL, never part of the product (spec 013 research R1).
//
// Answers one question for known issue KI-3: when a Desktop shows a label on screen but macOS reports the original
// wallpaper, does setting the reported image again make the screen catch up? It uses only public NSWorkspace calls.
//
// Build and run (from the repository root):
//   swiftc -O -o build.noindex/research/reset-wallpaper prototype/reset-wallpaper.swift
//   build.noindex/research/reset-wallpaper                      # print what each display reports (changes nothing)
//   build.noindex/research/reset-wallpaper --set NAME           # set NAME's reported image again, same options
//   build.noindex/research/reset-wallpaper --set NAME --via F   # set image F first, then the reported image
// NAME is a display name as macOS gives it (NSScreen.localizedName).

import AppKit
import Foundation

func argument(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name), index + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[index + 1]
}

func describe(_ screen: NSScreen) {
    let workspace = NSWorkspace.shared
    let url = workspace.desktopImageURL(for: screen)?.path ?? "(none)"
    let options = workspace.desktopImageOptions(for: screen) ?? [:]
    let scaling = (options[.imageScaling] as? NSNumber)?.intValue.description ?? "-"
    let clipping = (options[.allowClipping] as? NSNumber)?.boolValue.description ?? "-"
    let fill = (options[.fillColor] as? NSColor).map { "\($0)" } ?? "-"
    print("\(screen.localizedName): \(url)")
    print("  scaling \(scaling), clipping \(clipping), fill \(fill)")
}

let screens = NSScreen.screens
guard let name = argument("--set") else {
    screens.forEach(describe)
    exit(0)
}
guard let screen = screens.first(where: { $0.localizedName == name }) else {
    FileHandle.standardError.write(Data("No display named \(name). Displays: \(screens.map(\.localizedName))\n".utf8))
    exit(2)
}
let workspace = NSWorkspace.shared
guard let reported = workspace.desktopImageURL(for: screen) else {
    FileHandle.standardError.write(Data("\(name) reports no image.\n".utf8))
    exit(1)
}
let options = workspace.desktopImageOptions(for: screen) ?? [:]
print("Before:"); describe(screen)
do {
    if let via = argument("--via") {
        try workspace.setDesktopImageURL(URL(fileURLWithPath: via), for: screen, options: options)
        print("Set \(via) first.")
        Thread.sleep(forTimeInterval: 1)
    }
    try workspace.setDesktopImageURL(reported, for: screen, options: options)
    print("Set \(reported.path) again.")
} catch {
    FileHandle.standardError.write(Data("Set failed: \(error)\n".utf8))
    exit(1)
}
print("After:"); describe(screen)
