# Data model: The menu-bar app and label editor (spec 014)

The label store (format 3) is unchanged and not repeated here; see spec 001 and spec 009. This file covers what the app
adds. None of it is stored in the label store.

## AppSettings (kept in the app's user defaults; keys in contracts/app-settings.md)

| Field | Type | Default | Rules |
|---|---|---|---|
| menuBarMode | `iconAndText` \| `icon` \| `hidden` | `iconAndText` | FR-010 |
| hotkey | Shortcut (key code, modifiers), optional | none | FR-014; opens the main window; set only after a successful registration (FR-015); at least two of ⌃⌥⌘, or ⌘ with ⇧; Escape, Return, Tab, Space alone refused |
| editorHotkey | Shortcut (key code, modifiers), optional | none | FR-014; opens the editor ("Style and Preview"); the same rules as hotkey, and never equal to it |
| defaultLook | automatic \| plain \| halo \| frosted | automatic | FR-006, FR-018; app only |
| defaultColor | automatic \| light \| dark \| #RRGGBB | automatic | as `dnm set --color` |
| defaultPosition | the six positions | bottom-left | as `dnm set --position` |
| defaultSize | small \| medium \| large | medium | as `dnm set --size` |
| cleanUpDays | Int, 1 to 3650 | 30 (`DesktopLabeler.defaultCleanupDays`) | the age Clean Up lists by |
| welcomeShown | Bool | false | set true when the welcome window is dismissed or closed (FR-017a) |

Open at login is not a field: `SMAppService.mainApp.status` is read whenever it is shown (R4).

An unreadable or out-of-range value falls back to its default; nothing is migrated in M2.

## EditorDraft (in memory; dropped on Cancel or close)

| Field | Type | Notes |
|---|---|---|
| display | the display the editor was opened for | fixed while open |
| text | String | checked as typed with `LabelText`'s rules: one line, 1 to 30 characters |
| look, color, position, size | as `LabelOptions` (each may be automatic) | start from the current label's values if the Desktop has one, else from AppSettings |
| backdrop | the Desktop's original image composed for the display, at preview size | loaded once when the editor opens |
| preview | the latest rendered preview and chip images | coalesced; the newest request wins |
| state | see below | |
| message | one sentence or none | FR-008, FR-009 |

States:

```text
loading ──► ready ◄──► invalid          (text or options change)
   │          │
   │          ├─► applying ──► closed   (success)
   │          │        └─────► ready + message  (failure; nothing changed)
   │          └─► removing ──► closed
   └─► unsupported (wallpaper the app will not label: message, no Apply; Remove still offered if labeled)
```

`applying` and `removing` cannot be entered twice (Edge Cases: one Apply at a time).

## MenuBarState (in memory; recomputed on every signal in research R5)

| Field | Type | Notes |
|---|---|---|
| activeDisplay | Display or none | R5 |
| currentLabel | Label or none | from the wallpaper the active display shows and the store |
| itemTitle | String or none | mode `iconAndText`: the app's fixed text; else none. Never the label (FR-010) |
| undoAvailable | Bool | `checkUndo` passes for the active display |
| cleanUpWarning | bytes or none | set while `cleanupPlan(days: AppSettings.cleanUpDays)` could free at least 50 MB (FR-016b) |

The Clean Up warning, the space labeled images use and the count of labels in use are computed when the main window
opens and when the Clean Up, Configuration or Labels pane opens, not on every Desktop switch (they read stamp file
sizes).

## QuickLabel (in memory; the main window's field, FR-013a)

| Field | Type | Notes |
|---|---|---|
| display | the display the main window was opened on | fixed while open |
| text | String | the current label, selected, or empty; checked as typed with `LabelText`'s rules, as EditorDraft |
| options | `LabelOptions` | the current label's options if the Desktop has one, else AppSettings' defaults; never shown or changed here |
| state | `ready`, `invalid`, `applying`, then closed | Label (or Return) is off while `invalid`, or while the text equals the current label |

Applying calls the same `LabelingController` Apply as the editor, so the result, the undo record and the errors are
the same (FR-007).

## CleanUpModel (in memory)

The `CleanupPlan` for `cleanUpDays`, its total, the person's selection (a subset of its candidates; none at first),
and the confirmation step. Deleting calls `carryOut(_:)` with a plan holding only the selected candidates (the plan's
`candidates` are public, so no core change is needed); `carryOut` re-checks them under the store lock (spec 009) and
reports what it deleted.

## PrototypeReview (a document, `prototypes/REVIEW.md`)

For each round: date, stage (1 mockups, 2 editor), what was shown, the maintainer's decisions, and the changes made.
Ends with the approval line for each stage (FR-002, SC-007).
