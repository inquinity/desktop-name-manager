# Desktop Name Manager Constitution

## Core Principles

### I. Public APIs First
Labeling MUST use public macOS APIs only (stamping the label into a copy of a Desktop's
wallpaper and applying it with `NSWorkspace.setDesktopImageURL`). Private interfaces
(SkyLight) MAY be used only to read state (for example, the Space list), MUST be optional,
and MUST be isolated behind a single module. The app and CLI MUST keep working, with
reduced features, when a private interface is missing or changes.
Rationale: private APIs break across macOS releases and are unacceptable to Homebrew.

### II. Never Require SIP Changes
No feature, install step, or workaround may require disabling or weakening System
Integrity Protection. A feature that needs it MUST be dropped or redesigned.
Rationale: Homebrew rejects such software, and users should not lower system security.

### III. Least Permission
Labeling MUST require no macOS permissions. Accessibility (or any other permission) MAY be
used only for features that cannot work without it (such as switching Desktops or
re-deploying them), MUST be explicit and opt-in, and MUST be explained before it is
requested. Declining MUST leave all permission-free features working.

### IV. Local-Only
The app and CLI MUST NOT make network requests and MUST NOT collect telemetry, analytics,
or crash reports. No dependency may introduce either.
Rationale: the tool handles the user's personal wallpapers and Desktop names.

### V. Reversible Changes
Every change to a user's wallpaper MUST be exactly undoable. Removing a label MUST restore
the original image and its placement (fill, fit, tile, and so on) as they were. Original
images MUST never be modified in place; stamps are written to separate files.

### VI. Distributable via Homebrew
Release builds MUST be signed with a Developer ID, notarized, and pass Gatekeeper. The
project MUST NOT adopt any design that would prevent inclusion in a Homebrew cask.

### VII. Tested
- Rendering logic MUST have snapshot tests over the local `wallpaper-samples/` set. These
  run locally only; the images MUST NOT enter git.
- Behavior that touches the real wallpaper or Spaces MUST have live checks listed in its
  spec, run only after backing up
  `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` and restoring it
  afterwards.
- Behavior-changing work MUST be reviewed independently before merge, and every release
  MUST pass the code and security reviews described under Development Workflow.

### VIII. Public-Repo Hygiene
Tracked files MUST NOT contain personal paths, user names, display or Space UUIDs,
keychain profile names, credentials, or personal images. `wallpaper-samples/` and
`working-notes/` MUST stay untracked. Docs and tests use synthetic fixtures.

## Platform & Distribution Constraints

- macOS app plus the `dnm` CLI (alias `desktop-name`), sharing one core library.
- Bundle ID `com.altmansoftwaredesign.desktop-name-manager` (`.dev` suffix for dev builds).
- Releases are hosted on this repository's GitHub Releases; the cask ships first in
  `inquinity/homebrew-tap`.
- Licensed MIT. New dependencies MUST be justified in the plan and MUST satisfy
  principles I-VI.

## Development Workflow & Quality Gates

- Work proceeds through Spec Kit: spec, clarify, plan, tasks, analyze, implement. Artifacts
  in `specs/` are the source of truth, not chat history.
- Each plan MUST include a Constitution Check against principles I-VIII.
- Spec Kit extensions MUST be reviewed before install (some add Claude Code hooks); check
  `git status` for `.claude/settings.json` after any `specify` command.
- `speckit-implement` and `speckit-taskstoissues` keep `disable-model-invocation: true`.
- Every release MUST pass, before it is signed and published:
  - a code review of the changes since the previous release (correctness, reversibility,
    and compliance with principles I-VIII), and
  - a security review (permissions, private-interface use, network and telemetry
    absence, file access, dependencies, and the build and release pipeline).
  Findings MUST be resolved, or explicitly accepted by the maintainer in the release
  notes, before publishing. Review records live in `specs/` or the release's tracking
  issue, and MUST NOT contain personal paths or identifiers (principle VIII).
- Commits follow Conventional Commits and are signed.

## Governance

This constitution supersedes other practices. Amendments require a written change with
rationale, a Sync Impact Report reviewed by the maintainer, and updates to any affected
spec or plan. Versioning is semantic: MAJOR for removing or redefining a principle, MINOR
for adding or materially expanding one, PATCH for clarifications. Every plan and review
MUST verify compliance; any deviation MUST be justified in the plan's complexity
tracking and approved by the maintainer. Runtime guidance for agents lives in `CLAUDE.md`.

**Version**: 1.0.0 | **Ratified**: 2026-09-28 | **Last Amended**: 2026-09-28
