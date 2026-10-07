# Implementation Plan: Packaging and Release (0.1.0, M1)

**Branch**: n/a (spec directory `005-packaging-and-release`; work happens on main) | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/005-packaging-and-release/spec.md`, as clarified on 2026-10-07

## Summary

Turn the tested `dnm` command-line tool into the first, unlisted release, 0.1.0 (roadmap milestone M1): an
Apple-silicon release build, checked for leaked paths and unexpected libraries, signed with the Developer
ID and the hardened runtime, zipped, notarized, verified the way a user's Mac checks it, published as a
GitHub release, and installed through an unlisted cask, `desktop-name-manager`, in the maintainer's tap.
One local script runs the procedure in stages; every outward step (draft, publish, cask) needs its own
explicit confirmation. Credentials come only from the environment. This plan covers User Stories 1, 2, 4
and 5; upgrade and withdrawal (3 and 6) are documented now and tested from 0.1.1.

Decisions and their reasoning are in [research.md](research.md).

## Technical Context

**Language/Version**: Bash 3.2-compatible shell script (the macOS system bash) for the procedure; Ruby only
as Homebrew's cask format. The product is unchanged Swift 6.4.

**Primary Dependencies**: Xcode command-line tools (`swift`, `codesign`, `notarytool`, `otool`, `strings`,
`ditto`, `syspolicy_check`), GitHub CLI (`gh`), Homebrew (`brew`) for the cask audit and install test.
No new dependency in the product.

**Storage**: per-release gate record `specs/005-packaging-and-release/releases/<version>.md`; build output in
`build.noindex/release-artifacts/<version>/` (ignored).

**Testing**: a dry run of the whole procedure; `shellcheck`; the cask's `brew audit` and a local-tap install,
run and uninstall; the quickstart in [quickstart.md](quickstart.md) on macOS 26 and 27 after publishing.

**Target Platform**: macOS 26 or later, Apple silicon (arm64) only for 0.1.0.

**Project Type**: release tooling for a command-line tool.

**Performance Goals**: none beyond SC-001 (install and first run in under 2 minutes). Notarization waits at
most 30 minutes.

**Constraints**: no credential, keychain profile name, personal path or identifier in tracked files, logs,
release files or the tap (FR-008, FR-019); nothing pushed or published without a separate confirmation
(FR-001); no hosted CI (clarified).

**Scale/Scope**: one maintainer, one release at a time, a few users.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design: still passes.*

| Principle | Status | How |
|---|---|---|
| I. Public APIs only | Pass | Packaging changes no product code. |
| II. Never require SIP changes | Pass | A notarized binary; nothing to disable (FR-013). |
| III. Least permission | Pass | Installing asks for no permission; the cask caveats explain the opt-in Accessibility use (security plan S1). |
| IV. Local-only | Pass | The tool makes no connection; the only network use is the download and macOS's own first-run check. |
| V. Reversible changes | Pass | Uninstall leaves stored data and wallpapers; no `zap` stanza (R9, R12). |
| VI. Distributable via Homebrew | Pass | This plan is that distribution: Developer ID, notarization, a cask (R4 to R9). |
| VII. Tested | Pass | Live checks on 26 and 27 exist for spec 001; the quickstart adds install checks on both. |
| VIII. Public-repo hygiene | Pass | Credentials only from the environment (R5); the hygiene scan covers the new files. |
| Release gate: code and security reviews | Pass, by maintainer decision | For 0.1.0 the two security reviews of 2026-10-07 stand in for both (spec Clarifications); recorded in the gate file (R10). Required in full from 1.0.0. |

## Project Structure

### Documentation (this feature)

```text
specs/005-packaging-and-release/
├── spec.md
├── plan.md              # this file
├── research.md          # decisions R1 to R12
├── data-model.md        # release, artifact, gate record, cask
├── quickstart.md        # validation scenarios
├── contracts/
│   ├── release-procedure.md   # scripts/release.sh: stages, options, exit codes
│   └── cask.md                # what the cask must contain
├── releases/
│   └── 0.1.0.md         # the gate record for this release (written during the release)
└── checklists/requirements.md
```

### Source Code (repository root)

```text
scripts/
└── release.sh                         # the procedure (R11)
packaging/
├── desktop-name-manager.rb.template   # the cask, rendered per release (R9)
└── release-notes.md.template          # release notes skeleton (FR-007)
README.md                              # install, verify, uninstall and full removal
```

**Structure Decision**: one script with stages rather than several scripts, so the gates, the version and the
paths are worked out in one place; templates live in `packaging/` so the tap only ever receives rendered
files.

## Complexity Tracking

None.
