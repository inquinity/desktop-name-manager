# Quickstart: `remove` repairs a misreported Desktop (Feature F6)

## Automated

```bash
just build
just test
just periphery
```

## Confirm first (research R1; live, under the live-test rules)

Back up `Index.plist`, use a throwaway `DNM_STORE_DIR`, and announce live control if `--desktop` is used.

1. One display with three Desktops: unlabeled, A, B. Label the left-most Desktop C.
2. Add a Desktop in Mission Control (it shows C). Switch to the left-most Desktop and run `dnm remove`.
3. Switch to the new Desktop: it still shows C; `dnm show` says no label (KI-3).
4. Snapshot with `prototype/space-observer.swift` (read-only); then set the reported URL again with a one-off
   prototype and look at the screen. Record the outcome in KI-3 and research R1.

## After the feature is built

5. Repeat steps 1-3; `dnm remove` prints the repair line and the new Desktop shows the original on screen (SC-001).
6. `dnm remove` on an unlabeled Desktop showing a wallpaper never labeled: `No label on <display>.`, nothing set.
7. Clean up with `dnm remove` on every labeled Desktop; restore `Index.plist` only if something is left wrong.

Record the results with `dnm --version` in `tasks.md`.
