// dnm-prototype: put a quiet text label on the wallpaper of the current macOS Space.
//
// The label is rendered into a copy of the Space's current wallpaper and set
// with the public NSWorkspace API, which only affects the Space currently shown
// on that display. macOS then keeps the image attached to that Space (by UUID)
// across reboots, reordering and Show Desktop. Nothing keeps running afterwards.
//
// The only private interfaces used are read-only and optional: SkyLight's
// space list (for `list` and for naming the Space in output) and the wallpaper
// store plist (for `list` and a "Show on all Spaces" warning). If either
// breaks in a future macOS, labeling still works.

import AppKit
import CoreImage
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
import Vision

let version = "0.2.0"
let appName = "dnm-prototype"

// MARK: - Errors and output

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

func warn(_ message: String) { FileHandle.standardError.write(Data("\(appName): \(message)\n".utf8)) }

// MARK: - Options

enum Position: String, CaseIterable {
    case auto
    case bottomLeft = "bottom-left", bottomRight = "bottom-right"
    case topLeft = "top-left", topRight = "top-right"
    case center, bottomCenter = "bottom-center", topCenter = "top-center"
}

/// How the text is separated from the picture behind it.
enum Look: String, CaseIterable {
    case auto
    case plain      // text with a soft shadow
    case halo       // text with a strong, wide shadow
    case pill       // text on a translucent rounded rectangle
    case frosted    // text on a blurred, tinted rounded rectangle
}

enum TextColor: Hashable {
    case auto, white, black
    case custom(r: Double, g: Double, b: Double)

    init?(_ raw: String) {
        switch raw.lowercased() {
        case "auto": self = .auto
        case "white": self = .white
        case "black": self = .black
        default:
            let hex = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
            guard hex.count == 6, let v = UInt32(hex, radix: 16) else { return nil }
            self = .custom(r: Double(v >> 16 & 0xff) / 255, g: Double(v >> 8 & 0xff) / 255, b: Double(v & 0xff) / 255)
        }
    }
}

struct Style: Hashable {
    var position: Position = .bottomLeft
    var size = 0.03          // font size as a fraction of screen height
    var opacity = 0.85
    var look: Look = .auto
    var textColor: TextColor = .auto
}

enum DisplayChoice: Equatable { case active, mouse, all, index(Int) }

struct Options {
    var command = "set"
    var label: String?
    var style = Style()
    var display = DisplayChoice.active
    var base: URL?
    var preview: URL?
    var canvas: Geometry?
    var verbose = false
}

let usage = """
usage: dnm-prototype [options] <label>      label the current Space's wallpaper
       dnm-prototype clear [options]        restore the unlabeled wallpaper on this Space
       dnm-prototype list                   show every Space and its label
       dnm-prototype --version | --help

options:
  --display active|mouse|all|N   which display's current Space (default: active,
                                 the display with the focused window)
  --position P                   bottom-left (default), bottom-right, bottom-center,
                                 top-left, top-right, top-center, center, or auto
                                 (the calmest corner)
  --style S                      auto (default), plain, halo, pill, frosted
  --text-color C                 auto (default), white, black or #RRGGBB
  --size F                       font size as a fraction of screen height (default 0.03)
  --opacity F                    text opacity 0-1 (default 0.85)
  --base FILE                    image to label instead of the Space's current wallpaper
  --preview FILE                 render to FILE (.jpg/.png) and do not change the wallpaper
  --canvas WxH@S[,dock=N]        with --preview: render for a screen of W x H points at
                                 scale S instead of a real display (testing aid)
  --verbose                      print the background analysis and timings

Use "\\n" in the label for a second line, e.g. dnm-prototype 'Status Report\\nweekly'.
Run dnm-prototype while you are on the Space you want to label.
"""

