import AppKit
import SwiftUI

/// The welcome window (spec 014, contracts/app-ui.md §Welcome window, FR-017a): shown once, with one OK button and no
/// settings or actions.
public struct WelcomeView: View {
    let menuBarMode: MenuBarMode
    let onOK: () -> Void

    public init(menuBarMode: MenuBarMode, onOK: @escaping () -> Void) {
        self.menuBarMode = menuBarMode
        self.onOK = onOK
    }

    public var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            Text(AppInfo.displayName).font(.title2.bold())
            Text("It labels each Desktop by writing the label into a copy of that Desktop's wallpaper.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text("To label a Desktop, click")
                MenuBarItemSample(showsText: menuBarMode != .icon)
                Text("in the menu bar.")
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("To label a Desktop, click \(AppInfo.displayName) in the menu bar.")
            Button("OK", action: onOK)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(24)
        .frame(width: 400)
    }
}

/// The menu-bar item as it looks there: the glyph and, in Icon and text mode, the fixed text.
struct MenuBarItemSample: View {
    let showsText: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: MenuBarGlyph.image())
            if showsText { Text(AppInfo.menuBarText) }
        }
        .font(.callout)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)))
    }
}

/// The menu-bar item's glyph: `MenuBarGlyph.svg` from the bundle as a template image, or a system symbol when the app
/// runs outside its bundle (tests, `swift run`).
public enum MenuBarGlyph {
    @MainActor
    public static func image() -> NSImage {
        let image = Bundle.main.url(forResource: "MenuBarGlyph", withExtension: "svg").flatMap(NSImage.init(contentsOf:))
            ?? NSImage(systemSymbolName: "tag", accessibilityDescription: nil) ?? NSImage()
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        image.accessibilityDescription = AppInfo.displayName
        return image
    }
}
