---
description: "Task list for spec 015: refuse the macOS 27 default-wallpaper placeholder"
---

# Tasks: Refuse the macOS 27 default-wallpaper placeholder

**Input**: `specs/015-default-placeholder/` (spec.md, plan.md, quickstart.md)

**Tests**: included (constitution VII; SC-002, SC-003).

**Rules**: no automated test changes the real wallpaper or the real store (fake wallpaper system, temporary store);
synthetic images only; build and test with `just`.

## Phase 1: Tests first (User Stories 1 and 2)

- [x] T001 [US1] In `Tests/DesktopNameCoreTests/WallpaperKindTests.swift`, add a test that the stand-in location
  (as reported, and spelled with `.`, `..` and `//`) classifies as unsupported with the FR-002 reason.
- [x] T002 [US1] Same file: a valid still made a stand-in through the `standIns` parameter is unsupported (the check
  comes before the contents, FR-004).
- [x] T003 [US1] Same file: `setLabel` with the fake system reporting the stand-in location throws
  `unsupportedWallpaper` with exit code 3, sets no wallpaper, writes no stamp and records nothing.
- [x] T004 [US2] Same file: the same still at a location that is not a stand-in is supported (only the location
  decides); existing tests stay unchanged.

## Phase 2: Fix

- [x] T005 [US1] In `Sources/DesktopNameCore/System/WallpaperKind.swift`, add `standInLocations` and the check in
  `classify` as in plan.md (Design), with a comment naming the approved principle I deviation.

## Phase 3: Docs and gates

- [x] T006 README: add the stand-in case to the exit-code 3 line and the workaround (copy the picture elsewhere).
- [x] T007 `docs/release-notes/UNRELEASED.md`: the fix, and advice for labels made over the stand-in by 0.3.0.
- [x] T008 `just test`, `just periphery`; independent review of the change (2026-11-20: no blocking findings; the
  "never opened" test now uses a missing file, and the comparison's limits are noted in the code).
- [ ] T009 Live check (quickstart.md), with the maintainer's OK for live control; record results.
