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

/// Shows the main window and the editor (spec 014, T034, T040, T045, T063): in an `NSPopover` under the menu-bar item,
/// or, when a hotkey opens it and the item is hidden or not on the display chosen, in a floating panel near the top of
/// that display. One main
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
    /// True while the editor shown was opened by the editor hotkey (its Cancel closes the window).
    private var editorClosesWindow = false
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

    /// A hotkey (FR-014, the table in contracts/app-ui.md). Nothing open: its page for the active display. Its own
    /// page open: the window moves to the next display (it stays with one display). The other page open: that page
    /// is swapped in on the same display. A hotkey never hides the window.
    func hotkey(_ kind: HotkeyKind, itemButton: NSStatusBarButton?) {
        guard isShown, let display else {
            open(kind, on: ActiveDisplay.forHotkey(), itemButton: itemButton)
            return
        }
        if showing != kind {
            // Switched to from the main window, the editor's Cancel goes back there.
            keepPanelTop()
            if kind == .editor { openEditor(closesWindowOnCancel: false) } else { showMainPage(for: display) }
            focus()
        } else if let next = ActiveDisplay.nextScreen(after: display),
                  ActiveDisplay.display(for: next, system: controller.labeler.system) != nil {   // never a hide
            close()
            open(kind, on: next, itemButton: itemButton)
        } else {
            focus()
        }
    }

    /// The page shown now.
    private var showing: HotkeyKind? {
        switch content.page {
        case .main?: .main
        case .editor?: .editor
        case nil: nil
        }
    }

    /// Under the item when it is shown on `screen`; else (hidden, or on another display's menu bar) in the panel.
    private func open(_ kind: HotkeyKind, on screen: NSScreen?, itemButton: NSStatusBarButton?) {
        let button = itemButton.flatMap { ActiveDisplay.same($0.window?.screen, screen) ? $0 : nil }
        showMain(about: screen, under: button, page: kind)
    }

    private func focus() {
        NSApp.activate()
        (popover?.contentViewController?.view.window ?? panel)?.makeKey()
    }

    private func showMain(about screen: NSScreen?, under button: NSStatusBarButton?, page: HotkeyKind = .main) {
        guard let display = ActiveDisplay.display(for: screen, system: controller.labeler.system) else { return }
        self.display = display
        if page == .editor { openEditor(closesWindowOnCancel: true) } else { showMainPage(for: display) }
        watch()
        rereadAfterSwitch()
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
        var model: MainWindowModel?
        // The actions act only while their own main window is the page shown: one a hotkey swapped out does nothing.
        let isCurrent: () -> Bool = { [unowned self] in
            if case .main(let shown)? = content.page, let model { return shown === model }
            return false
        }
        model = MainWindowModel(display: display, controller: controller, settings: settings, actions: MainWindowActions(
            openEditor: { [unowned self] in if isCurrent() { openEditor(closesWindowOnCancel: false) } },
            openSettings: { [unowned self] pane in if isCurrent() { close(); openSettings(pane) } },
            quit: { NSApp.terminate(nil) },
            close: { [unowned self] in if isCurrent() { close() } }))
        setPage(model.map(PanelContent.Page.main))
    }

    /// Shows `page` and lets the one it replaces go: a pending change in it is not made (FR-014's page switch).
    private func setPage(_ page: PanelContent.Page?) {
        let old = content.page
        content.page = page
        switch old {
        case .editor(let draft)? where draft.state != .closed: draft.cancel()
        case .main(let model)?: model.close()
        default: break
        }
    }

    /// "Style and Preview…": the editor replaces the main window in the same panel. Opened by the editor hotkey with
    /// nothing open (or moved to another display), its Cancel closes the window rather than going back to a main
    /// window the person never saw.
    private func openEditor(closesWindowOnCancel: Bool) {
        editorClosesWindow = closesWindowOnCancel
        keepPanelTop()
        guard let display else { return }
        let current = try? controller.labeler.currentLabel(on: display)
        let draft = EditorDraft(display: display, currentLabel: current, defaults: settings.newLabelOptions, actions: EditorActions(
            apply: { [controller] text, options in try controller.apply(text, options: options, on: display) },
            remove: { [controller] in try controller.remove(on: display) }))
        setPage(.editor(draft))
        // The picture loads off the main thread; the editor shows `loading` until it arrives (T034).
        Task { await draft.load { [controller] in try controller.labeler.previewOrigin(on: display) } }
    }

    /// Apply and Remove close the panel; Cancel and Escape go back to the main window, or close an editor the hotkey
    /// opened.
    private func editorClosed(_ draft: EditorDraft) {
        guard case .editor(let shown)? = content.page, shown === draft else { return }   // swapped out meanwhile
        if draft.changed || editorClosesWindow {
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
        setPage(nil)
    }

    // MARK: - Following the store

    /// macOS reports a new Desktop's wallpaper up to about 1.6 s after a switch (spike S1, research R5), so a window
    /// opened soon after one would name the previous Desktop's label. While the main window is open, read again at
    /// 0.5, 1, 1.5 and 2 s; the model keeps text the person has already typed.
    private func rereadAfterSwitch() {
        for delay in [0.5, 1.0, 1.5, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                if case .main(let model)? = self?.content.page { model.storeChanged() }
            }
        }
    }

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
