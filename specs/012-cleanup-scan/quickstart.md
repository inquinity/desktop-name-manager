# Quickstart: `dnm cleanup --scan` (Feature F9)

Validation for [spec.md](spec.md) against [contracts/cli.md](contracts/cli.md).

## Automated

```bash
just build
just test
just periphery
```

Expected: all pass, including the walk tests in `DesktopNavigatorTests`, `ScanTests`, the scan cases in
`CleanupTests` and the refusals in `CleanupCommandTests`. No test switches a real Desktop.

## By hand, no switching

Use a throwaway store: `export DNM_STORE_DIR="$(mktemp -d)"`.

| # | Command | Expected |
|---|---|---|
| 1 | `dnm cleanup --scan --days 7` | exit 2, `--scan looks at every Desktop, so --days does not apply.` |
| 2 | `dnm cleanup --scan DP1` | exit 2, the parser's usage error |
| 3 | `dnm cleanup --scan </dev/null \| cat` | the description, `Nothing was scanned: add --yes ...`, exit 0, no switching |
| 4 | `dnm cleanup --scan --json` | one JSON document with `wouldScan`, nothing switched, exit 0 |
| 5 | `dnm cleanup --help` | lists `--scan` with the contract's text |
| 6 | Accessibility removed for the terminal app, `dnm cleanup --scan` | the `--desktop` explanation first, exit 1 |

## Live (switches Desktops; changes wallpapers)

Ask for live control and announce it first (`say "Requesting lyve control"`), and announce when done. Follow the
live-test rules in `CLAUDE.md`: back up `Index.plist`, use a throwaway `DNM_STORE_DIR`, remove labels with
`dnm remove` afterwards, and restore `Index.plist` only if that leaves something wrong. (Constitution VII says to
restore it afterwards; `CLAUDE.md`'s narrower rule is the project's practice since spec 001. Accepted 2026-11-09;
reconciling the two is a separate constitution change.)

1. **One display**: `Tests/live/live-scan.sh` labels three Desktops (creating them if needed), asks the person to
   delete the middle one in Mission Control, runs `dnm cleanup --scan --yes`, and checks that exactly that label was
   deleted, the others remain, and the display is back on the Desktop it started on (SC-001).
2. **Two displays**: the same with a label on each display, deleting one Desktop on the second display (SC-001); the
   time from the first `Scanning` line to the report is under 20 s for 3 Desktops on each (SC-004).
3. **Display not connected**: with a label stored for a display that is unplugged, the report names it under
   `Not checked` and does not list its labels.
4. **Ctrl-C**: start a scan on a display with five or more Desktops, press Ctrl-C mid-walk: the display returns,
   `Stopped. Scanned: ...`, exit 130, nothing deleted.
5. **"Displays have separate Spaces" off** (optional; needs a log-out): the description says the displays switch
   together; one walk; the result is correct on both displays.

Record the results, with `dnm --version`, in `tasks.md`.
