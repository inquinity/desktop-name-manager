# Desktop-switching timings

How long macOS takes to switch Desktops when `dnm --desktop` presses "Move left/right a space", recorded
per machine and display setup. The numbers set `dnm`'s waits (`SystemDesktopSwitcher.confirmTimeout` and
`settleTime`) and spec 001's SC-008. They are kept relative to one baseline, so that a new macOS release
needs only the baseline re-measured to predict the rest.

## Method

- **Tool:** `prototype/switch-timing.swift` (research only, public interfaces only: the same key presses
  and the same `NSWorkspace.activeSpaceDidChangeNotification` that `--desktop` uses). It is run by
  `Tests/live/live-timing.sh`, which also times the real, read-only `dnm show --desktop` for every start
  Desktop and target.
- **Confirmation latency:** time from the key press to the notification that the active Desktop changed.
  `dnm` waits `confirmTimeout` for it; a step slower than that is wrongly treated as "nothing moved".
- **Gap test:** the next press comes 0, 50, 100, 150, 250 or 400 ms after the previous confirmation;
  lost or doubled steps show how much `settleTime` is needed.
- **Edge test:** a press at the first Desktop, where nothing should move, with a 2.5 s wait: a late
  notification there would mean the timeout cuts off real steps.
- **Samples:** 20 per measurement, so 140 steps per display (20 for confirmation, 20 for each gap).
- **Settings:** macOS defaults. Reduce Motion was measured once, to learn its effect; `dnm` does not ask
  people to change settings, so it is not part of the regular runs.

## The index

Each setup gets one number: its **slowest display's** median confirmation latency, as a percentage of the
baseline's. That is the display a delay has to cover. The table also keeps the maximum, which is what
the delay must exceed.

**Baseline (100%):** Apple M5 Pro, macOS 27.0.1 (26A434), three displays (built-in plus two LG monitors),
Reduce Motion off. The slowest display is the built-in one: **median 1006 ms, maximum 1023 ms**.

## Results

Confirmation latency of the slowest display in each setup. Median: the confirmation run (a rest between
steps). Max: every step, the confirmation run plus every gap.

| Setup | Date | Slowest display | Median | Max | Index (median) | Index (max) | Lost / doubled |
|---|---|---|---|---|---|---|---|
| **M5 Pro, 27.0.1, 3 displays (baseline)** | 2026-10-06 | Built-in | 1006 ms | 1023 ms | **100%** | **100%** | 0 / 0 |
| M5 Pro, 27.0.1, 2 displays | 2026-10-06 | Built-in | 986 ms | 1000 ms | 98.0% | 97.8% | 0 / 0 |
| M5 Pro, 27.0.1, 2 displays, Reduce Motion on (once, for information) | 2026-10-06 | Built-in | 978 ms | 998 ms | 97.2% | 97.6% | 0 / 0 |
| Intel MacBook Pro 16" (2019), 26.x, 2 displays | pending | | | | | | |
| Intel MacBook Pro 16" (2019), 26.x, 3 displays | pending | | | | | | |

Other displays measured (not the slowest in their setup):

| Setup | Display | Median | Max | Index (median) |
|---|---|---|---|---|
| M5 Pro, 27.0.1, 2 displays | DP (external) | 552 ms | 578 ms | 54.9% |
| M5 Pro, 27.0.1, 2 displays, Reduce Motion on | DP (external) | 554 ms | 582 ms | 55.1% |
| M5 Pro, 27.0.1, 3 displays | LG ULTRAFINE, LG Ultra HD | pending (the run stopped: LG ULTRAFINE had one Desktop) | | |

Gap and edge tests, every setup so far: no lost or doubled steps at any gap, including 0 ms; no late
notifications at the edge.

## What the numbers say so far

1. **`confirmTimeout` (1.0 s) is too short.** The baseline's slowest steps took 1023 ms, so on that setup
   a real step can be counted as "nothing moved". This is a functional bug, not a test artifact.
2. **`settleTime` (0.25 s) shows no benefit.** Pressing again immediately after a confirmation lost no
   steps on any display.
3. **Reduce Motion has no measurable effect** (97.2% against 98.0%, within the spread of one run).
4. **Displays differ more than setups do.** On one Mac the built-in display takes about 1000 ms per step
   and an external one about 550 ms; adding a third monitor moved the built-in display by about 2%.
5. Caveat: the two- and three-display setups used different external monitors (DP against the two LG
   monitors), so the 2% also includes the change of monitors.

## Choosing the delay

`dnm` uses one delay everywhere. It must exceed the slowest step of the slowest supported setup, with
a margin:

```
confirmTimeout = baseline max × index (max) of the slowest setup × margin
```

The slowest setup and the margin are open until the Intel runs are in. For example, if the Intel Mac
measures 136% (max), then 1023 ms × 1.36 × 1.5 ≈ 2.1 s. The extra wait costs time only once per command
(the final press at the edge, which never moves); a step that does move returns as soon as it is
confirmed.

## Recalibrating for a new macOS release

The assumption is that a macOS update scales every setup by about the same factor, so the relative indexes
stay valid:

1. Run `Tests/live/live-timing.sh` on the baseline setup (M5 Pro, three displays) only.
2. Compute `k = new baseline max ÷ 1023 ms`.
3. Predict the slowest setup as `k × its recorded index` and recompute `confirmTimeout` with the formula
   above.
4. Check the assumption with one run on the slowest setup (the Intel Mac). If its index moved by more than
   about 5 points, re-measure every setup and start a new baseline row.

Record each recalibration as new rows here, with the macOS version and build; never overwrite old rows.

## Raw data

The tool's logs and CSV files are kept locally in `working-notes/timing/` (untracked). The kit writes them
to its `results/` folder.
