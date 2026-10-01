import Foundation

/// The parts of a display that matter for drawing: size in points, pixels per point,
/// and the menu bar and Dock insets.
public struct DisplayGeometry: Equatable, Sendable {
    public var pointWidth: Double
    public var pointHeight: Double
    public var scale: Double
    public var insetTop: Double
    public var insetLeft: Double
    public var insetBottom: Double
    public var insetRight: Double

    public init(pointWidth: Double, pointHeight: Double, scale: Double,
                insetTop: Double = 0, insetLeft: Double = 0, insetBottom: Double = 0, insetRight: Double = 0) {
        self.pointWidth = pointWidth
        self.pointHeight = pointHeight
        self.scale = scale
        self.insetTop = insetTop
        self.insetLeft = insetLeft
        self.insetBottom = insetBottom
        self.insetRight = insetRight
    }

    public var pixelWidth: Int { Int((pointWidth * scale).rounded()) }
    public var pixelHeight: Int { Int((pointHeight * scale).rounded()) }
}

/// A connected display. `uuid` is the stable identity used for storage and is never printed.
public struct Display: Equatable, Sendable {
    public var name: String
    public var uuid: String
    public var isMain: Bool
    public var geometry: DisplayGeometry

    public init(name: String, uuid: String, isMain: Bool, geometry: DisplayGeometry) {
        self.name = name
        self.uuid = uuid
        self.isMain = isMain
        self.geometry = geometry
    }
}

/// How the system places an image on a display.
public struct WallpaperPlacement: Equatable, Sendable {
    public var scaling: UInt
    public var clipping: Bool
    /// Archived `NSColor`, if any.
    public var fillColor: Data?

    public init(scaling: UInt, clipping: Bool, fillColor: Data?) {
        self.scaling = scaling
        self.clipping = clipping
        self.fillColor = fillColor
    }
}

/// What a display currently shows. `url` is nil when the system reports no wallpaper file.
public struct CurrentWallpaper: Equatable, Sendable {
    public var url: URL?
    public var placement: WallpaperPlacement

    public init(url: URL?, placement: WallpaperPlacement) {
        self.url = url
        self.placement = placement
    }
}

/// The only way the tool touches the real wallpaper and displays. Tests use a fake.
public protocol WallpaperSystem {
    func displays() throws -> [Display]
    func currentWallpaper(on display: Display) throws -> CurrentWallpaper
    func setWallpaper(_ url: URL, placement: WallpaperPlacement, on display: Display) throws
}
