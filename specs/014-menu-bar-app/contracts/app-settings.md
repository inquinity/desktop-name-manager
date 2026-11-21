# Contract: app settings (spec 014)

Stored in the app's user defaults, in the domain of its bundle ID (`.dev` for development builds). `dnm` never reads
them (FR-018). Fields and rules are in data-model.md (AppSettings).

| Key | Type | Default |
|---|---|---|
| `menuBarMode` | String: `iconAndText`, `icon`, `hidden` | `iconAndText` |
| `hotkeyKeyCode` | Int (virtual key code), or absent | absent (no hotkey) |
| `hotkeyModifiers` | Int (Carbon modifier mask), or absent | absent (no hotkey) |
| `editorHotkeyKeyCode` | Int (virtual key code), or absent | absent (no editor hotkey) |
| `editorHotkeyModifiers` | Int (Carbon modifier mask), or absent | absent (no editor hotkey) |
| `defaultLook` | String: `automatic`, `plain`, `halo`, `frosted` | `automatic` |
| `defaultColor` | String: `automatic`, `light`, `dark`, `#RRGGBB` | `automatic` |
| `defaultPosition` | String: `bottom-left`, `bottom-right`, `top-left`, `top-right`, `bottom`, `top` | `bottom-left` |
| `defaultSize` | String: `small`, `medium`, `large` | `medium` |
| `cleanUpDays` | Int, 1 to 3650 | `30` |
| `welcomeShown` | Bool | `false` |

Values use the same spellings as `dnm set`'s options, so the README can describe both in one vocabulary. An unknown or
invalid value is read as the default and is not rewritten until the person changes that setting.

There is a main hotkey exactly when both `hotkey…` keys are present, and an editor hotkey exactly when both
`editorHotkey…` keys are present (FR-014). Each pair is written only after the shortcut was registered; a shortcut that
cannot be claimed, or that the other hotkey uses, is shown with its error in Settings but not stored (FR-015).
Clearing a shortcut removes its two keys. `menuBarMode` is `hidden` only while the main hotkey is stored; at launch, a
stored `hidden` with no main hotkey that can be claimed is rewritten to `iconAndText` (FR-014a). A stored shortcut that is invalid, or equal to the main one, is read as
absent.

Removing the app's settings (`defaults delete <bundle ID>`) returns the app to a first launch: the welcome window shows
again. The label store is not affected.
