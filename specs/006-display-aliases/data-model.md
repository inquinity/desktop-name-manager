# Data Model: Display Aliases (Feature F2)

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## 1. Entities

### `DisplayAlias`

A user-configured alias mapped to a display's stable identity.

```swift
public struct DisplayAlias: Codable, Equatable, Sendable {
    /// The user-defined short name (e.g. "DP1", "desk"). Unique case-insensitively; the capitalization
    /// given last is kept.
    public var name: String

    /// The display's UUID (Display.uuid). Shown only when no name was recorded.
    public var displayUUID: String

    /// The display's name as macOS showed it when the alias was set, for showing the alias while the
    /// display is not connected. Optional so that a record without it still decodes.
    public var displayName: String?
}
```

There is no timestamp: nothing reads it, and the store is not a history.

---

## 2. Manifest Schema Updates

Aliases are stored inside the existing `manifest.json` file.

### Schema Definition

```swift
public struct Manifest: Codable, Equatable, Sendable {
    /// The newest version this build reads and writes.
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var stamps: [Stamp]
    public var changes: [ChangeRecord]
    public var aliases: [DisplayAlias]
}
```

### JSON Representation

The identities below are placeholders (not UUID-shaped, so the hygiene scan stays clean); never commit real display UUIDs.

```json
{
  "schemaVersion": 2,
  "stamps": [],
  "changes": [],
  "aliases": [
    {
      "name": "desk",
      "displayUUID": "<uuid of the built-in display>",
      "displayName": "Built-in Retina Display"
    },
    {
      "name": "DP1",
      "displayUUID": "<uuid of the external display>",
      "displayName": "LG Ultra HD"
    }
  ]
}
```

---

## 3. Versions, Compatibility & Decoding

- Decoding uses `decodeIfPresent([DisplayAlias].self, forKey: .aliases) ?? []`, so a version 1 manifest
  (from 0.1.0) decodes with no aliases.
- This build reads versions 1 and 2, and refuses anything newer (the existing check in `Store`).
- Every write saves **version 2**.
- An older release that meets version 2 stops with its "newer than this tool understands" message and
  changes nothing. Backward compatibility is not kept; that is an accepted risk at 0.1 (one user, no
  downgrades).
- Writing any modification preserves all existing `stamps`, `changes` and `aliases`.

---

## 4. Concurrency & Integrity

- All writes (set, move, remove) execute inside `Store.transaction`:
  - Acquires `manifest.lock`.
  - Reads the current manifest.
  - Updates the `aliases` array.
  - Atomically writes the updated manifest with owner-only (`0600`) permissions.
- Uniqueness is enforced on the lowercased name. Setting an alias whose name already exists replaces that
  entry: the new capitalization, display identity and display name.
- Listing reads the manifest without the lock and never creates the store.