func parseArguments(_ args: [String]) throws -> Options {
    var options = Options()
    var words: [String] = []
    var i = 0
    func value(_ flag: String) throws -> String {
        i += 1
        guard i < args.count else { throw Failure("\(flag) needs a value") }
        return args[i]
    }
    func fraction(_ flag: String, _ range: ClosedRange<Double>) throws -> Double {
        let raw = try value(flag)
        guard let v = Double(raw), range.contains(v) else {
            throw Failure("\(flag) must be a number in \(range.lowerBound)...\(range.upperBound), got \(raw)")
        }
        return v
    }
    func path(_ flag: String) throws -> URL {
        URL(fileURLWithPath: (try value(flag) as NSString).expandingTildeInPath)
    }
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "-h", "--help": options.command = "help"
        case "--version": options.command = "version"
        case "--verbose", "-v": options.verbose = true
        case "--display":
            let raw = try value(arg)
            switch raw {
            case "active": options.display = .active
            case "mouse": options.display = .mouse
            case "all": options.display = .all
            default:
                guard let n = Int(raw), n >= 1 else { throw Failure("--display must be active, mouse, all or a number") }
                options.display = .index(n)
            }
        case "--position":
            let raw = try value(arg)
            guard let p = Position(rawValue: raw) else {
                throw Failure("--position must be one of: \(Position.allCases.map(\.rawValue).joined(separator: ", "))")
            }
            options.style.position = p
        case "--style":
            let raw = try value(arg)
            guard let l = Look(rawValue: raw) else {
                throw Failure("--style must be one of: \(Look.allCases.map(\.rawValue).joined(separator: ", "))")
            }
            options.style.look = l
        case "--text-color":
            let raw = try value(arg)
            guard let c = TextColor(raw) else { throw Failure("--text-color must be auto, white, black or #RRGGBB") }
            options.style.textColor = c
        case "--size": options.style.size = try fraction(arg, 0.005...0.5)
        case "--opacity": options.style.opacity = try fraction(arg, 0.05...1)
        case "--base": options.base = try path(arg)
        case "--preview": options.preview = try path(arg)
        case "--canvas":
            let raw = try value(arg)
            guard let g = Geometry(spec: raw) else { throw Failure("--canvas must look like 2560x1440@2 or 1920x1200@1,dock=90") }
            options.canvas = g
        case "--": words.append(contentsOf: args[(i + 1)...]); i = args.count
        default:
            if arg.hasPrefix("-") && arg.count > 1 { throw Failure("unknown option \(arg)") }
            words.append(arg)
        }
        i += 1
    }
    if options.command == "set", let first = words.first, ["clear", "list"].contains(first) {
        options.command = first
        words.removeFirst()
    }
    if options.command == "set" {
        let label = words.joined(separator: " ").replacingOccurrences(of: "\\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { throw Failure("missing label\n\n\(usage)") }
        options.label = label
    } else if !words.isEmpty, options.command != "help" {
        throw Failure("unexpected argument: \(words[0])")
    }
    if options.canvas != nil && options.preview == nil { throw Failure("--canvas only works with --preview") }
    return options
}

// MARK: - Storage

let storeDir: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent(appName, isDirectory: true)
let manifestURL = storeDir.appendingPathComponent("manifest.json")

/// What we need to undo a label: the image we started from and how it was placed.
struct ManifestEntry: Codable {
    var base: String
    var label: String
    var display: String
    var scaling: UInt
    var clipping: Bool
    var fill: [Double]?          // v0.1: sRGB RGBA
    var fillArchive: Data?       // v0.2: the NSColor itself, so its color space round-trips exactly
    var created: Date

    var fillColor: NSColor? {
        if let data = fillArchive {
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        }
        return fill.map { NSColor(srgbRed: $0[0], green: $0[1], blue: $0[2], alpha: $0[3]) }
    }
}

func loadManifest() -> [String: ManifestEntry] {
    guard let data = try? Data(contentsOf: manifestURL) else { return [:] }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return (try? decoder.decode([String: ManifestEntry].self, from: data)) ?? [:]
}

func saveManifest(_ manifest: [String: ManifestEntry]) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
}

func isOurs(_ url: URL) -> Bool {
    url.standardizedFileURL.deletingLastPathComponent().path == storeDir.standardizedFileURL.path
}

// MARK: - Screens and Spaces

/// The parts of a screen that matter for drawing: size in points, pixels per point,
/// and the menu bar / Dock insets (from visibleFrame).
struct Geometry {
    var size: CGSize
    var scale: CGFloat
    var insets: NSEdgeInsets

    var pixelWidth: Int { Int((size.width * scale).rounded()) }
    var pixelHeight: Int { Int((size.height * scale).rounded()) }

    init(screen: NSScreen) {
        let frame = screen.frame, visible = screen.visibleFrame
        size = frame.size
        let pixelWidth = CGDisplayCopyDisplayMode(screen.displayID)?.pixelWidth ?? 0
        scale = pixelWidth > 0 ? CGFloat(pixelWidth) / frame.width : screen.backingScaleFactor
        insets = NSEdgeInsets(top: frame.maxY - visible.maxY, left: visible.minX - frame.minX,
                              bottom: visible.minY - frame.minY, right: frame.maxX - visible.maxX)
    }

    /// "2560x1440@2" or "1920x1200@1,dock=90"
    init?(spec: String) {
        let parts = spec.split(separator: ",")
        let main = parts[0].split(separator: "@")
        let dims = main[0].split(separator: "x").compactMap { Double($0) }
        guard dims.count == 2, main.count == 2, let s = Double(main[1]) else { return nil }
        size = CGSize(width: dims[0], height: dims[1])
        scale = s
        var dock = 0.0
        for extra in parts.dropFirst() {
            let kv = extra.split(separator: "=")
            if kv.count == 2, kv[0] == "dock", let d = Double(kv[1]) { dock = d } else { return nil }
        }
        insets = NSEdgeInsets(top: 30, left: 0, bottom: dock, right: 0)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
    var displayUUID: String {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return "" }
        return CFUUIDCreateString(nil, uuid) as String
    }
}

func targetScreens(_ choice: DisplayChoice) throws -> [NSScreen] {
    let screens = NSScreen.screens
    guard !screens.isEmpty else { throw Failure("no displays found") }
    switch choice {
    case .all: return screens
    case .active: return [NSScreen.main ?? screens[0]]
    case .mouse:
        let p = NSEvent.mouseLocation
        return [screens.first { NSMouseInRect(p, $0.frame, false) } ?? screens[0]]
    case .index(let n):
        guard n <= screens.count else { throw Failure("--display \(n): only \(screens.count) display(s) attached") }
        return [screens[n - 1]]
    }
}

