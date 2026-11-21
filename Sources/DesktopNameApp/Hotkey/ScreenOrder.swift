import CoreGraphics

/// The order a hotkey moves its window in (spec 014, FR-014): displays left to right by their frames, the higher one
/// first where two share a left edge, wrapping from the last to the first.
public enum ScreenOrder {
    /// The index in `frames` after `current`, or nil with fewer than two frames or `current` out of range.
    public static func next(after current: Int, frames: [CGRect]) -> Int? {
        guard frames.count > 1, frames.indices.contains(current) else { return nil }
        let ordered = frames.indices.sorted {
            frames[$0].minX != frames[$1].minX ? frames[$0].minX < frames[$1].minX : frames[$0].maxY > frames[$1].maxY
        }
        guard let position = ordered.firstIndex(of: current) else { return nil }
        return ordered[(position + 1) % ordered.count]
    }
}
