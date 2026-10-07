# Releases

One gate record per release (`<version>.md`), written by `scripts/release.sh` and the maintainer, and
committed after publishing (FR-017). The procedure is in
[../contracts/release-procedure.md](../contracts/release-procedure.md).

## Upgrades (User Story 3; tested from 0.1.1)

Users upgrade with `brew upgrade --cask desktop-name-manager`; the cask's `livecheck` finds new GitHub
releases. Stored labels live outside the install and are kept. For each release after 0.1.0, the quickstart
adds: install the previous release, label a Desktop, upgrade, and confirm the label still shows and
`dnm show`, `dnm undo` (within its window) and `dnm remove` work (SC-004).

## Withdrawing a bad release (User Story 6; tested from 0.1.1)

1. Mark the GitHub release as withdrawn: edit its notes to start with "Withdrawn: <reason>; use <previous
   version>", and mark it as a pre-release so it is no longer "latest". Never delete it (FR-016).
2. Return the cask in the tap to the previous good version and SHA-256 (render it again with
   `scripts/release.sh <previous version> cask --confirm --tap <tap clone>`), then commit and push the tap.
3. Record the withdrawal in that release's gate record.
4. Users already on the withdrawn release get the next good release with `brew upgrade --cask`.