struct SpaceInfo { let uuid: String; let number: Int; let fullscreen: Bool }
struct DisplaySpaces { let displayUUID: String; let current: String?; let spaces: [SpaceInfo] }

/// Read-only view of Mission Control's Space list via SkyLight (private, optional).
func managedSpaces() -> [DisplaySpaces]? {
    typealias MainConnection = @convention(c) () -> Int32
    typealias CopySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
          let connSym = dlsym(handle, "SLSMainConnectionID") ?? dlsym(handle, "CGSMainConnectionID"),
          let copySym = dlsym(handle, "SLSCopyManagedDisplaySpaces") ?? dlsym(handle, "CGSCopyManagedDisplaySpaces")
    else { return nil }
    let connection = unsafeBitCast(connSym, to: MainConnection.self)()
    guard let raw = unsafeBitCast(copySym, to: CopySpaces.self)(connection)?.takeRetainedValue() as? [[String: Any]]
    else { return nil }
    return raw.map { display in
        var desktopNumber = 0
        let spaces = ((display["Spaces"] as? [[String: Any]]) ?? []).map { space -> SpaceInfo in
            let fullscreen = (space["type"] as? Int ?? 0) != 0
            if !fullscreen { desktopNumber += 1 }
            return SpaceInfo(uuid: space["uuid"] as? String ?? "", number: fullscreen ? 0 : desktopNumber, fullscreen: fullscreen)
        }
        let current = (display["Current Space"] as? [String: Any])?["uuid"] as? String
        return DisplaySpaces(displayUUID: display["Display Identifier"] as? String ?? "", current: current, spaces: spaces)
    }
}

func describeCurrentSpace(on screen: NSScreen) -> String {
    guard let all = managedSpaces() else { return screen.localizedName }
    // With "Displays have separate Spaces" off, SkyLight reports a single "Main" entry.
    let entry = all.first { $0.displayUUID == screen.displayUUID } ?? (all.count == 1 ? all[0] : nil)
    guard let entry, let current = entry.current,
          let space = entry.spaces.first(where: { $0.uuid == current }) else { return screen.localizedName }
    return space.fullscreen ? "a full-screen Space on \(screen.localizedName)"
                            : "Desktop \(space.number) on \(screen.localizedName)"
}

// MARK: - Wallpaper store (read-only, private format, best effort)

let wallpaperIndexURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")

func loadWallpaperIndex() -> [String: Any]? {
    guard let data = try? Data(contentsOf: wallpaperIndexURL) else { return nil }
    return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
}

/// File URL of the desktop wallpaper stored for a Space on a display, if it is a plain image file.
func storedWallpaper(index: [String: Any], space: String, display: String) -> URL? {
    guard let entry = (index["Spaces"] as? [String: Any])?[space] as? [String: Any] else { return nil }
    let perDisplay = (entry["Displays"] as? [String: Any])?[display] as? [String: Any]
    let slot = perDisplay ?? entry["Default"] as? [String: Any]
    guard let desktop = slot?["Desktop"] as? [String: Any],
          let choice = ((desktop["Content"] as? [String: Any])?["Choices"] as? [[String: Any]])?.first,
          let blob = choice["Configuration"] as? Data,
          let config = try? PropertyListSerialization.propertyList(from: blob, format: nil) as? [String: Any],
          let relative = (config["url"] as? [String: Any])?["relative"] as? String
    else { return nil }
    return URL(string: relative)
}

func showOnAllSpacesIsOn() -> Bool {
    guard let all = loadWallpaperIndex()?["AllSpacesAndDisplays"] as? [String: Any] else { return false }
    return all["Desktop"] != nil
}

// MARK: - Loading and composing the backdrop

func loadImage(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        throw Failure("cannot read image \(url.path)")
    }
    let index = CGImageSourceGetPrimaryImageIndex(source)
    if CGImageSourceGetCount(source) > 1 {
        warn("\(url.lastPathComponent) holds several images (dynamic wallpaper); labeling its main image, which will be static")
    }
    guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
          let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int
    else { throw Failure("cannot read image size of \(url.path)") }
    // A full-size "thumbnail" is the simplest way to get EXIF orientation applied.
    let thumbOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: max(w, h),
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, thumbOptions as CFDictionary) else {
        throw Failure("cannot decode image \(url.path)")
    }
    return image
}

struct Placement { var scaling: NSImageScaling; var clipping: Bool; var fill: NSColor? }

/// Where the wallpaper image lands on a canvas, mirroring macOS's placement options.
func imageRect(image: CGSize, canvas: CGSize, placement: Placement) -> CGRect {
    let fitScale = min(canvas.width / image.width, canvas.height / image.height)
    let fillScale = max(canvas.width / image.width, canvas.height / image.height)
    let scale: CGFloat
    switch placement.scaling {
    case .scaleAxesIndependently: return CGRect(origin: .zero, size: canvas)
    case .scaleNone: scale = 1
    case .scaleProportionallyDown: scale = min(1, fitScale)
    default: scale = placement.clipping ? fillScale : fitScale
    }
    let size = CGSize(width: image.width * scale, height: image.height * scale)
    return CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2,
                  width: size.width, height: size.height)
}

