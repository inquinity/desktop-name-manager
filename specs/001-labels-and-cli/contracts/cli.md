# Contract: `dnm` command-line interface

The binary is `dnm`. The same binary is installed as `desktop-name` and behaves
identically (FR-013). Commands never prompt and never read from standard input.

```text
dnm set <label> [--display <name>] [--desktop <n>] [--position <p>] [--size <s>] [--style <look>] [--color <c>]
dnm remove [--display <name>] [--desktop <n>]
dnm undo   [--display <name>] [--desktop <n>]
dnm show   [--display <name>] [--desktop <n>] [--json]
dnm prune  [--yes] [--json]
dnm about
dnm check  [--json]
dnm list   [--json]
dnm displays [--json]
dnm --help | dnm <command> --help | dnm --version
```

## Common behavior

- **Target**: commands that act on a Desktop (`set`, `remove`, `undo`, `show`) act on the
  current Desktop of the display chosen by `--display`, or of the main display when it is
  omitted (FR-023).
- **`--display <value>`**: `main`; or a display's name as macOS shows it
  (case-insensitive); or a partial name matching exactly one connected display. No match or
  more than one match exits `2`, prints the candidates, and changes nothing. Numbers and
  position keywords are not accepted.
- **Cleanup**: every command first deletes retired stamps older than the cool-down (30
  minutes) and our own unreferenced files older than that (FR-018, FR-026). It prints nothing about this
  unless it fails.
- **Streams**: results on standard output; messages, warnings and errors on standard
  error. With `--json`, standard output holds exactly one JSON document and nothing else.
- **No change on failure**: any command that exits non-zero leaves the wallpaper as it
  found it.

## `--desktop <n>` (set, remove, undo, show)

Acts on Desktop `n` of the chosen display, numbered as Mission Control numbers them, then returns to the
Desktop the display started on (FR-027). Not given: no switching and no permission. Given, it always
switches (to learn where the display is), so it needs the Accessibility permission and the "Move left/right a space" shortcuts; the
Desktops slide on screen and the person must not type meanwhile.

| Situation | Exit | Message (standard error) |
|---|---|---|
| `n` is not a positive whole number | 2 | `--desktop takes a Desktop number, 1 or more.` |
| The display has fewer than `n` Desktops | 2 | `<display> has <k> Desktops; there is no Desktop <n>. Nothing was changed.` |
| Accessibility not granted | 1 | Says why it is needed and where to grant it (System Settings > Privacy & Security > Accessibility on macOS 26, Device Control and Data Access on macOS 27, for the app running `dnm`). Never prompts. |
| Shortcuts turned off | 1 | Names the two shortcuts and where to turn them on. |
| A step cannot be confirmed | 1 | Says so; the display is returned to its starting Desktop. |
| The person (or another app) switched Desktops meanwhile | 1 | Says so and that `dnm` did not switch back (the position is unknown); if it happened while labeling, says to check with `dnm show`. |

The `set` confirmation names the Desktop when `--desktop` was given, for example
`Labeled "LABEL1" on DP, Desktop 2 (plain, light text, bottom-left, medium).` Labeling Desktop 1 adds no
note: new Desktops copying the left-most Desktop's wallpaper is documented in the README (FR-028).

## `dnm prune`

Lists labeled images that are no longer an active label (removed, replaced or undone through `dnm`), with
the space they use, and warns that a Desktop still showing one would lose its wallpaper. Deletes them only
with `--yes`; never deletes an image shown on any display's current Desktop. Exit `0`.

## `dnm set <label>`

Labels the target Desktop. A label is 1 to 30 characters after trimming, on one line, with no control
characters (escape, tab and so on) or text-direction marks; emoji are allowed and count as one
character each (FR-006, FR-007). A rejected label exits `2`.

| Option | Values | Default |
|---|---|---|
| `--position` | `bottom-left`, `bottom-right`, `top-left`, `top-right`, `bottom`, `top` | `bottom-left` |
| `--size` | `small`, `medium`, `large` | `medium` |
| `--style` | `plain`, `halo`, `frosted` | chosen automatically |
| `--color` | `light`, `dark`, or `#RRGGBB` | chosen automatically |

- Options the user leaves out use their default; they never inherit from a label being
  replaced (FR-009).
- Output (human): one line naming the display, the label, and the style and color chosen,
  for example `Labeled "Email" on Built-in Display (frosted, light text, bottom-left, medium).`
- Replacing an existing label keeps the recorded original.
- Exits `3` without changes on unsupported wallpaper (FR-014); `2` on invalid input.

