import AppKit
import DesktopNameApp
import DesktopNameCore
import Observation
import SwiftUI

/// What the panel under the menu-bar item shows: the main window, or the editor for the same display.
@MainActor
@Observable
final class PanelContent {
    enum Page {
        case main(MainWindowModel)
        case editor(EditorDraft)
    }

    var page: Page?
}

struct PanelView: View {
    let content: PanelContent
    let editorClosed: (EditorDraft) -> Void

    var body: some View {
        switch content.page {
        case .main(let model)?:
            MainView(model: model).id(ObjectIdentifier(model))
        case .editor(let draft)?:
            EditorView(draft: draft) { editorClosed(draft) }.id(ObjectIdentifier(draft))
        case nil:
            EmptyView()
        }
    }
}

/// Shows the main window and the editor (spec 014, T034, T040, T045): in an `NSPopover` under the menu-bar item, or,
/// when the item is hidden and the hotkey is pressed, in a floating panel near the top of the active display. One main
/// window or editor at a time. Escape and a click outside close it with no change.
@MainActor
final class PopoverPresenter: NSObject, NSPopoverDelegate, NSWindowDelegate {
    private let controller: LabelingController
    private let settings: AppSettings
    private let openSettings: (SettingsPane) -> Void
    private let content = PanelContent()
    /// A new host for each popover or panel, so no view is ever in two windows.
    private func makeHosting() -> NSHostingController<PanelView> {
        let hosting = NSHostingController(rootView: PanelView(content: content) { [unowned self] draft in editorClosed(draft) })
        hosting.sizingOptions = [.preferredContentSize]
        return hosting
    }
    private var popover: NSPopover?
    /// When a click outside last closed the popover: a click on the item itself closes it on mouse-down, and its
    /// action must not then open it again.
    private var closedByClickAt = Date.distantPast
    private var panel: NSPanel?
    private var watcher: StoreWatcher?
    private var display: Display?
    /// While the floating panel is shown: a switch to another app closes it, even after the color panel took the
    /// keyboard (the panel then gets no resign-key of its own).
    private var deactivation: NSObjectProtocol?

    init(controller: LabelingController, settings: AppSettings, openSettings: @escaping (SettingsPane) -> Void) {
        self.controller = controller
        self.settings = settings
        self.openSettings = openSettings
    }

    private var isShown: Bool { popover?.isShown == true || panel?.isVisible == true }

    // MARK: - Opening

    /// A click on the menu-bar item: the main window for the display whose menu bar was clicked, or closes it.
    func toggle(from button: NSStatusBarButton) {
        if isShown { close(); return }
        guard Date().timeIntervalSince(closedByClickAt) > 0.3 else { return }
        showMain(about: button.window?.screen, under: button)
    }

    /// The hotkey: the main window for the active display, under the item when it is shown, else in a floating panel.
    /// It only opens (FR-014): a window already open for that display stays as it is and takes the keyboard; one open
    /// for another display moves to the active one.
    func openFromHotkey(itemButton: NSStatusBarButton?) {
        let screen = ActiveDisplay.forHotkey()
        if isShown {
            if let open = display, open.uuid == ActiveDisplay.display(for: screen, system: controller.labeler.system)?.uuid {
                NSApp.activate()
                (popover?.contentViewController?.view.window ?? panel)?.makeKey()
                return
            }
            close()
        }
        if let itemButton {
            showMain(about: screen, under: itemButton)
        } else {
            showMain(about: screen, under: nil)
        }
    }

    private func showMain(about screen: NSScreen?, under button: NSStatusBarButton?) {
        guard let display = ActiveDisplay.display(for: screen, system: controller.labeler.system) else { return }
        self.display = display
        showMainPage(for: display)
        watch()
        if let button {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = false
            popover.contentViewController = makeHosting()
            popover.delegate = self
            self.popover = popover
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        } else {
            showPanel(on: screen ?? NSScreen.main)
        }
    }

    private func showMainPage(for display: Display) {
        content.page = .main(MainWindowModel(display: display, controller: controller, settings: settings, actions: MainWindowActions(
            openEditor: { [unowned self] in openEditor() },
            openSettings: { [unowned self] pane in close(); openSettings(pane) },
            quit: { NSApp.terminate(nil) },
            close: { [unowned self] in close() })))
    }