func makeContext(width: Int, height: Int, colorSpace: CGColorSpace) throws -> CGContext {
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    else { throw Failure("cannot create a \(width)x\(height) drawing surface") }
    ctx.interpolationQuality = .high
    return ctx
}

/// The wallpaper exactly as macOS would show it on this screen, at the screen's pixel size.
func composeBackdrop(base: CGImage, placement: Placement, geometry: Geometry) throws -> CGImage {
    let colorSpace = base.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = try makeContext(width: geometry.pixelWidth, height: geometry.pixelHeight, colorSpace: colorSpace)
    let canvas = CGSize(width: geometry.pixelWidth, height: geometry.pixelHeight)
    ctx.setFillColor((placement.fill ?? .black).usingColorSpace(.sRGB)?.cgColor ?? NSColor.black.cgColor)
    ctx.fill(CGRect(origin: .zero, size: canvas))
    ctx.draw(base, in: imageRect(image: CGSize(width: base.width, height: base.height), canvas: canvas, placement: placement))
    guard let image = ctx.makeImage() else { throw Failure("rendering failed") }
    return image
}

// MARK: - Background analysis

/// A small sRGB copy of the backdrop plus a Vision attention map, for judging label spots.
struct Sampler {
    let width: Int, height: Int
    let luminance: [Float]       // WCAG relative luminance, 0...1
    let lightness: [Float]       // CIE L*, 0...1
    let saliency: (w: Int, h: Int, values: [Float])?

    init(backdrop: CGImage) {
        let width = 1024
        let height = max(1, Int((Double(backdrop.height) * 1024 / Double(backdrop.width)).rounded()))
        self.width = width
        self.height = height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        pixels.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: srgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            ctx.interpolationQuality = .medium
            ctx.draw(backdrop, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let linear = (0..<256).map { v -> Float in
            let c = Float(v) / 255
            return c <= 0.04045 ? c / 12.92 : powf((c + 0.055) / 1.055, 2.4)
        }
        var lum = [Float](repeating: 0, count: width * height)
        var light = lum
        for i in 0..<(width * height) {
            let y = 0.2126 * linear[Int(pixels[i * 4])] + 0.7152 * linear[Int(pixels[i * 4 + 1])] + 0.0722 * linear[Int(pixels[i * 4 + 2])]
            lum[i] = y
            light[i] = (y > 0.008856 ? 1.16 * cbrtf(y) - 0.16 : 9.033 * y)
        }
        luminance = lum
        lightness = light

        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let small = pixels.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                      space: srgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)?.makeImage()
        }
        if let small, (try? VNImageRequestHandler(cgImage: small).perform([request])) != nil,
           let observation = request.results?.first {
            let buffer = observation.pixelBuffer
            CVPixelBufferLockBaseAddress(buffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
            let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
            let rowFloats = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<Float>.size
            let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: Float.self)
            var values = [Float](repeating: 0, count: w * h)
            for row in 0..<h { for col in 0..<w { values[row * w + col] = base[row * rowFloats + col] } }
            let peak = max(values.max() ?? 1, 0.0001)
            saliency = (w, h, values.map { $0 / peak })
        } else {
            saliency = nil
        }
    }

    /// Statistics for a rectangle given as fractions of the screen, origin at the bottom left.
    func stats(_ unit: CGRect) -> RegionStats {
        let x0 = max(0, Int(unit.minX * CGFloat(width))), x1 = min(width - 1, Int(unit.maxX * CGFloat(width)))
        let y0 = max(0, Int((1 - unit.maxY) * CGFloat(height))), y1 = min(height - 1, Int((1 - unit.minY) * CGFloat(height)))
        var sum: Float = 0, sumSq: Float = 0, gradient: Float = 0, badWhite = 0, badBlack = 0, n = 0
        for y in y0...max(y0, y1) {
            for x in x0...max(x0, x1) {
                let i = y * width + x
                let l = luminance[i]
                sum += l; sumSq += l * l; n += 1
                if x < x1 && y < y1 {
                    gradient += abs(lightness[i + 1] - lightness[i]) + abs(lightness[i + width] - lightness[i])
                }
                if 1.05 / (l + 0.05) < 3 { badWhite += 1 }        // white text contrast under 3:1
                if (l + 0.05) / 0.05 < 3 { badBlack += 1 }        // black text contrast under 3:1
            }
        }
        let count = Float(max(n, 1))
        let mean = sum / count
        var salient: Float = 0
        if let s = saliency {
            let sx0 = Int(unit.minX * CGFloat(s.w)), sx1 = max(sx0, min(s.w - 1, Int(unit.maxX * CGFloat(s.w))))
            let sy0 = Int((1 - unit.maxY) * CGFloat(s.h)), sy1 = max(sy0, min(s.h - 1, Int((1 - unit.minY) * CGFloat(s.h))))
            var total: Float = 0, cells: Float = 0
            for y in max(0, sy0)...sy1 { for x in max(0, sx0)...sx1 { total += s.values[y * s.w + x]; cells += 1 } }
            salient = total / max(cells, 1)
        }
        return RegionStats(meanLuminance: Double(mean), spread: Double(sqrtf(max(0, sumSq / count - mean * mean))),
                           busyness: Double(gradient / count), badWhite: Double(badWhite) / Double(count),
                           badBlack: Double(badBlack) / Double(count), saliency: Double(salient))
    }
}

