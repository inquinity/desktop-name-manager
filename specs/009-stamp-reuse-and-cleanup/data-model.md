# Data Model: Reuse and Cleanup (Feature F4)

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## 1. Changes to `Stamp`

```swift
public struct Stamp {
    // existing: id, fileName, label, original, displayUUID, displayName, pixelWidth, pixelHeight,
    //           createdAt, state, supersededBy
    /// SHA-256 (hex) of the reuse key (spec FR-007); nil for labels made before this version, which are never reused.
    public var reuseKey: String?
    /// The last time this label's image was the wallpaper of a display's current Desktop. Set to createdAt at creation.
    /// nil for labels made before this version: their age counts from createdAt.
    public var lastSeen: Date?
}
```

Both decode with `decodeIfPresent`, so a manifest from 0.2.0 reads unchanged.

## 2. The reuse key

SHA-256 over a canonical, length-prefixed encoding of, in order:

1. `rendererVersion` (an integer constant in `LabelRenderer`; bump it whenever the output of a render changes);
2. the original's path, file size and modification time (read when the key is computed; a changed file is a new key);
3. the original's placement (scaling, clipping, fill color bytes);
4. the label text (trimmed, as stored);
5. the requested look, text color, position and size (`nil` is written as "automatic");
6. the display's UUID, pixel width and height, scale and insets.

Only the key is stored, not the pieces. Two requests with the same key are expected to render the same image.

## 3. Maintenance state

```swift
public struct Maintenance: Codable {
    /// When the nudge was last shown and how many bytes it reported.
    public var nudgedAt: Date?
    public var nudgedBytes: Int64?
}
// Manifest.maintenance: Maintenance? — nil until first nudge; cleared by `cleanup`.
```

## 4. Candidate selection (shared by `cleanup`, the nudge and `check`)

```text
for each stamp S:
    skip if S's image is the wallpaper of any display's current Desktop
    skip if S is referenced by a change record (the undo window)
    if S is retired and retiredAt <= now - days          -> candidate (why: removed|replaced|undone, since retiredAt)
    if S is active  and (lastSeen ?? createdAt) <= now - days -> candidate (why: not seen, since lastSeen)
```

The estimate for the nudge is the sum of the candidates' file sizes with the default days; a missing file counts 0.

## 5. Schema

The manifest becomes schema version 3 (`maintenance`, `lastSeen`, `reuseKey` are new keys); this release reads 1, 2 and 3 and writes 3. Older releases refuse it (accepted at 0.x, as for version 2).
