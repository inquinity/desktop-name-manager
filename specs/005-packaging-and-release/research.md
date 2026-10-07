# Research: Packaging and Release (0.1.0, M1)

Decisions for the first, unlisted release. Each has the decision, why, and what else was considered.
Reference implementation: the maintainer's sibling project (its build and publish scripts), adapted for a
command-line tool and for this repository's rule that no credential name is ever committed.

## R1. The artifact

- **Decision:** `dnm-<version>-arm64.zip`, made with `ditto -c -k` (without extended attributes), holding
  the signed `dnm` binary, `LICENSE`, `Acknowledgements.md` and the license files of the components in the
  binary, as `scripts/make-acknowledgements.sh --binary-license-files` lists them (constitution 2.1.0).
  The alias `desktop-name` is a second link the cask creates, not a second file.
- **Why:** clarified 2026-10-07 (a zip; Apple silicon only). `ditto` keeps the code signature intact, which
  `zip` can damage (the sibling project's experience).
- **Considered:** a stapled `.pkg` (works offline, but needs the admin password and receipt cleanup); a
  `.dmg` (the binary copied out of it carries no ticket, so no gain).

## R2. The build

- **Decision:** `swift build -c release --arch arm64 --product dnm --force-resolved-versions` with the
  release build stamp (`scripts/build-stamp.sh --release`, which refuses a dirty tree), into
  `build.noindex/`. The version and build number come from `Version.xcconfig` (read by `scripts/ver` and
  `scripts/build-num`, stamped into the binary), the single source (FR-003); the procedure checks that the
  built `dnm --version` prints exactly `<version> (<build>)`.
- **Why:** the same toolchain and pinned dependency as the tested builds (security plan S5).
- **Considered:** a universal build (built and tested, but Intel is out of scope for 0.1.0).

## R3. Checks on the binary before signing (security plan S7)

- **Decision:** fail if `strings -a` finds the build folder, the home folder or the user name; fail if
  `otool -L` lists any library outside the allowed system set (the same list as the linkage test, run on
  the release binary and never skipped); fail if the artifact holds anything but those files (so no
  `prototype/` tool or `switch-timing` can ship).
- **Why:** the reviews found that nothing checked the release binary itself. A manual check on 2026-10-07
  found no paths, so these are guards against regressions.

## R4. Signing

- **Decision:** `codesign --force --sign "$DNM_SIGNING_IDENTITY" --options runtime --timestamp
  --identifier com.altmansoftwaredesign.dnm`, with no entitlements. Verify with
  `codesign --verify --strict --verbose=2` and check that `codesign -dvv` shows the hardened runtime flag
  and a "Developer ID Application" authority.
- **Why:** notarization requires the hardened runtime and a secure timestamp; the tool needs no
  entitlement (no JIT, no library validation exceptions, no sandbox).

## R5. Credentials (FR-008)

- **Decision (revised 2026-10-07 to match the sibling project's no-typing setup):** the signing identity
  is `DNM_SIGNING_IDENTITY`, else `SIGNING_IDENTITY` in the local, git-ignored `Secrets.xcconfig` (the
  sibling project's file name), else the keychain's only "Developer ID Application" identity. The notary
  profile is `DNM_NOTARY_PROFILE`, else `NOTARY_PROFILE` in `Secrets.xcconfig`. The sibling project writes
  its defaults into its tracked build script; here they stay in the untracked file. The procedure checks the identity with `security find-identity -v -p codesigning` and
  the profile with `xcrun notarytool history`, and on failure says which variable is wrong without printing
  its value. Nothing writes either value to a file, log, release note or the tap.
- **Why:** the constitution forbids keychain profile names in tracked files; the sibling project's
  built-in defaults are exactly what must not be copied. The hygiene scan's hashed deny-list (security plan
  S6) guards the profile name.

## R6. Notarization

- **Decision:** `xcrun notarytool submit <zip> --keychain-profile "$DNM_NOTARY_PROFILE" --wait --timeout 30m`.
  On anything but "Accepted", fetch the log with `notarytool log` and stop. No stapling (impossible for a
  zip or a bare binary).
- **Why:** bounded waiting (spec edge case: slow or unavailable service).

## R7. Verifying the download (FR-006, User Story 5)

- **Decision:** after notarization, unzip into a temporary folder, mark the binary as downloaded
  (`com.apple.quarantine`, as a browser or Homebrew would), and run `dnm --version`: macOS performs its
  first-run notarization check, and the run must succeed and print the version. Also record
  `syspolicy_check distribution dnm`, the codesign details, and the SHA-256. The release notes give
  readers the same commands.
- **Why:** this is the check a user's Mac makes. `spctl --assess` is meant for app bundles and reports
  bare binaries poorly.

## R8. Hosting (FR-007)

- **Decision:** a GitHub release `v<version>` on this repository, created as a **draft** with
  `gh release create --draft --verify-tag`, with the zip and a `.sha256` file, then published by a separate
  step (`gh release edit --draft=false`). The tag is a signed, annotated tag on the release commit, pushed by
  the maintainer.
- **Why:** FR-001 requires a separate confirmation for publishing; a draft is invisible to the public.

## R9. The cask

- **Decision:** `Casks/desktop-name-manager.rb` in the tap, rendered by the procedure from a template in this
  repository (`packaging/desktop-name-manager.rb.template`):
  `version`, `sha256`, `url` (the release download), `name`, `desc`, `homepage`,
  `livecheck` (`strategy :github_latest`), `depends_on macos: :tahoe` (macOS 26 or later), `depends_on arch: :arm64`,
  `binary "dnm"`, `binary "dnm", target: "desktop-name"`, and `caveats` (the Accessibility note from
  security plan S1, and where full removal is documented). **No `zap` stanza:** stored data is never
  removed automatically (FR-015). The tap's README is not touched (FR-010).
- **Testing before any push (FR-011):** a temporary local tap (`brew tap-new` with no remote), `brew audit
  --cask --strict --online` (not `--new`, which applies the official
  repository's acceptance rules such as a minimum number of stars), then install, run both commands, uninstall, and remove the temporary tap. The
  procedure writes the cask into the maintainer's local clone of the tap and prints the commit and push
  commands; it never pushes.
- **Considered:** writing the cask by hand each release (error-prone checksum and version).

## R10. Gates (FR-002)

- **Decision:** a gate file per release, `specs/005-packaging-and-release/releases/<version>.md`. The
  automated gates are run by the procedure (clean tree, tag on HEAD, new version, `just test`, Periphery,
  live-check records for macOS 26 and 27 present in `specs/001-labels-and-cli/review-notes.md`). The
  review gate is a maintainer-confirmed line naming the review record (for 0.1.0, the 2026-10-07 security
  plan). The procedure refuses to start if any line is unmet and names it.
- **Why:** the reviews are human judgments; the record must say who accepted what (FR-017), without
  personal data.

## R11. Shape of the procedure

- **Decision:** one script, `scripts/release.sh <version> <stage>`, with stages run in order:
  `check` (gates), `build` (build, binary checks, sign, zip), `notarize`, `verify`, `draft`, `publish`,
  `cask`. `--dry-run` runs `check` and `build` (signing ad hoc if no identity is set) and prints what each
  later stage would do. `draft`, `publish` and `cask` each refuse to run without `--confirm`, so each
  outward step is a separate, explicit decision (FR-001).
- **Why:** each stage can be repeated after a failure without redoing earlier ones, and the dangerous ones
  cannot happen by accident.

## R12. Uninstall and full removal (User Story 4)

- **Decision:** `brew uninstall --cask desktop-name-manager` removes both links and the binary. Full
  removal is documented in the README and the cask caveats: first remove labels you want gone with
  `dnm remove` (or accept that those Desktops lose their labeled picture), then delete the store folder by
  hand. Homebrew never deletes it.
- **Why:** a labeled Desktop must never be left blank by an uninstall.