struct RegionStats {
    var meanLuminance: Double   // WCAG relative luminance
    var spread: Double          // standard deviation of luminance
    var busyness: Double        // mean L* change between neighbouring samples
    var badWhite: Double        // share of the area where white text would fall under 3:1 contrast
    var badBlack: Double        // same for black text
    var saliency: Double        // Vision attention, 0 (ignored) ... 1 (the subject)

    var summary: String {
        String(format: "lum %.2f±%.2f busy %.3f weak-contrast white %.0f%% black %.0f%% saliency %.2f",
               meanLuminance, spread, busyness, badWhite * 100, badBlack * 100, saliency)
    }
}

struct Treatment { var look: Look; var lightText: Bool; var reason: String }

/// The decision rules. Contrast first (can plain text be read here?), then texture
/// (will the texture fight the letterforms?), then fall back to a backing.
func chooseTreatment(_ s: RegionStats, style: Style) -> Treatment {
    let lightText: Bool
    switch style.textColor {
    case .white: lightText = true
    case .black: lightText = false
    case .custom(let r, let g, let b): lightText = 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.5
    case .auto:
        if abs(s.badWhite - s.badBlack) > 0.05 {
            lightText = s.badWhite < s.badBlack
        } else {
            // Both read about equally: compare average contrast, leaning to white, which suits photos.
            let whiteRatio = 1.05 / (s.meanLuminance + 0.05), blackRatio = (s.meanLuminance + 0.05) / 0.05
            lightText = whiteRatio * 1.3 >= blackRatio
        }
    }
    if style.look != .auto { return Treatment(look: style.look, lightText: lightText, reason: "chosen") }
    let weak = lightText ? s.badWhite : s.badBlack
    if weak < 0.05 && s.busyness < 0.035 { return Treatment(look: .plain, lightText: lightText, reason: "calm, high contrast") }
    if weak < 0.20 && s.busyness < 0.07 { return Treatment(look: .halo, lightText: lightText, reason: "some texture or weak spots") }
    return Treatment(look: .frosted, lightText: lightText, reason: weak >= 0.20 ? "mid-tones, neither white nor black reads" : "busy texture")
}

/// Lower is better: avoid the subject, texture and places where no text color works.
func spotCost(_ s: RegionStats) -> Double {
    3 * s.saliency + 6 * s.busyness + 1.5 * min(s.badWhite, s.badBlack)
}

// MARK: - Layout and drawing

struct Layout {
    var box: CGRect             // points, origin bottom-left
    var textRect: CGRect
    var font: NSFont
    var alignment: NSTextAlignment
}

func textAttributes(font: NSFont, alignment: NSTextAlignment) -> [NSAttributedString.Key: Any] {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    return [.font: font, .kern: font.pointSize * 0.01, .paragraphStyle: paragraph]
}

func layout(label: String, position: Position, style: Style, geometry: Geometry, look: Look) -> Layout {
    let fontSize = geometry.size.height * style.size
    let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    let alignment: NSTextAlignment = [.bottomRight, .topRight].contains(position) ? .right
        : [.center, .bottomCenter, .topCenter].contains(position) ? .center : .left
    // Measure with exactly the attributes used to draw, or long labels wrap into a box one line short.
    let textSize = NSAttributedString(string: label, attributes: textAttributes(font: font, alignment: alignment)).boundingRect(
        with: CGSize(width: geometry.size.width * 0.8, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading]).size
    let backed = look == .pill || look == .frosted
    let padX = backed ? fontSize * 0.55 : 0, padY = backed ? fontSize * 0.3 : 0
    let box = CGSize(width: ceil(textSize.width) + 2 + padX * 2, height: ceil(textSize.height) + padY * 2)

    // Keep clear of the menu bar and Dock; visibleFrame reflects both.
    let w = geometry.size.width, h = geometry.size.height, insets = geometry.insets
    let margin = h * 0.035
    let left = insets.left + margin, right = w - insets.right - margin - box.width
    let bottom = insets.bottom + margin, top = h - max(insets.top, 40) - margin - box.height
    let midX = (w - box.width) / 2, midY = (h - box.height) / 2
    let origin: CGPoint
    switch position {
    case .bottomLeft, .auto: origin = CGPoint(x: left, y: bottom)
    case .bottomRight: origin = CGPoint(x: right, y: bottom)
    case .bottomCenter: origin = CGPoint(x: midX, y: bottom)
    case .topLeft: origin = CGPoint(x: left, y: top)
    case .topRight: origin = CGPoint(x: right, y: top)
    case .topCenter: origin = CGPoint(x: midX, y: top)
    case .center: origin = CGPoint(x: midX, y: midY)
    }
    let boxRect = CGRect(origin: origin, size: box)
    return Layout(box: boxRect, textRect: boxRect.insetBy(dx: padX, dy: padY), font: font, alignment: alignment)
}

