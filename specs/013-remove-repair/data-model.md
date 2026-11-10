# Data Model: `remove` repairs a misreported Desktop (Feature F6)

No stored-data change: the manifest stays format 3.

## Read

| Field (existing) | Use |
|---|---|
| `Stamp.displayUUID` | Only labels of this display are matched (spec FR-003) |
| `Stamp.original` (path, bookmark, placement, fill) | Resolved and compared with the reported file (research R2); its placement is what is set |
| `Stamp.createdAt` | The most recent label wins when several share one original |

## Written

| When | What |
|---|---|
| A repair | `lastSeen` of the labels whose images show on current Desktops (as `remove` does today); nothing else |
| No match | Nothing |

## In memory

`RemoveLabelOutcome` gains `.repaired` beside `.removed(Label)` and `.noLabel`.
