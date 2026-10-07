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

## Decisions and what was done (2026-10-07)

The maintainer chose the sibling project's (Belvedere's) approach, checked against common practice:
command-line tools installed here (jq, just, shellcheck, uv, Periphery) ship their license files beside the
binary and print none; `gh licenses` prints a short list of name, version, license and a pinned link, not
the full texts. Periphery, a Swift tool that also compiles in swift-argument-parser, ships no notice for it.

1. **Constitution 2.1.0** (`d6e9fe2`): every component in the source or a distributed binary is listed in
   `Acknowledgements.md` at the version that ships, with its license text in `Licenses/`; every binary
   download includes the license files of the components it contains; the tool names them briefly;
   releases add a license check.
2. **`Licenses/`** holds swift-argument-parser's and Spec Kit's license texts, copied from the exact
   versions used (closes L1).
3. **`scripts/make-acknowledgements.sh`** (Belvedere's process) writes `Acknowledgements.md` and, with
   `--check` (run by `AcknowledgementsTests` and the release `check` stage), refuses an unlisted license
   file, a missing or non-https link, a link pinned to another version than ships (read from the committed
   `Package.resolved`), or `dnm about` not naming a binary component at that version (closes L4).
4. **`dnm about`** ends with the acknowledgements in `gh licenses`' short form and "Full license texts are
   in Licenses/." No full texts are printed, and `about` has no JSON form (closes L3).
5. **The release zip and the test kit** hold `dnm`, `LICENSE`, `Acknowledgements.md` and the binary's
   license files, listed by `make-acknowledgements.sh --binary-license-files` (closes L2). Someone who
   separates the binary from them is not our responsibility (maintainer decision).
6. Spec 001 FR-030 and its contract, spec 005 (R1, data model, contract, quickstart), the release notes
   template, the README's License section and the review modes are updated (closes L5).

Verified 2026-10-07: the pinned tags exist (`v1.0.12` in github/spec-kit, checked by the maintainer with `gh api`; `1.8.2` in apple/swift-argument-parser, the version in `Package.resolved`).
