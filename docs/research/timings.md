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
| M5 Pro, 27.0.1, 3 displays, repeat run | 2026-10-06 | Built-in | 1003 ms | 1027 ms | 99.7% | 100.4% | 0 / 0 |
| M5 Pro, 27.0.1, 4 displays | 2026-10-07 | Built-in | 1003 ms | 1021 ms | 99.7% | 99.8% | 0 / 0 |
| M5 Pro, 27.0.1, 2 displays | 2026-10-06 | Built-in | 986 ms | 1000 ms | 98.0% | 97.8% | 0 / 0 |
| M5 Pro, 27.0.1, 2 displays, Reduce Motion on (once, for information) | 2026-10-06 | Built-in | 978 ms | 998 ms | 97.2% | 97.6% | 0 / 0 |
| Intel i9-9980HK (MacBook Pro 16", 2019), 26.7.1 (25G241), 3 displays | 2026-10-06 | Built-in | 560 ms | 586 ms | 55.7% | 57.3% | 0 / 0 |
| Intel i9-9980HK, 26.7.1, 2 displays | pending | | | | | | |

Other displays measured (not the slowest in their setup):

| Setup | Display | Median | Max | Index (median) |
|---|---|---|---|---|
| M5 Pro, 27.0.1, 2 displays | DP (external) | 552 ms | 578 ms | 54.9% |
| M5 Pro, 27.0.1, 2 displays, Reduce Motion on | DP (external) | 554 ms | 582 ms | 55.1% |
| M5 Pro, 27.0.1, 3 displays | LG ULTRAFINE | 553 ms | 578 ms | 55.0% |
| M5 Pro, 27.0.1, 3 displays | LG Ultra HD | 559 ms | 577 ms | 55.6% |
| M5 Pro, 27.0.1, 4 displays | DP | 560 ms | 591 ms | 55.7% |
| M5 Pro, 27.0.1, 4 displays | LG ULTRAFINE | 557 ms | 582 ms | 55.4% |
| M5 Pro, 27.0.1, 4 displays | LG Ultra HD | 558 ms | 588 ms | 55.5% |
| Intel, 26.7.1, 3 displays | LG ULTRAFINE | 552 ms | 577 ms | 54.9% |
| Intel, 26.7.1, 3 displays | LG Ultra HD | 556 ms | 577 ms | 55.3% |

The repeat run of the baseline setup moved by less than half a point (99.7% median, 100.4% max): that is
the run-to-run noise to allow for when comparing runs.

Gap and edge tests, every setup so far: no lost or doubled steps at any gap, including 0 ms; no late
notifications at the edge.

## What the numbers say so far

1. **`confirmTimeout` (1.0 s) is too short.** The baseline's slowest steps took 1023 ms, so on that setup
   a real step can be counted as "nothing moved". This is a functional bug, not a test artifact.
2. **`settleTime` (0.25 s) shows no benefit.** Pressing again immediately after a confirmation lost no
   steps on any display.
3. **Reduce Motion has no measurable effect** (97.2% against 98.0%, within the spread of one run).
4. **The number of displays does not matter** (two, three and four displays within 2.2 points of each
   other). **Displays differ more than setups do.** On one Mac the built-in display takes about 1000 ms per step
   and an external one about 550 ms; adding a third monitor moved the built-in display by about 2%.
5. Caveat: the two- and three-display setups used different external monitors (DP against the two LG
   monitors), so the 2% also includes the change of monitors.
6. **The margin today is about 13 ms.** `dnm` starts its 1.0 s wait after the key press (about 40 ms), so
   it effectively allows about 1.04 s; the slowest step seen took 1027 ms.
7. **The CPU is not what is slow.** The Intel Mac (macOS 26.7.1) confirms in about 560 ms on every display,
   like every external monitor on the M5. Only the M5's built-in display on macOS 27 takes about 1000 ms.
   Whether that is the display or macOS 27 is open: an Apple silicon Mac on macOS 26 would tell.

## End-to-end time of a `--desktop` command

`live-timing.sh` times `dnm show --desktop` (read-only) for each start Desktop and target, with three
Desktops per display. The Intel run (26.7.1, three displays, 3 runs each) fits, within 1%:

```
time ≈ 1.38 s + 0.83 s × steps
```

- **1.38 s fixed:** the press at the edge, which never moves and waits the whole 1.0 s `confirmTimeout`,
  plus about 0.38 s to start, point at the display and read.
- **0.83 s per step:** about 0.56 s confirmation, 0.25 s `settleTime`, 0.02 s for the key press.
- **Steps** for start `s` and target `t`: `(s − 1)` to walk left, `2` more when `s = 1` (the shortcut probe),
  `(t − 1)` to walk right, `|t − s|` to return.

| Steps | Example (start → target) | Median |
|---|---|---|
| 2 | 1 → 1, 2 → 2, 2 → 1 | 3.03 s |
| 4 | 1 → 2, 2 → 3, 3 → any | 4.69 s |
| 6 | 1 → 3 | 6.33 s |

The M5 (27.0.1, three displays) gives the same for its LG monitors (3.00, 4.67 and 6.35 s), and for its
built-in display `time ≈ 1.29 s + 1.28 s × steps`:

| Steps | M5 built-in display | M5 LG monitors | Intel, every display |
|---|---|---|---|
| 2 | 3.86 s | 3.00 s | 3.03 s |
| 4 | 6.42 s | 4.67 s | 4.69 s |
| 6 | **8.98 s** | 6.35 s | 6.33 s |

With three Desktops, `--desktop 3` from Desktop 1 on the M5's built-in display already exceeds SC-008's 8 s.

Four displays (M5, 27.0.1) change nothing: the built-in display took 3.86, 6.41 and 8.97 s for 2, 4 and 6
steps, and DP and the two LG monitors 2.98 to 3.03, 4.63 to 4.69 and 6.29 to 6.32 s. The number of
displays does not measurably affect switching time; the display itself does.

Consequences:

- `settleTime` is 30% of each step and has never been needed (no lost steps at a 0 ms gap).
- The probe adds 2 steps whenever the display starts on Desktop 1, though for a target of 2 or more the
  first step toward it already proves the shortcuts work.
- The worst case grows with the number of Desktops `D`: `2 × (D − 1)` steps. With the M5's built-in display
  (about 1.25 s per step today), five Desktops take about 11 s. A fixed 8 s in SC-008 cannot hold for
  every Desktop count; it should be stated per step or for a given number of Desktops.

## Decisions (2026-10-07)

From the runs above (the M5 with two, three and four displays, and the Intel Mac):

| Setting | Was | Now | Reason |
|---|---|---|---|
| `confirmTimeout` | 1.0 s | **1.5 s** | Worst step seen 1027 ms; 1.46 × that. |
| `settleTime` | 0.25 s | **removed** | No step lost or doubled at a 0 ms gap, in 840+ steps per setup. |
| Probe from Desktop 1 | always | **only for `--desktop 1`** | For a later target, the first step toward it proves the shortcuts work. |
| SC-008 | each command under 8 s | **2.5 s + 1.25 s per step** | Steps grow with the number of Desktops. 2.5 s covers the 1.5 s edge wait and about 0.4 s of start-up; 1.25 s is about 20% over the slowest step (1027 ms). |

Predicted with these settings (to be confirmed by a new run): the M5's built-in display, Desktop 1 to
Desktop 3, from 8.98 s to about 5.9 s; the Intel Mac, from 6.33 s to about 4.2 s. When the slowest step
or the fixed cost changes (a new macOS release), recompute `confirmTimeout` and the SC-008 limits with
the procedure below.

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
