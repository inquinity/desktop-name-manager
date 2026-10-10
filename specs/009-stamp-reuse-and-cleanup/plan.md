# Implementation Plan: Feature F4 — Reuse of Labeled Images and `dnm cleanup`

**Branch**: n/a (spec directory `009-stamp-reuse-and-cleanup`; work happens on main) | **Date**: 2026-10-10 | **Spec**: [spec.md](spec.md)

## Summary

Add a reuse key and a last-seen date to each label, reuse identical images in `set`, replace `prune` by
`cleanup` (age and not-seen, described and confirmed), nudge when 50 MB could be freed, and, in stage 2, add
`cleanup --scan` by walking Desktops. Nothing deletes by itself.

## Technical Context

Swift 6.4; `swift-argument-parser` 1.8.2; Swift Testing. Public APIs only; no permissions except the opt-in
Accessibility already used by `--desktop`; no network. Manifest schema 3.

## Constitution Check

All principles pass. I (public APIs): the scan uses what `--desktop` uses. III (least permission): Accessibility
only for `--scan`, opt-in, never prompted for by us. V (reversible): no original is ever touched; a deleted
image is rebuilt by labeling again. VII (tested): unit, contract and timing tests, a live scan test. VIII
(public-repo hygiene): tests use synthetic names.

## Source changes

```text
Sources/DesktopNameCore/Model/Stamp.swift                  # Stamp.reuseKey, Stamp.lastSeen; Manifest.maintenance; schema 3
Sources/DesktopNameCore/Render/LabelRenderer.swift         # rendererVersion
Sources/DesktopNameCore/Operations/ReuseKey.swift          # New: the key (data-model §2)
Sources/DesktopNameCore/Operations/SetLabel.swift          # reuse before rendering; record lastSeen
Sources/DesktopNameCore/Operations/Cleanup.swift           # New: candidates (data-model §4), describe, delete   [renamed from the old Cleanup]
Sources/DesktopNameCore/Operations/Housekeeping.swift      # The old Cleanup enum, renamed; adds the estimate and the nudge decision
Sources/DesktopNameCore/Operations/Prune.swift             # Removed (folded into Cleanup.swift)
Sources/DesktopNameCore/Operations/Check.swift             # stored-labels row says what cleanup could free
Sources/DesktopNameCore/Switching/DesktopNavigator.swift   # stage 2: visit every Desktop of a display
Sources/DesktopNameCore/Operations/Scan.swift              # New (stage 2)
Sources/dnm/Commands/CleanupCommand.swift                  # New; PruneCommand.swift replaced by a command that only reports the rename
Sources/dnm/Nudge.swift                                    # New: prints the nudge after set/remove/undo
Tests/…                                                    # see tasks
README.md, docs/release-notes/UNRELEASED.md, specs/001 (FR-013, FR-018, FR-029, SC-006), specs/005, specs/007 (contract: cleanup)
```

## Phases

1. **Model and key**: fields, schema 3, `rendererVersion`, `ReuseKey` with tests (every part of the key changes it;
   automatic stays automatic; the same request gives the same key).
2. **Reuse in `set`**: look up by key (active or retired, file present), revive, skip rendering; tests with the fake
   wallpaper system, including undo after a reused set and a missing file.
3. **Last seen**: write path in the commands that write; tests that read-only commands write nothing.
4. **Cleanup**: candidates, describe, confirm/`--yes`/no terminal, JSON, `--days`; replaces `prune` (command,
   report, tests, docs, completion); `prune` reports the rename.
5. **Housekeeping rename and the nudge**: rename in code and documents; the estimate (performance test, 1,000
   labels under 50 ms); the throttle (table-driven test); `check` row.
6. **Stage 2, the scan**: navigator support to visit every Desktop; settle-until-stable reads; Accessibility check
   before any output; describe, ask, walk, report, ask, delete; unit tests with the fake switcher; a live script
   on this Mac in each display configuration (`Index.plist` backup, live-control announcements).
7. **Docs and verification**: README, release notes (removal of `prune`, new `cleanup`, reuse, nudge), completion,
   `just test`, `just periphery`; stage 1 live check of reuse on a real Desktop.

## Risks

- Reuse key too loose (stale image): mitigated by size and modification time of the original and the renderer
  version; a test for each part.
- The scan reads before macOS updates (stage 2): the settle read; live test; the deletion is confirmed and recoverable
  by relabeling.
- Schema 3: older releases refuse it (accepted at 0.x).
