# Amendment to spec 005: releasing the app with `dnm` (for 0.4.0)

Written for spec 014 (T056). It changes what a release builds, signs, notarizes and installs. It is reviewed
separately from spec 014 and is not part of that spec's merge gate; 0.4.0 cannot ship the app without it. Layout:
[spec 014 contracts/app-bundle.md](../014-menu-bar-app/contracts/app-bundle.md).

## What changes

| Stage | Today (0.3.x) | From 0.4.0 |
|---|---|---|
| build | release build of `dnm`, signed, zipped as `dnm-<v>-arm64.zip` | release build of `dnm` and the app (`scripts/make-app.sh --release`), the bundle laid out per the contract; the zip holds `Desktop Name Manager.app` and the completions; named `desktop-name-manager-<v>-arm64.zip` |
| signing | `dnm`, hardened runtime, no entitlements | nested code first (`Contents/Helpers/dnm`), then the app, both with the Developer ID identity, hardened runtime, timestamp, **no entitlements**; `codesign --verify --deep --strict` |
| notarize | the zip | the zip, then `stapler staple` on the app (the zip is rebuilt from the stapled app) |
| verify | a quarantined copy of `dnm` run as a user's Mac would | the same for the app (opened, quit) and for `Contents/Helpers/dnm --version`; the checksum compared |
| cask | `binary "dnm"` and `binary "dnm", target: "desktop-name"` | `app "Desktop Name Manager.app"`, `binary "#{appdir}/Desktop Name Manager.app/Contents/Helpers/dnm"` and the same with `target: "desktop-name"`; completions as now |
| uninstall | removes `dnm` and the links; keeps the wallpapers and the store | also removes the app; the app's preferences and Login Item are cleared by the cask's `zap`; the wallpapers and the store are kept |

## Requirements

- **A-1.** The zip's app and the standalone `dnm` print the same version line.
- **A-2.** The checks of the build stage (no unexpected linked libraries, no network symbols, no private
  interfaces, only the documented entitlements, which are none) run on both executables.
- **A-3.** A release that does not pass `spctl --assess` and a quarantine run of the app is not published.
- **A-4.** The cask installs the app in `/Applications` and the two command names; upgrading from 0.3.x keeps the
  labels; uninstalling keeps the wallpapers.
- **A-5.** Nothing is published, pushed or changed in the tap without `--confirm`, as before.
- **A-6.** The release notes and the gate record add the macOS 26 checks (spec 014 quickstart scenario 15) as a gate
  for 0.4.0.

## Tasks

- [ ] A1. `scripts/release.sh` build stage: assemble, sign nested code then the app, zip, checksum.
- [ ] A2. notarize and staple the app; rebuild the zip from the stapled app; verify stage for the app.
- [ ] A3. `packaging/desktop-name-manager.rb.template`: the `app`, `binary` and `zap` stanzas; update `contracts/cask.md`.
- [ ] A4. Update `scripts/make-app.sh` for `--release` (release bundle ID, store, hardened runtime flags) if needed, with tests.
- [ ] A5. Update `contracts/release-procedure.md`, the release memory notes and the gate-record template; add the macOS 26 gate.
- [ ] A6. A dry run (`just publish check --dry-run`, `build --dry-run`) with an ad-hoc signature, then the real run with the maintainer's approval of each outward step.
- [ ] A7. Independent review of the diff (code and security: signing, entitlements, the cask).

Risk: high (signing, notarization, release, shared system). Plan and dry-run first; a separate approval before
each outward step (notarize, push, draft, publish, cask).
