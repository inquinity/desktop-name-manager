# Implementation Plan: Refuse the macOS 27 default-wallpaper placeholder

**Branch**: `claude/distracted-swartz-dea6fb` (worktree; merged to `main` separately from `014-menu-bar-app`) |
**Date**: 2026-11-20 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/015-default-placeholder/spec.md` (approved by the maintainer 2026-11-20)

## Summary

`WallpaperKind.classify` gains one check, first among the file checks: if the reported location, normalized with
`standardizedFileURL` (which removes `.`, `..` and repeated `/` but follows no link), equals a known stand-in
location, the wallpaper is unsupported with the reason from FR-002. The only known stand-in is
`/System/Library/CoreServices/DefaultDesktop.heic`. The list is a parameter of `classify` with that value as its
default, so tests can make a temporary file a stand-in (FR-004, FR-007). `SetLabel` maps the result to
`DnmError.unsupportedWallpaper` as today, so `dnm` exits with code 3 and the app shows the same reason (FR-006).

## Technical Context

**Language/Version**: Swift 6.4 (language mode 6), as the package.

**Primary Dependencies**: Foundation only for the new check. No new dependency.

**Storage**: none changed (store format 3 unchanged).

**Testing**: Swift Testing, `Tests/DesktopNameCoreTests/WallpaperKindTests.swift` with the fake wallpaper system and a
temporary store (`LabelerHarness`). The real stand-in location can be reported by the fake system safely: the check
compares the location only, so nothing at that path is opened.

**Target Platform**: macOS 26 or later, as the package. The check is harmless on releases that never report the
stand-in (it never matches).

**Minimum macOS**: unchanged (no new API).

**Project Type**: core library change shared by `dnm` and the app.

**Constraints**: principle I deviation recorded below; no new permission, read, network use or telemetry.

## Constitution Check

| Principle | Status |
|---|---|
| I. Public APIs Only | **Deviation, approved (spec Q1).** The product names one undocumented system location and compares the location the public reader reports with it. It does not open, list, follow or read anything there or in the wallpaper store. See Complexity Tracking. |
| II. Never Require SIP Changes | Pass: nothing touches system files. |
| III. Least Permission | Pass: no permission; the check reads nothing new. |
| IV. Local-Only | Pass: no network, no telemetry. |
| V. Reversible Changes | Pass, and improved: the tool stops making a change it cannot undo (replacing a dynamic wallpaper with a still). |
| VI. Distributable via Homebrew | Pass: no change to signing or packaging. |
| VII. Tested | Pass: contract tests with the fake system (tasks T002-T004); live check in [quickstart.md](quickstart.md). |
| VIII. Public-Repo Hygiene | Pass: the location is a system path present on every Mac, not personal; tests use synthetic images. |

## Design

- `WallpaperKind.standInLocations: [URL]`: `[/System/Library/CoreServices/DefaultDesktop.heic]`, with a comment naming
  the deviation and spec 015.
- `classify(_ current: CurrentWallpaper, standIns: [URL] = standInLocations)`: after the "no file reported" check and
  before the catalog, folder, video and image checks, return
  `.unsupported(reason: "macOS reports the default wallpaper when dynamic or unsupported wallpapers are selected")`
  when `url.standardizedFileURL.path` equals any stand-in's `standardizedFileURL.path`.
- No other file changes in core. `SetLabel` already maps `.unsupported` to exit code 3.
- Docs: README's exit-code line and unsupported list; `docs/release-notes/UNRELEASED.md` (fix bullet plus advice for
  labels made over the stand-in by 0.3.0).

## Complexity Tracking

| Deviation | Why needed | Simpler alternative rejected because |
|---|---|---|
| Principle I: the product knows the undocumented location `/System/Library/CoreServices/DefaultDesktop.heic` (compared, never read). Approved by the maintainer 2026-11-20 (spec Q1). Revisit on each macOS release (quickstart step 2 checks it still matches). | On macOS 27 the public reader reports this stand-in for Apple dynamic wallpapers, and the file behind it is an ordinary still: nothing in the file tells them apart. | Classifying by contents cannot tell the stand-in from a still. Following the link into the hidden default-wallpaper folder would read more undocumented structure. Doing nothing leaves the tool replacing dynamic wallpapers it cannot restore. |

## Rollback

Revert the feature's commit: one check and its tests. The store and labels are untouched.
