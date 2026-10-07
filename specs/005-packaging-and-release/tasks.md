# Tasks: Packaging and Release (0.1.0, M1)

**Input**: Design documents from `/specs/005-packaging-and-release/` (plan.md, spec.md as clarified 2026-10-07,
research.md, data-model.md, contracts/, quickstart.md)

**Scope**: User Stories 1, 2, 4 and 5 for 0.1.0. User Stories 3 and 6 are documented only (T024) and tested
from 0.1.1.

**Tests**: the spec asks for verification inside the procedure (FR-006, FR-011) and for live install
checks (quickstart); there are no new unit tests. Shell scripts pass `shellcheck`.

**Marked steps**: tasks marked **(maintainer)** publish, push, sign a tag, or switch Desktops; each needs the
maintainer's explicit go-ahead at that moment, and Desktop-switching runs are announced with `say`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story the task serves (US1, US2, US4, US5)

## Phase 1: Setup

- [x] T001 Move `.github/workflows/ci.yml` and `.github/dependabot.yml` to `docs/ci/` as inactive drafts (keeping their content), add `docs/ci/README.md` saying they are unreviewed drafts for M5 (T006 of spec 001), and update references in `specs/001-labels-and-cli/` and `docs/` (security plan decision 4: no hosted CI before M5)
- [x] T002 [P] Create `packaging/` with `packaging/desktop-name-manager.rb.template` per `contracts/cask.md` (placeholders `@VERSION@` and `@SHA256@`; `depends_on macos: ">= :tahoe"`, `depends_on arch: :arm64`, `binary "dnm"`, `binary "dnm", target: "desktop-name"`, `livecheck` with `strategy :github_latest`, `caveats` with the Accessibility note from `About.accessibilityScope` and a pointer to the README's full-removal section; no `zap` stanza)
- [x] T003 [P] Create `packaging/release-notes.md.template` (FR-007: what changed, known gaps, gate outcomes with a link to the gate record, supported macOS versions "26 or later, Apple silicon", source commit, toolchain, and the verification commands of research R7), with placeholders `@VERSION@`, `@COMMIT@`, `@TOOLCHAIN@`, `@SHA256@`
- [x] T004 [P] Add `build.noindex/release-artifacts/` handling: confirm it is covered by the existing `build.noindex/` ignore rule in `.gitignore` (no change expected) and that `packaging/` is tracked

## Phase 2: Foundational (blocks every user story)

- [x] T005 Create `scripts/release.sh` skeleton (shell-script-expert style: `set -euo pipefail`, the standard color block, `usage`, argument parsing for `<version> <stage> [--dry-run] [--confirm] [--tap DIR] [--help]`, exit codes 0/1/2 per `contracts/release-procedure.md`, version format check `^[0-9]+\.[0-9]+\.[0-9]+$`, the artifact folder `build.noindex/release-artifacts/<version>/`, a temporary folder removed by an EXIT trap)
- [x] T006 In `scripts/release.sh`, add credential helpers that read only `DNM_SIGNING_IDENTITY` and `DNM_NOTARY_PROFILE` from the environment, check them with `security find-identity -v -p codesigning` and `xcrun notarytool history`, and report a problem by the variable's name only, never printing a value (FR-008, research R5)
- [x] T007 Create the gate record template and the 0.1.0 record `specs/005-packaging-and-release/releases/0.1.0.md` (sections per `data-model.md`: Release, Gates, Artifact, Verification, Cask; the review gate line names `specs/001-labels-and-cli/security-plan-2026-10-07.md` and the maintainer decision of 2026-10-07; "who ran it" is the role "maintainer", never a user name)

**Checkpoint**: the script parses its arguments and refuses unknown stages; credentials are checked without being printed.

## Phase 3: User Story 1 - The maintainer cuts a release that has passed its gates (P1)

**Goal**: one procedure builds, checks, signs, notarizes, verifies and drafts the release, refusing on any unmet gate.

**Independent test**: quickstart scenarios 1 to 6: a dry run lists unmet gates and builds an ad hoc signed zip; a dirty tree is refused by name; a missing credential is named without its value; `draft` without `--confirm` does nothing.

- [x] T008 [US1] Stage `check` in `scripts/release.sh`: clean tree; `v<version>` is a signed annotated tag on HEAD (`git tag -v`); `<version>` equals `DesktopNameCoreInfo.version` in `Sources/DesktopNameCore/DesktopNameCore.swift`; no GitHub release exists for the tag (`gh release view`, skipped with a note under `--dry-run`); `just test` and `just periphery` pass; `specs/001-labels-and-cli/review-notes.md` has live-run records for macOS 26 and macOS 27; the gate record's review line is confirmed. Stop at the first unmet gate, naming it; under `--dry-run`, list every unmet gate (FR-002)
- [x] T009 [US1] Stage `build` in `scripts/release.sh`: `swift build -c release --arch arm64 --product dnm --scratch-path build.noindex --force-resolved-versions` with the stamp flags of `scripts/build-stamp.sh --release` read one per line; check the built `dnm --version` prints exactly `<version>` (FR-003)
- [x] T010 [US1] Binary checks in the `build` stage of `scripts/release.sh` (security plan S7, research R3): fail if `strings -a` finds the repository path, `$HOME` or the user name; fail if `otool -L` lists a library outside the allowed set used by `Tests/dnmTests/LinkedLibrariesTests.swift`; run on the release binary, never skipped
- [x] T011 [US1] Signing in the `build` stage of `scripts/release.sh`: `codesign --force --sign "$DNM_SIGNING_IDENTITY" --options runtime --timestamp --identifier com.altmansoftwaredesign.dnm` (ad hoc `-` under `--dry-run` when the identity is unset), no entitlements; verify with `codesign --verify --strict --verbose=2` and check `codesign -dvv` shows the runtime flag and a "Developer ID Application" authority (skipped for ad hoc) (research R4)
- [x] T012 [US1] Packaging in the `build` stage of `scripts/release.sh`: `ditto -c -k` a folder holding exactly `dnm` and `LICENSE` into `dnm-<version>-arm64.zip`; write `dnm-<version>-arm64.zip.sha256`; record file name and SHA-256 in the gate record (research R1)
- [x] T013 [US1] Stage `notarize` in `scripts/release.sh`: `xcrun notarytool submit <zip> --keychain-profile "$DNM_NOTARY_PROFILE" --wait --timeout 30m`; require "Accepted", record the submission id; on failure run `notarytool log` and stop (research R6, spec edge case on slow service)
- [x] T014 [US1] Stage `draft` in `scripts/release.sh`: without `--confirm`, print the planned `gh release create v<version> --draft --verify-tag` command and exit 1; with it, render `packaging/release-notes.md.template` and create the draft with the zip and `.sha256` (FR-001, FR-007, research R8)
- [x] T015 [US1] Stage `publish` in `scripts/release.sh`: requires `--confirm`; refuses unless the draft exists and its asset checksum equals the recorded SHA-256; then `gh release edit v<version> --draft=false` (FR-001, FR-006)
- [x] T016 [US1] `--dry-run` across stages in `scripts/release.sh`: runs `check` and `build`, then prints what `notarize`, `verify`, `draft`, `publish` and `cask` would do, sending nothing anywhere (FR-018); `shellcheck` clean
- [x] T017 [US1] Run quickstart scenarios 1 to 4 (dry run, dirty tree, missing credential, unconfirmed draft) and record the results in `specs/005-packaging-and-release/releases/0.1.0.md`

**Checkpoint**: User Story 1 works up to a draft, without anything public.

## Phase 4: User Story 5 - Anyone can verify a release independently (P3, needed by FR-006)

**Goal**: the procedure verifies the download the way a user's Mac does, and the release notes let anyone repeat it.

**Independent test**: quickstart scenarios 5 and 12.

- [x] T018 [US5] Stage `verify` in `scripts/release.sh`: unzip into the temporary folder, set `com.apple.quarantine` on `dnm`, run it with `--version` (macOS's first-run notarization check) and require `<version>`; record `syspolicy_check distribution`, `codesign -dvv` and the SHA-256 comparison in the gate record (FR-006, research R7)
- [x] T019 [US5] Verification section in `packaging/release-notes.md.template`: the `shasum -a 256 -c`, `codesign -dvv` and quarantine-then-run commands, and the statement that a one-byte change fails the checksum (User Story 5, SC-003)

## Phase 5: User Story 2 - A user installs the tool quietly through the tap (P1)

**Goal**: an unlisted cask installs both commands on Apple-silicon Macs with macOS 26 or later, without a Gatekeeper warning.

**Independent test**: quickstart scenarios 7 to 10 and 13.

- [x] T020 [US2] Stage `cask` in `scripts/release.sh`: requires `--confirm` and `--tap DIR`; render `packaging/desktop-name-manager.rb.template` with the version and SHA-256; test it in a temporary local tap (`brew tap-new` with no git remote, `brew audit --cask --new --strict`, `brew install --cask`, `dnm --version` and `desktop-name --version` equal, `brew uninstall --cask`, `brew untap`); then write `Casks/desktop-name-manager.rb` into the tap clone and print the `git -C <tap> add/commit/push` commands without running them; never edit the tap's `README.md` (FR-009, FR-010, FR-011)
- [x] T021 [US2] README "Install" section in `README.md`: `brew install --cask inquinity/tap/desktop-name-manager` (adding the tap first), Apple silicon and macOS 26 or later only for now, the first run needs the network once, and the Accessibility note for `--desktop`

## Phase 6: User Story 4 - A user uninstalls without losing their wallpaper (P2)

**Goal**: uninstalling removes the commands and leaves wallpapers and stored data; full removal is documented with its warning.

**Independent test**: quickstart scenario 11.

- [x] T022 [US4] README "Uninstall" section in `README.md`: `brew uninstall --cask desktop-name-manager` removes `dnm` and `desktop-name` and leaves every wallpaper and the store; "Full removal": first `dnm remove` the labels you want gone (or accept that those Desktops lose their labeled picture), optionally `dnm prune --yes`, then delete `~/Library/Application Support/com.altmansoftwaredesign.desktop-name-manager` by hand; Homebrew never deletes it (FR-015, research R12)
- [x] T023 [US4] Confirm the rendered cask has no `zap` stanza and its caveats point to the README's full-removal section (`contracts/cask.md`)

## Phase 7: Release 0.1.0 (gates and maintainer steps)

- [x] T024 Document upgrade and withdrawal for later releases in `specs/005-packaging-and-release/releases/README.md`: `brew upgrade --cask`, and withdrawing (mark the GitHub release, return the cask to the previous version), tested from 0.1.1 (User Stories 3 and 6)
- [ ] T025 **(maintainer)** M1 confirmation runs with the measured `--desktop` settings on this Mac: `Tests/live/live-timing.sh` (every case PASS against SC-008) and `Tests/live/live-desktops.sh` (no failed check); record both in `docs/research/timings.md` and `specs/001-labels-and-cli/review-notes.md` (roadmap M1 exit criterion 1)
- [x] T026 Hygiene check of everything to be pushed: `git log origin/main..main` reviewed for personal paths, user names, identifiers and credentials (the hygiene scan plus a `git grep` over the range), and `just test` green
- [ ] T027 **(maintainer)** Push `main` to `origin` after T001 and T026
- [ ] T028 **(maintainer)** Create the signed annotated tag `v0.1.0` on the release commit (`git tag -s v0.1.0`) and push it
- [ ] T029 **(maintainer)** Run `scripts/release.sh 0.1.0 check`, `build`, `notarize`, `verify`, then `draft --confirm` (credentials set in the maintainer's shell)
- [ ] T030 **(maintainer)** Review the draft, then `scripts/release.sh 0.1.0 publish --confirm`
- [ ] T031 **(maintainer)** `scripts/release.sh 0.1.0 cask --confirm --tap <tap clone>`, review the printed diff, then commit and push the tap
- [ ] T032 Quickstart scenarios 8 to 13 on macOS 26 and macOS 27 (Apple silicon), recorded in `specs/005-packaging-and-release/releases/0.1.0.md`; commit the completed gate record

## Phase 8: Polish

- [ ] T033 [P] Update `ROADMAP.md` (M1 status), `specs/001-labels-and-cli/security-plan-2026-10-07.md` (mark resolved items with their commits) and `specs/005-packaging-and-release/checklists/requirements.md` as needed
- [ ] T034 [P] Run the hygiene scan and `shellcheck` over `scripts/release.sh` and the templates one last time

## Dependencies

- Phase 1 → Phase 2 → User Story 1 (T008 to T017) → User Story 5 (T018, T019) → User Story 2 (T020, T021) → User Story 4 (T022, T023) → Phase 7.
- T002 and T003 can be written in parallel with T005 to T007.
- T025 (live runs) is independent of the script work and can happen whenever the maintainer is away from the Mac.
- T027 needs T001 (no hosted CI pushed) and T026. T028 needs T027. T029 needs T028 and the credentials. T030 needs T029. T031 needs T030 (the cask points at the published download). T032 needs T031.

## Parallel example

```text
T002 packaging/desktop-name-manager.rb.template
T003 packaging/release-notes.md.template      (in parallel with T005 to T007 in scripts/release.sh)
```

## Implementation strategy

Build the procedure up to a dry run first (Phases 1 to 3 without credentials), then the verification and
cask stages, then the README. The release itself (Phase 7) is a sequence of short maintainer-approved
steps; nothing becomes public before T030.
