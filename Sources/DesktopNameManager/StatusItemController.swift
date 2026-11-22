import AppKit
import DesktopNameApp

/// The menu-bar item (spec 014, FR-010, contracts/app-ui.md §Menu-bar item): the glyph, with the app's fixed text
/// in Icon and text mode, and no item in Hidden mode. It never shows the label, so it does not change with Desktop
/// switches. Clicking it opens the main window.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onClick: (NSStatusBarButton) -> Void

    init(onClick: @escaping (NSStatusBarButton) -> Void) {
        self.onClick = onClick
        super.init()
        if let button = item.button {
            button.image = MenuBarGlyph.image()
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(clicked(_:))
            button.setAccessibilityLabel(AppInfo.displayName)
        }
    }

    func apply(_ mode: MenuBarMode) {
        item.isVisible = mode != .hidden
        item.button?.title = MenuBarState.itemTitle(for: mode).map { " \($0)" } ?? ""
    }

    /// The item's button while it is shown, for the hotkey to open the main window under it.
    var visibleButton: NSStatusBarButton? {
        item.isVisible ? item.button : nil
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        onClick(sender)
    }
}
