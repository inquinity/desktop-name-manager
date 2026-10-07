# Quickstart: validating the 0.1.0 release

How to show the release works end to end. Procedure details are in
[contracts/release-procedure.md](contracts/release-procedure.md); the cask's contents in
[contracts/cask.md](contracts/cask.md).

## Before the release (maintainer's Mac)

| # | Scenario | Command | Expected |
|---|---|---|---|
| 1 | Dry run | `scripts/release.sh 0.1.0 check --dry-run`, then `scripts/release.sh 0.1.0 build --dry-run` | Every unmet gate listed; an ad hoc signed zip built; the later stages described; nothing sent anywhere |
| 2 | A gate refuses | On a dirty tree, `scripts/release.sh 0.1.0 check` | Exit 1, naming the clean-tree gate (User Story 1, scenario 2) |
| 3 | Missing credential | Unset `DNM_SIGNING_IDENTITY`, run `build` | Exit 1, naming the variable, printing no value (spec edge case) |
| 4 | Outward steps need confirmation | `scripts/release.sh 0.1.0 draft` without `--confirm` | Prints what it would do; exit 1; no draft created |
| 5 | Signed and notarized | `build`, `notarize`, `verify` | Hardened runtime and Developer ID in the signature; notarization "Accepted"; the quarantined binary runs and prints `0.1.0` (FR-005, FR-006) |
| 6 | Binary hygiene | `build` | No build folder, home folder or user name in the binary; only system libraries linked; the zip holds only `dnm` and `LICENSE` (security plan S7) |
| 7 | Cask tested locally | `scripts/release.sh 0.1.0 cask --confirm --tap <tap clone>` | `brew audit` passes; local install, `dnm --version` and `desktop-name --version` match, uninstall clean; the push commands printed, nothing pushed (FR-011) |

## After publishing (macOS 26 and macOS 27, Apple silicon)

| # | Scenario | Command | Expected |
|---|---|---|---|
| 8 | Quiet install | `brew install --cask inquinity/tap/desktop-name-manager` | Both commands on the PATH, same version; no Gatekeeper warning, no permission prompt; under 2 minutes (User Story 2, SC-001) |
| 9 | Offline after the first run | Run `dnm --version` once, turn the network off, run `dnm list` | Works (User Story 2, scenario 3) |
| 10 | Unlisted | Read the tap's README | `desktop-name-manager` is not listed (FR-010) |
| 11 | Uninstall keeps the wallpaper | Label a Desktop, `brew uninstall --cask desktop-name-manager` | Both commands gone; the labeled wallpaper still shows; the store folder is still there (User Story 4) |
| 12 | Verify independently | The verification commands from the release notes | Signature, notarization and checksum confirmed; altering one byte of the zip makes the checksum fail (User Story 5, SC-003) |
| 13 | Intel refused | On an Intel Mac, the install command | Homebrew refuses with an architecture message; nothing installed (FR-012) |

Live checks on the real wallpaper follow the backup and private-store rules in `CLAUDE.md`.
