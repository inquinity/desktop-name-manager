# Quickstart: validating labels and the `dnm` CLI

How to prove the feature works end to end. Commands and options are defined in
[contracts/cli.md](contracts/cli.md); stored data in [data-model.md](data-model.md).

## Prerequisites

- macOS 26.0 or later (the minimum; see research R3). Run the live checks on 26 and on 27, with "Displays have separate Spaces"
  on and at least three Desktops on one display.
- Xcode 27 command-line tools.
- For the legibility sweep only: the untracked `wallpaper-samples/` folder.

## Build

```bash
just release    # swift build -c release --scratch-path build.noindex
```

The binary is `build.noindex/release/dnm`. Put `desktop-name` beside it as a link to it to check
the alias.

## Automated checks (safe: do not touch the real wallpaper)

```bash
just test      # swift test --scratch-path build.noindex
```

Covers validation, display resolution, set/remove/undo/list/show logic against a fake
wallpaper system and a temporary store, cool-down cleanup with an advanced clock, the
unsupported-wallpaper rules, the JSON shapes, and the source scan for networking and
private-framework use. Snapshot tests run over `wallpaper-samples/` when it is present and
report skipped when it is not.

## Live checks (these change your real wallpaper)

Rules: run only while you are idle at the machine; back up first; restore afterwards.

```bash
# 1. Back up the wallpaper store and use a private store directory for this run.
cp ~/Library/Application\ Support/com.apple.wallpaper/Store/Index.plist \
   "$TMPDIR/Index.plist.backup"
export DNM_STORE_DIR="$TMPDIR/dnm-live-store"
mkdir -p "$DNM_STORE_DIR"
```

Then, on Desktop 2, run the scenarios below and look at the screen each time.

| # | Scenario | Command | Expected |
|---|---|---|---|
| 1 | Label the current Desktop | `dnm set "Email"` | Label appears bottom-left within about 1 s and is legible; Desktops 1 and 3 are unchanged (Story 1). |
| 2 | Style and colour reported | `dnm show` | Look and colour match what you see; `automatic` lists them (Story 1, 4). |
| 3 | Replace | `dnm set "Mail" --size large` then `dnm set "Mail"` | Second run is medium again: options reset (clarify 3). |
| 4 | Persistence (manual: needs a log out, so no script) | Reorder Desktops, use Show Desktop, log out and in | Label stays on the same Desktop (Story 1). |
| 5 | Exact restore | Note System Settings' placement for the Desktop, then `dnm remove` | Original image and placement return, byte-identical file (Story 2). |
| 6 | Undo | `dnm set "Email"`, `dnm remove`, `dnm undo` | "Email" is back; a second `dnm undo` says nothing to undo (Story 2). |
| 7 | Limits | `dnm set "$(printf 'a%.0s' {1..31})"` and a label with a line break | Both exit 2 with a message; wallpaper unchanged (Story 3). |
| 8 | Emoji | `dnm set "Mail ✉️"` | Drawn cleanly, not clipped (Story 3). |
| 9 | Displays | `dnm displays`, `dnm set "Test" --display "LG"`, `--display main` | Names listed; partial name works; label lands on the named display (FR-023, 024). |
| 10 | Ambiguity | `dnm set "Test" --display "zzz"` | Exit 2, candidates listed, no change. |
| 11 | List | `dnm list`, `dnm list --json` | Labeled and current Desktops shown; final line and `scope` field state the scope (FR-011). |
| 12 | Unsupported | Switch the Desktop to a dynamic or aerial wallpaper, `dnm set "Test"` | Exit 3, message, no change (Story 5). |
| 13 | Unreadable | Put a wallpaper inside a protected folder, deny access, `dnm set "Test"` | The system's error shown, exit 1, no change (clarify 6). |
| 14 | No network | Turn Wi-Fi off, repeat 1, 5, 11 | All succeed (Story 5). |
| 15 | Originals untouched | `shasum` the original image before and after 1 to 6 | Identical. |
| 16 | Cool-down cleanup | After scenario 6, wait 31 minutes, run `dnm list` | Retired stamp files are gone from `$DNM_STORE_DIR`; active ones remain; no other file in the folder was touched (SC-006, FR-026). |
| 17 | Solid color | Set the Desktop to a solid color in System Settings, `dnm set "Test"` | Either labeled as an image or declined with exit 3; record which (research R6). |
| 18 | Image quality | Label a wallpaper with fine detail and flat color areas, compare to the original | No visible loss away from the label; record the difference measurement (research R7). |
| 19 | Missing stamp | Delete the stamp file for a labeled Desktop, run `dnm show`, then `dnm set "Email"` | `show` says the stamp is missing; `set` rebuilds it from the original; `remove` also works (spec edge case). |

Restore when finished:

```bash
unset DNM_STORE_DIR
# If the wallpaper looks wrong, put your original store back (log out and in afterwards):
cp "$TMPDIR/Index.plist.backup" \
   ~/Library/Application\ Support/com.apple.wallpaper/Store/Index.plist
```

## Timing check (SC-001)

```bash
time build.noindex/release/dnm set "Timing"
```

Expected: under 1 s on a 5K display.

## Legibility sweep (SC-002)

Run the snapshot suite with `wallpaper-samples/` present. Every rendering must meet the
contrast threshold, and you look at every rendering once. The images stay out of git.

## Exit criteria for this feature

- `swift test` passes.
- Live scenarios 1 to 19 pass on macOS 26 and macOS 27 (scenario 4 by hand).
- Code review and security review of the changes are recorded before any release
  (constitution, Development Workflow).
