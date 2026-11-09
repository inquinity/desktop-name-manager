# Data Model: `dnm cleanup --scan` (Feature F9)

No stored-data change: the manifest stays format 3. The scan writes only what spec 009 already stores (each label's
`lastSeen`, the nudge's `maintenance`, and deletions).

## In memory

### ScanResult

| Field | Meaning |
|---|---|
| `scanned` | The connected displays walked, in order, each with the image file names seen on its Desktops |
| `seen` | The union of those file names (what "shown by some Desktop" means) |
| `notConnected` | Each display that has labels in the store but is not connected: its recorded name and its label count |
| `separateSpaces` | Whether "Displays have separate Spaces" was on (one walk per display) or off (one walk, every display read at each stop) |

### Candidate (existing `CleanupCandidate`, spec 009)

A new reason, `notOnAnyDesktop`, beside `removed`, `replaced`, `undone` and `notSeen`. A stamp is a scan candidate
when:

1. its `displayUUID` is one of the scanned displays, and
2. its `fileName` is not in `seen`.

State (active or retired) does not matter. A stamp whose image file is missing is a candidate with size 0. Stamps of
displays in `notConnected` are never candidates.

## Writes

| When | One locked change |
|---|---|
| The person agrees to delete (or `--yes`) | Re-read the manifest; drop any candidate now showing on a display's current Desktop; mark every stamp in `seen` (and every image showing now) with `lastSeen = now`; remove the remaining candidates' records; clear `maintenance`; then delete their files |
| The person declines, or there is nothing to delete | Mark every stamp in `seen` with `lastSeen = now`; nothing else |
| Any failure or interrupt during the walk | Nothing is written |

## States of one run

```text
options checked → permission checked → described → (asked) → walking → scanned → reported → (asked) → deleted | kept
                                    ↘ no terminal / --json without --yes: described, exit 0
walking → failed (exit 1) | interrupted (exit 130): nothing written
```
