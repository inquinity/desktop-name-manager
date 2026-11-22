# Contract: additions to DesktopNameCore (spec 014)

The app uses the same operations as `dnm` (`setLabel`, `removeLabel`, `undoLastChange`, `checkUndo`, `cleanupPlan`,
`carryOut`, `About.info`, `check`). It needs three small public additions. `dnm` does not call them and its behavior
does not change. Names are proposals; signatures are settled in implementation and tested.

## 1. Preview

```swift
public struct PreviewRequest: Sendable {
    public var text: LabelText
    public var options: LabelOptions
    public var maxPixelWidth: Int        // the preview's width in pixels
}

public struct PreviewSource { /* opaque: the Desktop's original composed for the display, at preview size */ }

extension DesktopLabeler {
    /// Loads the image `setLabel` would stamp for the Desktop on screen of `display` (the recorded original when the
    /// Desktop is labeled), composed for the display. Throws as `setLabel` would for an unsupported wallpaper,
    /// a missing original or a stamp from another store. Reads only.
    public func previewSource(on display: Display, maxPixelWidth: Int) throws -> PreviewSource
}

public enum LabelPreview {
    /// Renders with the same pipeline as `setLabel` (`LabelRenderer`), at the source's size. Returns the image and the
    /// label it would record (so "Automatic: frosted" can be shown). Pure; safe off the main thread.
    public static func render(_ request: PreviewRequest, source: PreviewSource) throws -> (image: CGImage, label: Label)
}
```

Tests: a preview's chosen look and color match `setLabel`'s for the same request over the test backdrops; the source
for a labeled Desktop is its original, not the stamp; an unsupported wallpaper throws the same error as `setLabel`.

## 2. The label a display is showing

```swift
extension DesktopLabeler {
    /// The label of the Desktop on screen of `display`, if the wallpaper is one of this store's stamps; nil for any
    /// other wallpaper. Reads only; takes no lock (a torn read cannot happen: the manifest is replaced atomically).
    public func currentLabel(on display: Display) throws -> Label?
}
```

This is what `dnm show` already determines; the function factors it out so both use one rule. Tests: labeled,
unlabeled, a stamp from another store (nil), a newer manifest (throws).

## 3. Store changes

```swift
public final class StoreWatcher {
    /// Calls `onChange` on the main queue, coalesced, after `manifest.json` in `store.directory` is replaced or
    /// removed. Watches the folder (the manifest is replaced by rename, so a watch on the file alone would be lost).
    public init(store: Store, onChange: @escaping @MainActor () -> Void) throws
    public func stop()
}
```

Tests: a transaction in the same process triggers one call; a burst of writes triggers one call; stopping ends calls.

## 4. Added while building the app (Phases 5 to 8)

Each is additive; `dnm` calls none of them except through the unchanged paths noted.

```swift
public struct PreviewOrigin: Sendable { /* opaque: the Desktop's original and the display's geometry */ }

extension DesktopLabeler {
    public let system: WallpaperSystem                   // was internal; the app lists displays and watches the store
    public let store: Store

    /// The cheap half of `previewSource(on:maxPixelWidth:)`, run where the wallpaper system may be read (the main
    /// thread); `previewSource(on:)` is now this followed by the static half, so its results are unchanged.
    public func previewOrigin(on display: Display) throws -> PreviewOrigin
    /// The expensive half, safe off the main thread (T034: the editor no longer loads its picture on the main thread).
    public static func previewSource(from origin: PreviewOrigin, maxPixelWidth: Int) throws -> PreviewSource

    /// `setAlias(_:display:)` for a display itself (the Displays pane, where two displays may share a name); the same
    /// rules and sentences. `setAlias(_:display:)` now resolves the display and shares the rest with it.
    public func setAlias(_ rawName: String, on display: Display) throws -> SetAliasResult
}

extension SystemWallpaperSystem {
    /// The display a screen shows, as `displays()` reports it (the menu bar that was clicked).
    @MainActor public static func display(for screen: NSScreen) -> Display
}

public struct CleanupPlan {
    public init(days: Int?, candidates: [CleanupCandidate])   // a plan of the selected candidates, for carryOut
}
public struct CleanupCandidate {
    public internal(set) var stampID: UUID                    // identifies a row in the Clean Up pane's selection
}
```
