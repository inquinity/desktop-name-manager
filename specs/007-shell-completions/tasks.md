---
description: "Task list for feature F1: shell completions"
---

# Tasks: Feature F1 — Shell Completions

**Input**: `specs/007-shell-completions/` (spec.md, plan.md, research.md, contracts/cli.md, quickstart.md)

**Tests**: included (unit in `DesktopNameCoreTests`, contract in `dnmTests`, release checks in `scripts/release.sh`).

## Phase 1: Core and CLI (US1, US2)

- [x] T001 [US2] `DisplayResolver.completionCandidates(in:aliases:includeAliases:)` in `Sources/DesktopNameCore/Displays/DisplayResolver.swift` (FR-003, FR-005, FR-007)
- [x] T002 [US2] `Sources/dnm/Completions.swift`: callbacks over the system and the store, every failure offers nothing (FR-006)
- [x] T003 [US2] `--display` completion in `DisplayOption.swift`; `alias` name (`--remove`) and display completions in `AliasCommand.swift` (FR-003, FR-004)
- [x] T004 [US1] Fixed values for `--style`, `--position` and `--size` from `Look`, `Position`, `Size`; `--color` light and dark in `SetCommand.swift` (FR-002)
- [x] T005 [P] [US2] Unit tests in `DisplayResolverTests.swift`: candidate order, overridden and absent aliases left out, `includeAliases: false`, duplicates, control characters, every candidate resolves (FR-005)
- [x] T006 [P] [US1] Contract tests in `Tests/dnmTests/CompletionTests.swift`: the hidden call for `--display`, `alias` positionals and `--remove`; no standard error output; no store created; the generated zsh and bash scripts contain exactly the enumerations' values and a `--display` callback; `--generate-completion-script` exits 0 (FR-002 to FR-008)

## Phase 2: Packaging (US3)

- [x] T007 [US3] `scripts/release.sh` `build`: generate `completions/_dnm`, `completions/_desktop-name` and `completions/dnm.bash` from the release binary; fail if one is missing, empty or does not register both names; extend the zip's expected list (FR-009)
- [x] T008 [US3] `packaging/desktop-name-manager.rb.template` and the `cask` stage test: the three stanzas; check the files after install and their removal after uninstall (FR-010)
- [x] T009 [P] [US3] Spec 005: FR-005's zip contents, `contracts/cask.md`, `contracts/release-procedure.md`

## Phase 3: Documentation and verification

- [x] T010 [P] README: what Tab offers, how completions arrive, what the shell must load, `--generate-completion-script` (FR-011)
- [x] T011 [P] `docs/release-notes/UNRELEASED.md` (bullets only, no heading)
- [x] T012 `just test` and `just periphery` pass (SC-005)
- [x] T013 Simulated Tab in bash and zsh against the debug build (quickstart 1 to 4); also a real interactive zsh and bash on a pseudo-terminal with the exact files from the release zip's payload, for `dnm` and `desktop-name` (2026-10-09)
- [x] T014 After publishing: live install check on the maintainer's Mac (quickstart 6; SC-004)
