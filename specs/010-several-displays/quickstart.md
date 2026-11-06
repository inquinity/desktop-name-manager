# Quickstart: Several Displays in One Command (spec 010)

Validation scenarios for 0.2.2. Details of the grammar and output are in [contracts/cli.md](contracts/cli.md).

## Prerequisites

- A build from `just build-release`; quote `dnm --version` when reporting.
- For scenarios 1 to 6: two or more connected displays, each on a Desktop with a plain image wallpaper, "Show on all
  Spaces" off, and the person idle.
- Live rules (CLAUDE.md): back up `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` first, set
  `DNM_STORE_DIR` to a throwaway directory, and finish with `dnm remove` on every display.
- Scenario 7 also needs the Accessibility permission and two or more Desktops on each display; announce live control
  first.

## Automated

```bash
just test
just periphery
```

The table of command lines (SC-001), the refusals that change nothing and the failure on the second of three
displays (SC-002) run against the fake wallpaper system and never change a real wallpaper.

## Live (`Tests/live/live-syntax.sh`, SC-004)

| # | Scenario | Steps | Expected |
|---|---|---|---|
| 1 | Label every display | `dnm set main "Both" --display <other>` | Both current Desktops show "Both"; two lines, main first; exit 0 |
| 2 | Remove from every display | `dnm remove main <other>` | Both originals back; two lines; exit 0 |
| 3 | Undo on every display | `dnm set main "Again" --display <other>`, then within 60 s `dnm undo main <other>` | Both originals back; two lines |
| 4 | Undo refused for one | `dnm set <other> "Only"`; `dnm undo main <other>` (main has nothing to undo) | Exit 1, `Cannot undo: there is nothing to undo on ...`; `<other>` still shows "Only" |
| 5 | A typo changes nothing | `dnm set main "Typo" --display NoSuchDisplay` | Exit 2, the resolver's message; main unchanged |
| 6 | `show` stays one display | `dnm show main --display <other>` | Exit 2, "Multiple displays for a single command are not currently supported." |
| 7 | `--desktop` on every display | `dnm set main "Two" --display <other> --desktop 2` | Desktop 2 of each display shows "Two"; each display returns to where it was |
| 8 | One display, as before | the existing positional checks in the script | Unchanged results (FR-009) |

Finish with `dnm remove main <other>` (and `--desktop 2` after scenario 7); `dnm show` reports no label on either.