    /// "Style and Preview…": the editor replaces the main window in the same panel.
    private func openEditor() {
        keepPanelTop()
        guard let display else { return }
        let current = try? controller.labeler.currentLabel(on: display)
        let draft = EditorDraft(display: display, currentLabel: current, defaults: settings.newLabelOptions, actions: EditorActions(
            apply: { [controller] text, options in try controller.apply(text, options: options, on: display) },
            remove: { [controller] in try controller.remove(on: display) }))
        content.page = .editor(draft)
        // The picture loads off the main thread; the editor shows `loading` until it arrives (T034).
        Task { await draft.load { [controller] in try controller.labeler.previewOrigin(on: display) } }
    }

    /// Apply and Remove close the panel; Cancel and Escape go back to the main window.
    private func editorClosed(_ draft: EditorDraft) {
        if draft.changed {
            close()
        } else if let display, content.page != nil {
            keepPanelTop()
            showMainPage(for: display)
        }
    }

    // MARK: - The floating panel (item hidden)

    /// The editor is taller than the main window; a window grows from its bottom-left corner, so the panel's top is
    /// put back after the new content is sized.
    private func keepPanelTop() {
        guard let panel else { return }
        let top = panel.frame.maxY
        DispatchQueue.main.async { [weak panel] in
            guard let panel else { return }
            panel.setFrameTopLeftPoint(NSPoint(x: panel.frame.minX, y: top))
        }
    }

    private func showPanel(on screen: NSScreen?) {
        let panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
                             styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = makeHosting()
        panel.delegate = self
        self.panel = panel
        let place: @MainActor () -> Void = { [weak panel] in
            guard let panel, let frame = screen?.visibleFrame else { return }
            panel.setFrameTopLeftPoint(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.maxY - 40))
        }
        place()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        deactivation = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil,
                                                              queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        // Once SwiftUI has sized the content, keep the top where it belongs.
        DispatchQueue.main.async { place() }
    }

    /// A click outside the floating panel closes it, as for the popover; the color panel the editor's Custom color
    /// opens does not count.
    func windowDidResignKey(_ notification: Notification) {
        guard let resigned = notification.object as? NSPanel, resigned === panel else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel === resigned, !Self.colorPanelInUse, NSApp.keyWindow !== resigned else { return }
            self.close()
        }
    }

    /// The popover stays open while the person uses the color panel.
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        !Self.colorPanelInUse
    }

    private static var colorPanelInUse: Bool {
        guard NSColorPanel.sharedColorPanelExists else { return false }
        let panel = NSColorPanel.shared
        return panel.isKeyWindow || (panel.isVisible && NSApp.currentEvent?.window === panel)
    }

    // MARK: - Closing

    func close() {
        popover?.performClose(nil)
        popover = nil
        if let panel {
            self.panel = nil
            panel.orderOut(nil)
        }
        finish()
    }

    /// A click outside closed the popover. A popover closed by `close()` was already let go.
    func popoverDidClose(_ notification: Notification) {
        guard let closed = notification.object as? NSPopover, closed === popover else { return }
        closedByClickAt = Date()
        popover = nil
        if panel == nil { finish() }
    }

    private func finish() {
        if let deactivation { NotificationCenter.default.removeObserver(deactivation) }
        deactivation = nil
        watcher?.stop()
        watcher = nil
        display = nil   // a late editor or main-window callback then shows nothing
        switch content.page {
        case .editor(let draft)? where draft.state != .closed: draft.cancel()
        case .main(let model)?: model.close()
        default: break
        }
        content.page = nil
    }

    // MARK: - Following the store

    /// While the main window is open, a change from `dnm` or another run updates its label and Undo (T040). A store
    /// that does not exist yet is not watched; nothing can change it but this window.
    private func watch() {
        watcher?.stop()
        watcher = try? StoreWatcher(store: controller.labeler.store) { [weak self] in
            if case .main(let model)? = self?.content.page { model.storeChanged() }
        }
    }
}

/// A panel that can become key, so its field takes typing.
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
