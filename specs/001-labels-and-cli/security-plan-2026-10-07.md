# Security resolution plan, 2026-10-07 (before the M1 / 0.1.0 release)

Two independent, read-only security reviews of `main` at `e88c74d` (Sources, Tests, scripts, CI, specs and
`prototype/`), run in parallel by separate agents:

- **OSS:** the `security-oss-app-reviewer` method (static-first: egress, credentials, filesystem reach,
  dependencies, CI). Findings OSS-1 to OSS-11.
- **SR:** the `security-review` method applied to the whole tree. Findings SR-1 to SR-9. The 197 unit and
  contract tests passed; four scans skipped outside a git checkout and passed in the main checkout.

Both found no network or telemetry code, no private interfaces in the shipped code, no credentials, no
subprocesses, guarded path handling and deletions, and a single pinned dependency. One finding was checked
by hand afterwards: the current release and kit binaries contain no home path or user name (OSS-4).

## Merged findings

| ID | Sev | Finding | Source | Proposed resolution | When |
|---|---|---|---|---|---|
| S1 | medium | `--desktop`'s Accessibility grant goes to the terminal app, so everything run in that terminal can post input, not only `dnm` | OSS-1, SR-4 | Say so plainly in `dnm check`, `dnm about`, the README and the cask caveats; suggest removing the grant after use or using a dedicated terminal. Long term, the app (M2) holds its own grant | M1 (docs); M2 (own identity) |
| S2 | low | Resolving the saved bookmark of an original can mount a network volume or show UI | SR-1 | Resolve with `.withoutUI` and `.withoutMounting`; test that the options are set | M1 |
| S3 | low | An existing store folder keeps loose permissions; new files are briefly readable at umask permissions before `chmod 600` | OSS-5, SR-2 | Write each file as 0600 from creation (temporary file, then rename); tighten the default store folder to 0700 and warn when a `DNM_STORE_DIR` folder is group- or world-accessible | M1 |
| S4 | low | Labels (and display names) may contain terminal control characters (escape sequences, bidi overrides), printed as-is | OSS-3, SR-7 | Reject control and bidi characters in `LabelText` (keeping emoji joiners and variation selectors); escape control characters in display names when printing | M1 |
| S5 | low | Builds do not force the pinned dependency revision | OSS-7, SR-3 | `--force-resolved-versions` in the justfile, CI and the release procedure; the release checks the swift-argument-parser revision | M1 (justfile, release); CI with T006 |
| S6 | low | The hygiene test assembles the maintainer's keychain profile name, so it can be read from the public repo | OSS-2 | Keep the deny-list as SHA-256 hashes of the forbidden tokens, or in an untracked local file; no history rewrite (it is not a credential) | M1 |
| S7 | low | Nothing checks the release binary itself (embedded paths, linkage, no research tools) | OSS-4, OSS-11 | Release procedure: fail if `strings` finds the build root or home path, run the linkage check on the release binary (fail, never skip), and assert no `prototype/` or `switch-timing` binary ships | M1 (spec 005) |
| S8 | info | Notarizing a bare command-line binary: a ticket cannot be stapled to it or to a zip; hardened runtime not stated | OSS-10, SR Q3 | Clarify spec 005: the artifact (zip of the binary, or a pkg), hardened runtime with no entitlements, and FR-005's offline acceptance relaxed if a zip | M1 (spec 005 clarify) |
| S9 | info | `Store.removeFile` would delete a folder recursively | SR-8 | Remove only regular files (not following symlinks), as `Cleanup` already does | M1 |
| S10 | info | Original paths and bookmarks in the manifest are trusted (another process of the same user could point them at any readable image) | OSS-6, SR-6 | Before applying, require a regular image file that `WallpaperKind` accepts; record that same-user tampering beyond that is out of scope | M1 |
| S11 | info | The live kit tells testers to strip quarantine from the whole folder; its checksums sit inside it | OSS-8, SR-5 | Strip quarantine only from `dnm` and `switch-timing`; keep this advice out of release docs; give the SHA-256 separately | M1 |
| S12 | info | Build-stamp flags break on a checkout path with spaces | SR-9 | Pass the flags as an array, one per line | M1 |
| S13 | info | CI workflow: runner label still marked TODO; first-time contributors' pull requests should need approval | OSS-7, SR Q4 | Settle with T006. **Pushing `main` publishes `.github/workflows/ci.yml` and starts it**, so before the push either review it (T006) or move it out until then | Before the push |
| S14 | info | The CodeQL gate cannot run: the query tag file is not committed | OSS-9 | Pin and commit the query tag | M5 |
| S15 | info | `prototype/` uses private interfaces | OSS-11 | Research only, never built into the product; covered by S7's release check | M1 (via S7) |

## Questions for the maintainer

1. **`--desktop` in 0.1.0:** ship it with the S1 warnings (recommended), or hold it until the app has its
   own Accessibility identity (M2)?
2. **Threat model:** is another process running as the same user in scope? The plan assumes no, beyond
   keeping every file operation inside the store (S9, S10).
3. **`DNM_STORE_DIR` in release builds:** keep it (the plan assumes yes: it is the user's own environment,
   and the tests and kits rely on it) or limit it to debug builds?
4. **The CI workflow before the push (S13):** review it now (T006), or move it out of the tree until M5?

## Order of work

1. Code fixes S2, S3, S4, S9, S10, with tests (one commit each).
2. S6 (hygiene deny-list), S12 (build-stamp flags), S5 (justfile), S11 (kit wording).
3. S1 documentation and `check` and `about` wording.
4. Spec 005 clarify for the M1 stage, covering S7, S8 and S5's release checks.
5. S13 decision, then the hygiene check and the push.

## Deferred, with reasons

- **S14 and the independent code review** (`/code-review ultra`): required before M5 (1.0.0). For M1
  the maintainer chose these two security reviews (2026-10-07). The constitution requires the code and
  security reviews before any signed, published build, so M1 needs either the code review or a recorded
  constitution decision for the preview stage.
- **S1's own identity:** needs the app (M2).
