# Data Model: Packaging and Release (0.1.0)

Files, not a database. Nothing here holds a credential, a personal path or an identifier.

## Release

| Field | Example | Rules |
|---|---|---|
| version | `0.1.0` | Semantic version; equals `DesktopNameCoreInfo.version` at the tag; never reused (FR-003) |
| tag | `v0.1.0` | Signed, annotated, on the release commit; HEAD at release time (FR-001, FR-004) |
| commit | short hash | The tagged commit; the tree must be clean |
| toolchain | `swift --version` first line, Xcode build | Recorded in the gate record and release notes (FR-004) |
| state | draft → published (→ withdrawn, from 0.1.1) | Changes only through the procedure's confirmed stages |

## Artifact

| Field | Example | Rules |
|---|---|---|
| file | `dnm-0.1.0-arm64.zip` | Holds exactly `dnm`, `LICENSE`, `Acknowledgements.md` and the license files of the components in the binary (`Licenses/swift-argument-parser-LICENSE.txt`) (R1, R3) |
| sha256 | 64 hex characters | Same value in the release's `.sha256` file, the cask and the gate record |
| signature | Developer ID Application, hardened runtime, timestamp | No entitlements (R4) |
| notarization | submission id, status "Accepted" | Stored in the gate record (the id is Apple's, not personal) |

## Gate record (`releases/<version>.md`)

One file per release, written by the procedure and committed by the maintainer after publishing (FR-017).

| Section | Contents |
|---|---|
| Release | version, tag, commit, date (UTC), toolchain |
| Gates | each gate (clean tree, tag, new version, tests, Periphery, live checks on 26 and 27, reviews) with pass or the name of the accepting record |
| Artifact | file name, SHA-256, signing authority (the certificate's common name, which is public), notarization id and status |
| Verification | results of the codesign, first-run and `syspolicy_check` checks |
| Cask | `brew audit` result; local install, run and uninstall results |

The "who ran it" field records the role ("maintainer"), not a user name.

## Cask (`Casks/desktop-name-manager.rb` in the tap)

Rendered from `packaging/desktop-name-manager.rb.template`; see [contracts/cask.md](contracts/cask.md).

## State changes

```text
check ──► build ──► notarize ──► verify ──► draft (--confirm) ──► publish (--confirm) ──► cask (--confirm)
```

Each arrow requires the previous stage's output in `build.noindex/release-artifacts/<version>/`. A failed
stage leaves earlier outputs in place and publishes nothing.
