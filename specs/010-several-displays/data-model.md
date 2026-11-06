# Data Model: Several Displays in One Command (spec 010)

**Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

## Stored data

**No change.** The manifest stays format 3 (spec 009). A command on several displays writes, for each display, the
same records a single command writes today: the stamp, its `lastSeen`, and one `ChangeRecord` per display with its
own 60-second window (FR-008). No record of a "batch" exists, so `undo` is always per display.

## In-memory values

| Value | Holds | Rules |
|---|---|---|
| `DisplayArguments.Targets` | the displays to act on, in order; the override notices | Order: display words, then `--display` values, as given; a display named more than once (by any name) appears once, at its first place. Every value resolved before it is returned; an empty value is refused. |
| `DisplayArguments.SetRequest` | `Targets` and the label | At most one display word (the last word is the label); further displays only with `--display`. |
| `DisplayArguments.Target` (unchanged) | one display and its notice | Used by `show` only; two different displays are refused with "Multiple displays for a single command are not currently supported." |
| `DisplayBatch` progress | the displays changed so far, in order | Grows as each display succeeds; on an error it is reported in the message and the error's case (and so the exit status) is kept. |

## State per display during a command

```text
resolved ──(all checks pass)──► changing ──► changed
    │                              │
    └─(a check fails: nothing      └─(fails: stop; earlier displays stay changed,
       changed on any display)        later ones are never attempted)
```
