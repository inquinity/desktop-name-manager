# Contract: `scripts/release.sh`

```text
scripts/release.sh <version> <stage> [--dry-run] [--confirm] [--tap DIR] [--help]
just release <major|minor|revision|current>   # before the stages: bump, notes, "Release X build N", signed tag
just publish <stage> [--confirm] ...          # a stage for the version in Version.xcconfig
```

Run from the repository root on the maintainer's Mac. Stages run in the order `check`, `build`, `notarize`,
`verify`, `push`, `draft`, `publish`, `cask`, `record`; each needs the previous
stage's output in `build.noindex/release-artifacts/<version>/`.

| Stage | Does | Publishes? |
|---|---|---|
| `check` | Gates: clean tree; `v<version>` is a signed tag on HEAD; the version equals `MARKETING_VERSION` in `Version.xcconfig` and has no GitHub release; HEAD's subject is "Release <version> build <n>"; `docs/release-notes/<version>.md` exists; `just test` and `just periphery` pass; live-check records for macOS 26 and 27; `Acknowledgements.md` is up to date (the license check); the gate file's review line is confirmed. Names the first unmet gate. | no |
| `build` | Release build for arm64 with the release stamp; `dnm --version` equals `<version>`; binary checks (no build folder, home folder or user name in `strings`; only allowed libraries in `otool -L`); sign (hardened runtime, timestamp, no entitlements); verify the signature; zip `dnm`, `LICENSE`, `Acknowledgements.md` and the license files of the components in the binary (`Licenses/swift-argument-parser-LICENSE.txt`) with `ditto`; SHA-256. | no |
| `notarize` | Submit the zip, wait up to 30 minutes, require "Accepted"; on failure fetch Apple's log and stop. | no (sends the zip to Apple) |
| `verify` | Unzip to a temporary folder, mark the binary as downloaded, run `dnm --version` (macOS's first-run check), `syspolicy_check distribution`, compare the SHA-256; results go to the procedure log. | no |
| `push` | Pushes `main` and the signed tag to `origin`. | **yes** (the code and tag). Needs `--confirm` |
| `draft` | `gh release create v<version> --draft --verify-tag` with the zip, the `.sha256` file and the rendered release notes. | a **draft**, not public. Needs `--confirm` |
| `publish` | Turns the draft public. | **yes**. Needs `--confirm` |
| `cask` | Renders the cask into the local tap clone given by `--tap`, runs `brew audit --cask --strict --online` and a local-tap install, run and uninstall test, then prints the `git` commands to commit and push the tap. Never pushes. | no (prints the push). Needs `--confirm` |
| `record` | Appends the procedure log (kept in the build folder so the tree stays clean during the release) to the gate record, for the maintainer to review and commit. | no |

## Options

- `--dry-run`: runs `check` (reporting every unmet gate instead of stopping at the first) and `build`
  (signing ad hoc when `DNM_SIGNING_IDENTITY` is not set), then prints what `notarize`, `verify`, `draft`,
  `publish` and `cask` would do. Sends nothing anywhere.
- `--confirm`: required by `draft`, `publish` and `cask`; without it they print what they would do and
  exit 1.
- `--tap DIR`: the maintainer's local clone of `inquinity/homebrew-tap` (required by `cask`).

## Environment

- `DNM_SIGNING_IDENTITY`, else `SIGNING_IDENTITY` in the git-ignored `Secrets.xcconfig`, else the keychain's
  only "Developer ID Application" identity (used by `build`; a dry run always signs ad hoc).
- `DNM_NOTARY_PROFILE`, else `NOTARY_PROFILE` in `Secrets.xcconfig`: a `notarytool` keychain profile (used
  by `notarize`).

Neither value is ever printed, logged or written to a file. A missing or unusable one is reported by the
variable's name only.

## Exit codes

`0` success; `1` a gate or step failed, or a stage needs `--confirm` (the message names it); `2` invalid
usage (unknown stage or option, malformed version).

## Output

Progress and results on standard output; errors on standard error. Nothing written outside
`build.noindex/release-artifacts/<version>/`, the gate record, a temporary folder (removed on exit) and,
for `cask`, the tap clone's `Casks/desktop-name-manager.rb`.