struct RenderResult { var image: CGImage; var position: Position; var treatment: Treatment; var stats: RegionStats; var notes: [String] }

func render(backdrop: CGImage, label: String, geometry: Geometry, style: Style) throws -> RenderResult {
    let sampler = Sampler(backdrop: backdrop)
    var notes: [String] = []
    func unitRect(_ r: CGRect) -> CGRect {
        // Judge a slightly larger area than the text itself; shadows and eyes spill over.
        let grown = r.insetBy(dx: -r.height * 0.4, dy: -r.height * 0.4)
        return CGRect(x: grown.minX / geometry.size.width, y: grown.minY / geometry.size.height,
                      width: grown.width / geometry.size.width, height: grown.height / geometry.size.height)
    }

    var position = style.position
    if position == .auto {
        // Corners only: the centre and edges are where people put subjects and the Dock.
        let corners: [Position] = [.bottomLeft, .bottomRight, .topLeft, .topRight]
        let scored = corners.map { p -> (Position, Double, RegionStats) in
            let s = sampler.stats(unitRect(layout(label: label, position: p, style: style, geometry: geometry, look: .frosted).box))
            return (p, spotCost(s) + (p == .bottomLeft ? 0 : 0.1), s)   // mild preference for a consistent spot
        }
        position = scored.min { $0.1 < $1.1 }!.0
        notes.append("spots: " + scored.map { String(format: "%@ %.2f", $0.0.rawValue, $0.1) }.joined(separator: ", "))
    }
    let probe = layout(label: label, position: position, style: style, geometry: geometry, look: .frosted)
    let stats = sampler.stats(unitRect(probe.box))
    let treatment = chooseTreatment(stats, style: style)
    let lay = layout(label: label, position: position, style: style, geometry: geometry, look: treatment.look)

    let colorSpace = backdrop.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = try makeContext(width: backdrop.width, height: backdrop.height, colorSpace: colorSpace)
    ctx.draw(backdrop, in: CGRect(x: 0, y: 0, width: backdrop.width, height: backdrop.height))
    let scale = geometry.scale
    let fontSize = lay.font.pointSize
    let radius = lay.box.height * 0.3

    if treatment.look == .frosted {
        // Blur what is behind the box, then tint it, like a macOS material.
        let pixelBox = CGRect(x: lay.box.minX * scale, y: lay.box.minY * scale, width: lay.box.width * scale, height: lay.box.height * scale)
        let blurred = CIImage(cgImage: backdrop).clampedToExtent()
            .applyingGaussianBlur(sigma: Double(fontSize * 0.5 * scale))
            .cropped(to: CGRect(x: 0, y: 0, width: backdrop.width, height: backdrop.height))
        if let blurImage = CIContext(options: [.workingColorSpace: colorSpace]).createCGImage(blurred, from: pixelBox) {
            ctx.saveGState()
            ctx.addPath(CGPath(roundedRect: pixelBox, cornerWidth: radius * scale, cornerHeight: radius * scale, transform: nil))
            ctx.clip()
            ctx.draw(blurImage, in: pixelBox)
            ctx.restoreGState()
        }
    }

    ctx.scaleBy(x: scale, y: scale)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let light = treatment.lightText
    let alpha = CGFloat(style.opacity)
    var attributes = textAttributes(font: lay.font, alignment: lay.alignment)
    switch style.textColor {
    case .custom(let r, let g, let b): attributes[.foregroundColor] = NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    default: attributes[.foregroundColor] = light ? NSColor(white: 1, alpha: alpha) : NSColor(white: 0, alpha: alpha * 0.85)
    }

    let shape = NSBezierPath(roundedRect: lay.box, xRadius: radius, yRadius: radius)
    switch treatment.look {
    case .frosted:
        (light ? NSColor(white: 0, alpha: 0.28) : NSColor(white: 1, alpha: 0.40)).setFill()
        shape.fill()
        (light ? NSColor(white: 1, alpha: 0.12) : NSColor(white: 0, alpha: 0.08)).setStroke()
        shape.lineWidth = 1 / scale
        shape.stroke()
    case .pill:
        (light ? NSColor(white: 0, alpha: 0.35) : NSColor(white: 1, alpha: 0.5)).setFill()
        shape.fill()
    case .plain, .halo, .auto:
        let shadow = NSShadow()
        let strong = treatment.look == .halo
        shadow.shadowColor = light ? NSColor(white: 0, alpha: strong ? 0.8 : 0.5) : NSColor(white: 1, alpha: strong ? 0.85 : 0.5)
        shadow.shadowBlurRadius = fontSize * (strong ? 0.4 : 0.22) * scale   // shadows ignore the CTM, so work in pixels
        shadow.shadowOffset = NSSize(width: 0, height: strong ? 0 : -fontSize * 0.03 * scale)
        attributes[.shadow] = shadow
    }
    let text = NSAttributedString(string: label, attributes: attributes)
    text.draw(with: lay.textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    if treatment.look == .halo {
        // A second pass tightens the glow right around the letters.
        var tight = attributes
        let inner = NSShadow()
        inner.shadowColor = (attributes[.shadow] as? NSShadow)?.shadowColor
        inner.shadowBlurRadius = fontSize * 0.1 * scale
        tight[.shadow] = inner
        NSAttributedString(string: label, attributes: tight).draw(with: lay.textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    guard let result = ctx.makeImage() else { throw Failure("rendering failed") }
    return RenderResult(image: result, position: position, treatment: treatment, stats: stats, notes: notes)
}

func writeImage(_ image: CGImage, to url: URL) throws {
    let type = url.pathExtension.lowercased() == "png" ? UTType.png : UTType.jpeg
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
        throw Failure("cannot write \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { throw Failure("cannot write \(url.path)") }
}

// MARK: - Commands

func currentPlacement(for screen: NSScreen) -> Placement {
    let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
    let scaling = (options[.imageScaling] as? NSNumber).flatMap { NSImageScaling(rawValue: $0.uintValue) }
    return Placement(scaling: scaling ?? .scaleProportionallyUpOrDown,
                     clipping: (options[.allowClipping] as? NSNumber)?.boolValue ?? true,
                     fill: options[.fillColor] as? NSColor)
}

func workspaceOptions(_ p: Placement) -> [NSWorkspace.DesktopImageOptionKey: Any] {
    var options: [NSWorkspace.DesktopImageOptionKey: Any] = [
        .imageScaling: NSNumber(value: p.scaling.rawValue),
        .allowClipping: NSNumber(value: p.clipping),
    ]
    if let fill = p.fill { options[.fillColor] = fill }
    return options
}

/// The unlabeled wallpaper for this Space and how it was placed.
func baseWallpaper(for screen: NSScreen, manifest: [String: ManifestEntry]) throws -> (URL, Placement) {
    guard let current = NSWorkspace.shared.desktopImageURL(for: screen) else {
        throw Failure("\(screen.localizedName): no wallpaper file reported for this Space; pass --base FILE")
    }
    guard isOurs(current) else { return (current, currentPlacement(for: screen)) }
    guard let entry = manifest[current.lastPathComponent] else {
        throw Failure("\(current.lastPathComponent) was made by \(appName) but is missing from its manifest; pass --base FILE")
    }
    return (URL(fileURLWithPath: entry.base),
            Placement(scaling: NSImageScaling(rawValue: entry.scaling) ?? .scaleProportionallyUpOrDown,
                      clipping: entry.clipping, fill: entry.fillColor))
}

func slug(_ text: String) -> String {
    let mapped = text.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" }
    let collapsed = String(String(mapped).split(separator: "-").joined(separator: "-").prefix(40))
    return collapsed.isEmpty ? "label" : collapsed
}

final class Stopwatch {
    private var last = DispatchTime.now()
    private(set) var laps: [(String, Double)] = []
    func lap(_ name: String) {
        let now = DispatchTime.now()
        laps.append((name, Double(now.uptimeNanoseconds - last.uptimeNanoseconds) / 1e6))
        last = now
    }
    var summary: String { laps.map { String(format: "%@ %.0fms", $0.0, $0.1) }.joined(separator: ", ") }
}

func report(_ result: RenderResult, _ clock: Stopwatch, verbose: Bool) {
    guard verbose else { return }
    for note in result.notes { print("  \(note)") }
    print("  \(result.position.rawValue): \(result.stats.summary)")
    print("  style: \(result.treatment.look.rawValue), \(result.treatment.lightText ? "light" : "dark") text (\(result.treatment.reason))")
    print("  time: \(clock.summary)")
}

func setLabel(_ options: Options) throws {
    let label = options.label!
    var manifest = loadManifest()
    if options.preview == nil {
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        if showOnAllSpacesIsOn() {
            warn("\"Show on all Spaces\" is on in Wallpaper settings; macOS may apply this label to every Space the first time. Turn it off, then run dnm-prototype again on each Space.")
        }
    }

    if let canvas = options.canvas, let preview = options.preview {
        guard let baseURL = options.base else { throw Failure("--canvas needs --base") }
        let clock = Stopwatch()
        let base = try loadImage(baseURL); clock.lap("load")
        let backdrop = try composeBackdrop(base: base, placement: Placement(scaling: .scaleProportionallyUpOrDown, clipping: true, fill: nil),
                                           geometry: canvas); clock.lap("compose")
        let result = try render(backdrop: backdrop, label: label, geometry: canvas, style: options.style); clock.lap("label")
        try writeImage(result.image, to: preview); clock.lap("write")
        print("wrote \(preview.path) (\(result.image.width)x\(result.image.height))")
        report(result, clock, verbose: options.verbose)
        return
    }

    for screen in try targetScreens(options.display) {
        let clock = Stopwatch()
        let geometry = Geometry(screen: screen)
        var (baseURL, placement) = try baseWallpaper(for: screen, manifest: manifest)
        if let explicit = options.base { baseURL = explicit }
        let base = try loadImage(baseURL); clock.lap("load")
        let backdrop = try composeBackdrop(base: base, placement: placement, geometry: geometry); clock.lap("compose")
        let result = try render(backdrop: backdrop, label: label, geometry: geometry, style: options.style); clock.lap("label")

        if let preview = options.preview {
            let out = options.display == .all && NSScreen.screens.count > 1
                ? preview.deletingPathExtension().appendingPathExtension("\(screen.displayID).\(preview.pathExtension)")
                : preview
            try writeImage(result.image, to: out); clock.lap("write")
            print("wrote \(out.path) (\(result.image.width)x\(result.image.height))")
            report(result, clock, verbose: options.verbose)
            continue
        }

        let modified = (try? baseURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let s = options.style
        let key = [baseURL.path, "\(modified?.timeIntervalSince1970 ?? 0)", label, "\(geometry.pixelWidth)x\(geometry.pixelHeight)",
                   s.position.rawValue, "\(s.size)", "\(s.opacity)", s.look.rawValue, "\(s.textColor)",
                   "\(placement.scaling.rawValue)", "\(placement.clipping)", "\(geometry.insets)", version]
            .joined(separator: "\u{1f}")
        let digest = SHA256.hash(data: Data(key.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        // A new name per content avoids WallpaperAgent serving a cached image for a reused path.
        let out = storeDir.appendingPathComponent("\(slug(label))-\(digest).jpg")
        if !FileManager.default.fileExists(atPath: out.path) { try writeImage(result.image, to: out) }
        clock.lap("write")

        let fillArchive = try placement.fill.map { try NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
        manifest[out.lastPathComponent] = ManifestEntry(base: baseURL.path, label: label, display: screen.displayUUID,
                                                        scaling: placement.scaling.rawValue, clipping: placement.clipping,
                                                        fill: nil, fillArchive: fillArchive, created: Date())
        try saveManifest(manifest)
        // The image already matches the screen exactly, so "fill" is lossless whatever the base placement was.
        let setPlacement = Placement(scaling: .scaleProportionallyUpOrDown, clipping: true, fill: placement.fill)
        try NSWorkspace.shared.setDesktopImageURL(out, for: screen, options: workspaceOptions(setPlacement))
        clock.lap("set")
        print("labeled \(describeCurrentSpace(on: screen)): \"\(label.replacingOccurrences(of: "\n", with: " / "))\"")
        report(result, clock, verbose: options.verbose)
    }
}

func clearLabel(_ options: Options) throws {
    let manifest = loadManifest()
    for screen in try targetScreens(options.display) {
        guard let current = NSWorkspace.shared.desktopImageURL(for: screen), isOurs(current) else {
            print("\(describeCurrentSpace(on: screen)) has no \(appName) label")
            continue
        }
        let (baseURL, placement) = try baseWallpaper(for: screen, manifest: manifest)
        guard FileManager.default.fileExists(atPath: baseURL.path) else {
            throw Failure("original wallpaper \(baseURL.path) no longer exists; choose one in System Settings > Wallpaper")
        }
        try NSWorkspace.shared.setDesktopImageURL(baseURL, for: screen, options: workspaceOptions(placement))
        print("cleared \(describeCurrentSpace(on: screen)); restored \(baseURL.lastPathComponent)")
    }
}

func listLabels() throws {
    guard let displays = managedSpaces() else {
        throw Failure("cannot read the Space list on this macOS version (SkyLight interface changed)")
    }
    guard let index = loadWallpaperIndex() else {
        throw Failure("cannot read \(wallpaperIndexURL.path)")
    }
    let manifest = loadManifest()
    let names = Dictionary(NSScreen.screens.map { ($0.displayUUID, $0.localizedName) }, uniquingKeysWith: { a, _ in a })
    for display in displays {
        print(names[display.displayUUID] ?? "Display \(display.displayUUID)")
        for space in display.spaces {
            let title = space.fullscreen ? "Full screen" : "Desktop \(space.number)"
            let marker = space.uuid == display.current ? "*" : " "
            var detail = "(no label)"
            if let url = storedWallpaper(index: index, space: space.uuid, display: display.displayUUID) {
                if isOurs(url), let entry = manifest[url.lastPathComponent] {
                    detail = "\"\(entry.label.replacingOccurrences(of: "\n", with: " / "))\""
                } else {
                    detail = "(no label: \(url.lastPathComponent))"
                }
            }
            print("  \(marker) \(title.padding(toLength: 12, withPad: " ", startingAt: 0)) \(detail)")
        }
    }
}

// MARK: - Main

do {
    let options = try parseArguments(Array(CommandLine.arguments.dropFirst()))
    switch options.command {
    case "help": print(usage)
    case "version": print("\(appName) \(version)")
    case "clear": try clearLabel(options)
    case "list": try listLabels()
    default: try setLabel(options)
    }
} catch {
    warn("\(error)")
    exit(1)
}
