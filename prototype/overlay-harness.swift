import AppKit
// Test harness: (1) does desktopImageURL track the active Space in a long-running process?
// (2) does a desktop-level, non-joining window stay on its Space and survive Show Desktop?
let start = Date()
func log(_ s: String) { print(String(format: "[%6.2f] ", Date().timeIntervalSince(start)) + s); fflush(stdout) }
typealias MainConn = @convention(c) () -> Int32
typealias Active = @convention(c) (Int32) -> UInt64
let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
let conn = unsafeBitCast(dlsym(h, "SLSMainConnectionID")!, to: MainConn.self)()
let active = unsafeBitCast(dlsym(h, "SLSGetActiveSpace")!, to: Active.self)
func snapshot(_ why: String) {
    let urls = NSScreen.screens.map { NSWorkspace.shared.desktopImageURL(for: $0)?.lastPathComponent ?? "nil" }
    log("\(why): space=\(active(conn)) urls=\(urls) overlayOnActiveSpace=\(window.isOnActiveSpace) visible=\(window.isVisible)")
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let screen = NSScreen.screens[0]
let size = NSSize(width: 420, height: 70)
let frame = NSRect(x: screen.frame.maxX - size.width - 60, y: screen.visibleFrame.minY + 40, width: size.width, height: size.height)
let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
window.isOpaque = false
window.backgroundColor = .clear
window.ignoresMouseEvents = true
window.hasShadow = false
window.collectionBehavior = [.stationary, .ignoresCycle]   // no canJoinAllSpaces: lives on the Space it was created on
let label = NSTextField(labelWithString: "Overlay Test")
label.font = .systemFont(ofSize: 40, weight: .semibold)
label.textColor = .systemYellow
label.frame = NSRect(origin: .zero, size: size)
label.alignment = .right
window.contentView!.addSubview(label)
window.orderFrontRegardless()
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in snapshot("spaceChanged") }
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { snapshot("start") }
DispatchQueue.main.asyncAfter(deadline: .now() + Double(CommandLine.arguments.dropFirst().first ?? "30")!) { snapshot("end"); exit(0) }
app.run()
