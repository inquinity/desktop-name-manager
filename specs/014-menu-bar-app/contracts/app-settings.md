# Contract: app settings (spec 014)

Stored in the app's user defaults, in the domain of its bundle ID (`.dev` for development builds). `dnm` never reads
them (FR-018). Fields and rules are in data-model.md (AppSettings).

| Key | Type | Default |
|---|---|---|
| `menuBarMode` | String: `iconAndText`, `icon`, `hidden` | `iconAndText` |
| `hotkeyKeyCode` | Int (virtual key code), or absent | absent (no hotkey) |
| `hotkeyModifiers` | Int (Carbon modifier mask), or absent | absent (no hotkey) |
| `defaultLook` | String: `automatic`, `plain`, `halo`, `frosted` | `automatic` |
| `defaultColor` | String: `automatic`, `light`, `dark`, `#RRGGBB` | `automatic` |
| `defaultPosition` | String: `bottom-left`, `bottom-right`, `top-left`, `top-right`, `bottom`, `top` | `bottom-left` |
| `defaultSize` | String: `small`, `medium`, `large` | `medium` |
| `cleanUpDays` | Int, 1 to 3650 | `30` |
| `welcomeShown` | Bool | `false` |

Values use the same spellings as `dnm set`'s options, so the README can describe both in one vocabulary. An unknown or
invalid value is read as the default and is not rewritten until the person changes that setting.

There is a hotkey exactly when both hotkey keys are present (FR-014). They are written only after the shortcut was
registered; a shortcut that cannot be claimed is shown with its error in Settings but not stored (FR-015). Clearing
the shortcut removes both keys.

Removing the app's settings (`defaults delete <bundle ID>`) returns the app to a first launch: the welcome window shows
again. The label store is not affected.
