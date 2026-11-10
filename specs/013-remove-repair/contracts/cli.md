# CLI Contract: `remove` repairs a misreported Desktop (Feature F6)

Extends the `remove` contract of `specs/001-labels-and-cli/contracts/cli.md` and `specs/010-several-displays`.

## Usage

Unchanged: `dnm remove [<display> ...] [--display <display> ...] [--desktop N]` (spec Q1, proposed).

## Output

| Case | Standard output | Exit |
|---|---|---|
| A label shows (today) | `Removed the label "<label>" from <display> and restored the original wallpaper.` (unchanged) | 0 |
| No label, and the reported image is the original of a label of this display | `No label is recorded for this Desktop; dnm set its original wallpaper again, in case the screen still showed a label.` | 0 |
| No label, no match | `No label on <display>.` (unchanged) | 0 |
| A match whose original cannot be found | the missing-original error (unchanged) | 1 |

With several displays, each display gets its own line, in order. Quiet mode prints the repair line (a result).

## Help

`remove --help` adds one sentence: `If macOS reports a Desktop's original wallpaper while the screen still shows a
label (known issue KI-3), remove sets the original again.`

## Undo

A repair records no change; `dnm undo` is unaffected.
