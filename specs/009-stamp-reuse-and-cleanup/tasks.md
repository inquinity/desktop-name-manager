---
description: "Task list for feature F4: reuse of labeled images and dnm cleanup"
---

# Tasks: Feature F4 — Reuse and `dnm cleanup`

**Input**: `specs/009-stamp-reuse-and-cleanup/` (spec.md, plan.md, research.md, data-model.md, contracts/cli.md, quickstart.md)

**Tests**: included. Stage 1 first (T001 to T019), then stage 2 (T020 to T026).

## Stage 1

- [ ] T001 `Stamp.reuseKey`, `Stamp.lastSeen`, `Manifest.maintenance`; schema 3 (read 1 to 3, write 3); decode tests including a 0.2.0 manifest
- [ ] T002 `LabelRenderer.rendererVersion`; `ReuseKey` (data-model §2) and tests: each part changes the key, automatic stays automatic, the same request gives the same key
- [ ] T003 `set` reuses an existing label of the same key (active or retired, file present), reactivating it, without rendering; new labels record the key and `lastSeen = createdAt`; tests: reuse, revival, undo after a reused set, missing file, relabel identical on the same Desktop, different text/option/original/display/size/version
- [ ] T004 Last seen: commands that write record the images on all displays' current Desktops; test that `list`, `show`, `displays`, `check`, `about` leave the manifest byte-identical
- [ ] T005 Rename the automatic tidying to housekeeping (code: `Cleanup` enum, `cleanUp()`; documents: specs 001 and 005, README, contracts)
- [ ] T006 `Cleanup.swift`: candidates (data-model §4), describe, delete as one locked change (image and record, nudge state); tests: retired vs not seen, `--days`, current-Desktop exclusion, undo-window exclusion, missing file, unreadable store
- [ ] T007 `CleanupCommand`: `--days`, `--yes`, `--json`; the description with the plain warning; the question on a terminal; no terminal without `--yes` describes and exits 0; exit codes (contract §2)
- [ ] T008 Remove `Prune.swift`, `PruneCommand`, the prune report; `dnm prune` reports the rename and exits 2; update completion (spec 007) and its tests
- [ ] T009 [P] Contract tests for `cleanup` against the binary (scratch store; no wallpaper changed): description, `--json`, no-terminal behavior, invalid `--days`, `prune` message
- [ ] T010 Housekeeping estimate (sum of candidate sizes at the default days) and the nudge decision; the throttle (shown, within 7 days, doubled, reset by cleanup); performance test: 1,000 labels under 50 ms
- [ ] T011 `Nudge.swift` in `dnm`: after `set` and `remove` only (not `undo`), standard error a terminal, never for other commands or `--json`; table-driven test (terminal or not, size, last shown, doubling, command)
- [ ] T012 `check` stored-labels row says what cleanup could free (contract §6); update its tests
- [ ] T013 [P] README (cleanup, the plain warning, reuse, the nudge, what the scan adds), release notes (bullets only: `prune` removed, `cleanup`, reuse, nudge)
- [ ] T014 [P] Amend spec 001 (FR-013, FR-018, FR-029, SC-006: `cleanup` replaces `prune`; housekeeping), spec 005 wording, spec 007 contract
- [ ] T015 `just test` and `just periphery` pass
- [ ] T016 Quickstart 1 to 7; live check of reuse on a real Desktop (`Index.plist` backup and restore)

## Stage 2

- [ ] T020 `DesktopNavigator`: visit every Desktop of a display (left to Desktop 1, right to the last), returning to the start; unit tests with the fake switcher (several Desktops, one Desktop, shortcuts off, a step that does not confirm)
- [ ] T021 Settle-until-stable read of the display's wallpaper at each Desktop (two reads about 100 ms apart, bounded by the confirmation timeout); tests with the fake system's delayed reports
- [ ] T022 `Scan.swift`: the images seen on all Desktops of each connected display; labels of those displays that were not seen; labels of absent displays named and left alone; updates `lastSeen` for everything seen
- [ ] T023 `cleanup --scan`: Accessibility check first with no output before it; describe; ask; walk; report; ask; delete; `--days` rejected; `--yes`; `--json`
- [ ] T024 Nudge text for stage 2 (mentions `--scan`)
- [ ] T025 Live script `Tests/live/live-scan.sh` (`Index.plist` backup and restore, live-control announcements): create Desktops, label them, delete one, scan, compare; run in each display configuration (SC-006)
- [ ] T026 Docs and release notes for the scan; check "Displays have separate Spaces" off behavior