## `dnm remove`

Restores the target Desktop's original image, placement and fill color exactly (FR-008).

- If the Desktop has no label: prints `No label on <display>.`, changes nothing, exits `0`.
- If the original file cannot be found (moved without a resolvable bookmark, or deleted):
  prints why and what to do (choose a wallpaper in System Settings), changes nothing,
  exits `1`.

## `dnm undo`

Reverses the most recent `set`, `replace` or `remove` made on the display, if it is within
the cool-down and the display's current wallpaper still equals what that change produced
(FR-022). One level only.

- Output states what was restored, for example `Restored label "Email" on Built-in Display
  (removed 4 minutes ago).`
- Exits `1` with a reason and no change when there is nothing to undo, the cool-down has
  expired, the current wallpaper no longer matches, or the needed file is gone.

## `dnm show`

Prints the target Desktop's label details: text, look, text color, position, size, which of
those were chosen automatically, when it was set, and whether an original is recorded.
A Desktop with no label prints `No label on <display>.` and exits `0`.

JSON shape:

```json
{
  "display": { "name": "Built-in Display", "isMain": true },
  "labeled": true,
  "label": {
    "text": "Email",
    "look": "frosted",
    "textColor": "light",
    "position": "bottom-left",
    "size": "medium",
    "automatic": ["look", "textColor"]
  },
  "createdAt": "2026-09-30T14:03:11Z",
  "originalRecorded": true,
  "stampMissing": false
}
```

## `dnm list`

Lists every labeled Desktop the tool knows plus the current Desktop of each connected
display, with the current ones marked (FR-011). Human output always ends with the line:

```text
Only labeled and current Desktops are shown.
```

JSON shape (the same sentence appears as `scope`):

```json
{
  "scope": "Only labeled and current Desktops are shown.",
  "desktops": [
    {
      "display": "Built-in Display",
      "connected": true,
      "current": true,
      "label": "Email",
      "stampMissing": false
    },
    {
      "display": "LG HDR 4K",
      "connected": true,
      "current": true,
      "label": null
    }
  ]
}
```

- `label` is `null` for a current Desktop with no label.
- `stampMissing` is `true` when the stamp file for a labeled Desktop is gone. `set` rebuilds
  it from the recorded original and `remove` still restores the original. Human output of
  `show` and `list` says so in words.
- A labeled Desktop whose display is not connected has `"connected": false`.
- The JSON never includes display UUIDs or file paths.

## `dnm displays`

Lists connected displays by the names `--display` accepts, marking the main display
(FR-024).

```text
Built-in Display   (main)
LG HDR 4K
```

```json
{ "displays": [ { "name": "Built-in Display", "isMain": true },
                { "name": "LG HDR 4K", "isMain": false } ] }
```

## `dnm about`

Prints the tool's name, version (as `--version` prints it), license, source location, data directory
(home shown as `~`), the permissions statement, and the acknowledgements (FR-030). Exit `0`. No JSON form.
The acknowledgements end the output:

```text
Acknowledgements:
  swift-argument-parser 1.8.2 - Apache License 2.0 with Runtime Library Exception
    https://github.com/apple/swift-argument-parser/blob/1.8.2/LICENSE.txt
Full license texts are in Licenses/.
```

## `dnm check`

Prints one line per item, in this order: macOS (version and chip), Separate Spaces, Displays (main
marked), Accessibility (for the app running `dnm`), Space shortcuts (always "cannot be read", with where to
look), Stored labels (active labels, images, space, what `prune` could
free). Each line starts with `ok`, `fix`, `?` or nothing (information); a `fix` or `?` line is followed by
how to fix or where to look. Changes nothing, takes no lock and never prompts for a permission (FR-031).
Exit `0`. `--json`: `{ "items": [ { "name", "state": "ok" | "attention" | "unknown" | "info", "detail",
"fix": string or null } ] }`.

## Exit codes (FR-013)

| Code | Meaning |
|---|---|
| `0` | Success, including "nothing to remove". |
| `1` | Failure: file access denied (the system's error is shown), file missing, disk error, undo not possible, a newer manifest format. |
| `2` | Invalid input: bad label, bad option value, unknown or ambiguous `--display`. |
| `3` | Unsupported wallpaper (dynamic, catalog, video, shuffle, or none reported). |

## Stability

The command names, option names, exit codes and JSON field names above are the contract
for scripts. New JSON fields may be added; existing ones are not renamed or removed
without a major version.
