# Implementation Plan: Desktop Labels and the `dnm` Command-Line Tool

**Branch**: n/a (spec directory `001-labels-and-cli`; work happens on main) | **Date**: 2026-09-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-labels-and-cli/spec.md`

## Summary

Stamp a one-line label into a copy of the current Desktop's wallpaper and set that copy as
the wallpaper, using only public macOS APIs and no permissions. The work is a Swift package
with two parts: a core library (`DesktopNameCore`: wallpaper access, rendering, storage,
cleanup) that the later app reuses, and the `dnm` command-line tool on top of it. The
approach is proven by the prototype in `prototype/` (261 ms per label on a 5K display, all 23
test wallpapers legible); this plan restructures it into testable modules and adds what the
spec requires beyond the prototype: exact restore, one-level undo, cool-down cleanup,
display selection, JSON output, and a rule for unsupported wallpapers.

Design decisions and their reasoning are in [research.md](research.md).

## Technical Context

**Language/Version**: Swift 6.4 (Xcode 27 toolchain), Swift 6 language mode

**Primary Dependencies**: Apple system frameworks only in the core (AppKit, CoreGraphics,
ImageIO, CoreImage, UniformTypeIdentifiers). One third-party package for
the CLI only: `swift-argument-parser` (Apple), pinned to an exact version. Justified in
research R2.

**Storage**: Files under `~/Library/Application Support/<store name>/`: stamps (labeled
wallpaper images named `<uuid>.dnm.<ext>`) and a versioned JSON manifest. See [data-model.md](data-model.md).

**Testing**: Swift Testing for unit and contract tests, with a fake wallpaper system and a
temporary store directory. Render snapshot tests over the local `wallpaper-samples/` set
(skipped when absent, never committed). Live checks as shell scripts run by hand, with the
`Index.plist` backup. See [quickstart.md](quickstart.md).

**Target Platform**: macOS 26.0 and later. Reasoning in research R3.

**Project Type**: library plus command-line tool (SwiftPM package)

**Performance Goals**: a label visible in under 1 s for a 5K wallpaper (spec FR-019). The
prototype measured 0.26 s.

**Constraints**: no network, no telemetry, no permissions requested, no private APIs, no
background process, original wallpaper files never modified, every change reversible.

**Scale/Scope**: one user; tens of labels; stamps of about 0.8 to 3.5 MB each.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design: still passes.*

| Principle | Status | How the plan meets it |
|---|---|---|
| I. Public APIs first | Pass | Wallpaper read/write through `NSWorkspace`; displays through `NSScreen` and CoreGraphics. No private interface is used in this feature. A future optional read-only Space-list module is out of scope. |
| II. Never require SIP changes | Pass | Nothing here touches system processes or protected settings. |
| III. Least permission | Pass | The tool requests none. If macOS denies a file read, it shows the error and stops (FR-015). Note that macOS itself may show a prompt for reads in protected folders; the tool never asks or works around it. |
| IV. Local-only | Pass | No networking framework is imported. A test checks the sources and the linked libraries (research R10). The CLI dependency is used at build time only and makes no requests at run time. |
| V. Reversible changes | Pass | The original record (path, bookmark, placement, fill color) is saved before the first change; originals are never written; stamps are separate files; undo and cool-down retain prior states. |
| VI. Distributable via Homebrew | Pass | A plain SwiftPM executable that can be signed and notarized. Packaging is spec 005. |
| VII. Tested | Pass | Unit tests with a fake system, local snapshot tests, and documented live checks. Releases are gated by code and security review (constitution). |
| VIII. Public-repo hygiene | Pass | Tests use generated fixtures; samples stay in the untracked `wallpaper-samples/`; no identifiers in tracked files. |

New dependency (`swift-argument-parser`): justified under "Platform & Distribution
Constraints"; it satisfies principles I to VI (research R2).

No violations, so the Complexity Tracking table is empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-labels-and-cli/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── cli.md           # Phase 1 output: commands, options, output, exit codes
├── checklists/
│   └── requirements.md
├── review-notes.md      # code and security review records
└── tasks.md             # Phase 2 output (/speckit-tasks command, not created here)
```

### Source Code (repository root)

```text
Package.swift                         # swift-tools-version 6.2 or later, platforms: macOS 26
.github/                             # CI workflow and Dependabot config (read-only, no secrets)
scripts/                             # developer scripts, for example the local CodeQL run
.periphery.yml                       # unused-code scan configuration (run by scripts/periphery.sh)
Sources/
├── DesktopNameCore/                  # library, reused by the app in spec 002
│   ├── Model/                        # Label, Style, Stamp, Original, DesktopRef, errors
│   ├── System/                       # WallpaperSystem protocol + NSWorkspace/NSScreen implementation
│   ├── Displays/                     # display listing and --display resolution
│   ├── Render/                       # backdrop composition, sampler, style picker, painter
│   ├── Store/                        # manifest, stamp files, lock, cleanup
│   └── Operations/                   # set, remove, undo, list, show (pure logic over the protocols)
└── dnm/                              # executable: argument parsing, output, exit codes
Tests/
├── DesktopNameCoreTests/             # unit and contract tests with a fake WallpaperSystem
├── SnapshotTests/                    # local-only render checks over wallpaper-samples/
└── live/                             # hand-run shell scripts for real-wallpaper checks
prototype/                            # unchanged; reference only
```

**Structure Decision**: one SwiftPM package with a library and an executable, so the core
can be tested without a display and the app (spec 002) can link the same library. The
operations depend on a `WallpaperSystem` protocol; the real implementation wraps
`NSWorkspace` and `NSScreen`, tests use a fake. The `desktop-name` alias is the same binary
under a second name, installed by packaging (spec 005); the code does not depend on the name
it was invoked with.

## Spec Amendments

Design found four places where the spec's wording was stronger than public APIs allow.
All four were applied to the spec on 2026-09-30. For amendment 2 (undo), the limitation
when Desktops share an image is recorded in the spec's assumptions and left to revisit later.

1. **Cleanup "in use" (FR-018, SC-006).** Without reading the system's private wallpaper
   store, the tool cannot tell whether a non-current Desktop still shows a stamp. Plan: a
   stamp counts as in use while it is the active stamp in the manifest, and it is deleted
   only after one of our commands retired it and the 30-minute cool-down has passed. If the user
   changes a Desktop's wallpaper by hand in System Settings, its old stamp stays (a few MB)
   because the tool cannot see it. Suggested SC-006 wording: "...leaves no stamp
   except those still active or retired within the cool-down."
2. **Undo on Desktops that share an image (FR-022).** Undo reverses the last change the tool
   made on that display, and only applies when the display's current wallpaper equals what
   that change produced. If two Desktops on one display show the identical image, undo
   cannot tell them apart. It always reports what it restored. Suggested FR-022 addition:
   "Undo acts on the most recent change on the display."
3. **Which wallpapers are unsupported (FR-014).** Detection is by file: no file reported,
   catalog (`.madesktop`), video, a folder (shuffle), or an image with more than one frame.
   Solid colors need a live check (research R6).
4. **What a Desktop is (Key Entities).** Here a Desktop is recognized by the wallpaper file
   it currently shows. Stability across restarts and reordering comes from macOS keeping the
   file with the Space; the tool does not read Space identifiers.

## Complexity Tracking

No constitution violations to justify.
