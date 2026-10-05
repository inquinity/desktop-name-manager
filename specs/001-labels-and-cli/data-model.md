# Data Model: Desktop Labels and the `dnm` Command-Line Tool

Everything the tool stores is in one directory, `~/Library/Application Support/<store name>/`
(overridable with `DNM_STORE_DIR`). The store name is a constant in the core library,
`com.altmansoftwaredesign.desktop-name-manager`, with the suffix `.dev` in debug builds. The
CLI and the later app share it, so it does not depend on any app bundle:

```text
manifest.json        # all records, schema versioned
manifest.lock        # advisory lock held during every read-modify-write
<id>.dnm.<ext>       # one stamp per set operation (id is random; ext is the image format, jpg in v1)
```

The manifest is written atomically (write to a temporary file, then replace).

## Entities

### Display (not stored; read from the system)

| Field | Meaning |
|---|---|
| `name` | The name macOS shows, for example "Built-in Display". Used for `--display`. |
| `uuid` | Stable display identity from CoreGraphics. Stored in stamps; never printed in docs or committed. |
| `isMain` | True for the display macOS treats as the main display. |
| `pixelSize`, `insets` | Geometry used when composing the backdrop (menu bar, Dock). |

### Label (value; stored inside a Stamp)

| Field | Rules |
|---|---|
| `text` | One line, 1 to 30 characters after trimming; each emoji counts as one; no line breaks. |
| `look` | `plain`, `halo` or `frosted`. |
| `textColor` | `light`, `dark`, or an explicit color. |
| `position` | One of the corners or anchor positions; default `bottomLeft`. |
| `size` | A relative size; default from the prototype's scale. |
| `automatic` | Which of `look`, `textColor`, `position`, `size` were chosen by the tool rather than the user (for `show`). |

### Original (stored inside a Stamp)

What the Desktop showed before its first label.

| Field | Meaning |
|---|---|
| `path` | File path at labeling time. |
| `bookmark` | Bookmark data for the file, so a move or rename still resolves. |
| `scaling`, `clipping` | The placement mode exactly as macOS reported it. |
| `fillColor` | Archived `NSColor`, so its color space round-trips exactly. |

### Stamp (stored; one per set operation)

| Field | Meaning |
|---|---|
| `id` | Random identifier (a UUID). |
| `fileName` | The stamp's file name, `<id>.dnm.<ext>`; the extension is whatever format was written (`jpg` in v1), so the format can change later without breaking cleanup. |
| `label` | The Label above. |
| `original` | The Original above, carried unchanged across replacements (FR-009). |
| `displayUUID` | Display the stamp was made for. |
| `displayName` | The display's name at that time, so labels on a disconnected display can still be listed by name. |
| `geometry` | Pixel size and insets at render time. |
| `createdAt` | Time of the set operation. |
| `state` | `active`, or `retired(at, reason)` with reason `replaced`, `removed` or `undone`. Since the 2026-10-05 amendment this is bookkeeping for `undo` and `prune` only: other Desktops may still show a retired stamp, so the state never decides whether a Desktop is labeled. |
| `applied` | True once the stamp was set as a wallpaper. Applied stamps are deleted only by `prune`. |
| `supersededBy` | Optional: the stamp that replaced it (helps `undo` and `show`). |

### Change record (stored; one per display)

The last change made on a display, for `undo`.

| Field | Meaning |
|---|---|
| `displayUUID` | The display. |
| `kind` | `set`, `replace`, `remove`. |
| `at` | Time of the change. |
| `produced` | A `StateRef`: what the display's wallpaper became. |
| `before` | A `StateRef`: what it was before. |

A `StateRef` is either `stamp(id)` or `original(path, bookmark, scaling, clipping, fillColor)`.

After an undo the record is cleared (one level only).

## Relationships

- A Stamp has exactly one Original and one Label.
- A display has at most one active Stamp per Desktop. The tool cannot see Desktops that are
  not current, so it treats every active Stamp as "a labeled Desktop".
- A Change record points at up to two Stamps (`produced`, `before`).

## State transitions

```text
unlabeled ──set──▶ active stamp S1
S1 active ──set──▶ S1 retired(replaced), new active stamp S2 (same Original)
S1 active ──remove──▶ S1 retired(removed); Desktop shows the Original
retired (within cool-down) ──undo──▶ stamp active again, or Desktop shows the state before
retired (older than cool-down) ──any command──▶ file and entry deleted
```

- A Stamp file is deleted only when its entry is retired and older than the cool-down (30
  minutes), or when it has no manifest entry, is older than the cool-down, and its name
  matches `<uuid>.dnm.<ext>` exactly. Cleanup never deletes the manifest, the lock file,
  subfolders, or any file that does not match that pattern, and does nothing in a folder
  that has no manifest of ours.
- An active Stamp is never deleted.
- Undo is allowed only while the Change record is within the cool-down and the display's
  current wallpaper matches `produced`.

## Validation rules (from the spec)

- Label text: 1 to 30 characters, no line breaks, not only whitespace (FR-007).
- Options: valid enumerations and a size within the allowed range; rejected with a message
  and no change otherwise.
- `--display`: `main`, an exact name, or a unique partial name (FR-023).
- A set is refused for unsupported wallpaper kinds before anything is written (FR-014).

## Manifest schema versioning

The manifest has a top-level `schemaVersion` (starting at 1). A manifest with a newer
version than the tool knows is read-only: the tool reports it and changes nothing, so an
older binary never damages newer data.
