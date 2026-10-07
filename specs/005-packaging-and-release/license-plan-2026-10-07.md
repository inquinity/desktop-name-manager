# License compliance review and plan, 2026-10-07 (before 0.1.0)

A review of every third-party component in the source repository and in the binary distribution, what each
license requires, where we stand, and a plan to close the gaps. This is an engineering review, not legal
advice.

## Inventory

| Component | Where | License | Distributed by us? |
|---|---|---|---|
| Desktop Name Manager (our code) | everything not listed below | MIT, Copyright (c) 2026 Robert Altman (`LICENSE`) | source and binary |
| swift-argument-parser 1.8.2 (revision `6a52f32`) | compiled into the `dnm` binary | Apache License 2.0 with Runtime Library Exception; "Copyright (c) 2020 Apple Inc. and the Swift project authors"; no NOTICE file; no dependencies of its own | **binary** (not its source: SwiftPM fetches it) |
| GitHub Spec Kit 1.0.12 (generated files) | `.specify/` (templates, scripts, workflows) and `.claude/skills/speckit-*` | MIT, "Copyright GitHub, Inc." | **source** (committed to this public repository) |
| macOS frameworks (AppKit, Foundation, CoreGraphics, ImageIO and others) and the Swift runtime in `/usr/lib/swift` | linked by `dnm` | Apple's macOS license | no: part of macOS, not shipped |
| The system font (`NSFont.systemFont`) | used to draw labels | part of macOS | no: drawn through the system on the user's Mac; no font file is shipped |
| Swift Testing, XCTest | tests only | Apple toolchain | no |
| Development tools: `just`, Periphery, CodeQL, shellcheck, Homebrew, `gh` | run on the maintainer's Mac | various | no |
| Research tools (`prototype/`, `switch-timing`) | our code; `switch-timing` ships only in the test kit | MIT (ours) | test kit only |

Checked: no code in `Sources/`, `Tests/`, `scripts/` or `prototype/` is copied or adapted from elsewhere
(the two "ported from the prototype" notes refer to our own prototype), and no third-party image, font or
data file is tracked. `wallpaper-samples/` is local only and never tracked.

## What each license requires of us

- **Our MIT license:** keep the copyright and permission notice with every copy. The release zip already
  includes `LICENSE`, and `dnm about` names the license and the source.
- **swift-argument-parser (Apache 2.0):** for a binary, section 4 asks to give recipients a copy of the
  license (4a) and to pass on a NOTICE file if there is one (4d; there is none). Its Runtime Library
  Exception waives 4(a), 4(b) and 4(d) for code embedded in a binary "as a result" of compiling with it.
  Whether a library linked into a program counts is open to reading; **we include the license and the
  copyright line anyway**, which satisfies section 4 either way and costs nothing.
- **Spec Kit (MIT):** the copyright and permission notice must be included "in all copies or substantial
  portions". Our repository holds copies of its templates, scripts and skills **without that notice: this
  is the one actual gap.**
- **Compatibility:** MIT and Apache 2.0 are both permissive and compatible with distributing our MIT code
  together with them. Nothing here is copyleft.

## Gaps

| ID | Gap | Severity |
|---|---|---|
| L1 | Spec Kit's MIT notice is missing from the repository | must fix (license condition) |
| L2 | The binary distribution carries no acknowledgement or license text for swift-argument-parser | should fix (required unless the exception applies; we choose to comply regardless) |
| L3 | The CLI shows our license name but no third-party acknowledgements or full license texts | requested by the maintainer |
| L4 | Nothing stops a new dependency from shipping without its notice | process gap |
| L5 | The constitution says nothing about licenses beyond "Licensed MIT" and justifying new dependencies | process gap (requested) |

## Plan

1. **`THIRD-PARTY-NOTICES.md` at the repository root** (L1, L2): one section per component that is
   distributed, with its name, version, where it is used, its copyright line and the full license text:
   swift-argument-parser (Apache 2.0 with Runtime Library Exception) and Spec Kit (MIT, covering `.specify/`
   and `.claude/skills/speckit-*`). A short closing note lists what is not distributed (macOS frameworks,
   the Swift runtime, the system font, test and development tools).
2. **`dnm about` shows acknowledgements; `dnm about --licenses` prints the full texts** (L3):
   - `dnm about` gains an "Acknowledgements" line: "swift-argument-parser 1.8.2 (Apache License 2.0 with
     Runtime Library Exception). Full license texts: `dnm about --licenses`."
   - `dnm about --licenses` prints our MIT license and every third-party notice compiled into the binary
     (so a copied binary carries them, with no extra file), and `dnm about --json` includes an
     `acknowledgements` list.
   - `dnm --help` mentions `about` (it already lists the subcommand; its abstract will say "version,
     licenses and permissions").
   - The texts live in one generated Swift source (`Sources/DesktopNameCore/Licenses.swift`), produced by a
     small script from `LICENSE` and the checked-out dependency's `LICENSE.txt`.
3. **Release artifact** (L2): the zip holds `dnm`, `LICENSE` and `THIRD-PARTY-NOTICES.md`; the release
   procedure's contents check and spec 005 (R1, the data model, the contract) change to match; the test
   kit gets the same two files. The release notes name the acknowledgements.
4. **Automated checks** (L4):
   - a test that every package in `Package.resolved` has a section in `THIRD-PARTY-NOTICES.md`, with its
     resolved version;
   - a test that the license texts compiled into the binary equal `LICENSE` and the dependency's
     `LICENSE.txt` in the build checkout (skipped, with a message, when the checkout is absent);
   - the release `check` stage runs both as part of `just test`, and fails if `THIRD-PARTY-NOTICES.md`
     is missing.
5. **Constitution amendment, v2.1.0 (MINOR: a materially expanded constraint)** (L5), in "Platform &
   Distribution Constraints", replacing "Licensed MIT. New dependencies MUST be justified in the plan and
   MUST satisfy principles I-VI." with:

   > Licensed MIT. Every third-party component in the source repository or in a distributed binary MUST be
   > listed in `THIRD-PARTY-NOTICES.md` with its version, its copyright notice and its full license text,
   > and its license MUST be compatible with distributing this project under MIT (no copyleft in what is
   > distributed). Binary distributions MUST carry those notices, both as a file in the download and from
   > the tool itself (`dnm about --licenses`; the app's About window later). A new dependency MUST be
   > justified in the plan, MUST satisfy principles I-VI, and MUST have its license reviewed and its notice
   > added before it is merged. Every release MUST pass a license check alongside the code and security
   > reviews.

   With a Sync Impact Report (affected: spec 001 FR-030 for `about`, spec 005 R1 and FR-007 for the
   artifact and notes, the release `check` stage, and the review modes in
   `specs/001-labels-and-cli/review-notes.md`).
6. **Spec updates:** spec 001 FR-030 (`about` names acknowledgements, `--licenses` prints the texts) and
   its CLI contract; spec 005's artifact contents, release notes and gate record (a "License check" gate).

## Order of work

1. The constitution amendment (needs the maintainer's approval of the wording first).
2. `THIRD-PARTY-NOTICES.md`; the license-text generator and `Licenses.swift`; `dnm about` and
   `--licenses` with tests; the inventory test.
3. Spec 001 and spec 005 updates; the release script, kit and release notes.
4. Then back to the 0.1.0 release steps (the confirmation runs, push, tag, release).
