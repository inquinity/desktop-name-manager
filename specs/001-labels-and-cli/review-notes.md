# Review Notes: Desktop Labels and the `dnm` Command-Line Tool

Records of the reviews required by the constitution (principle VII and Development
Workflow). Findings, decisions and acceptances go here. Never put personal paths, user
names, display or Space identifiers, or keychain profile names in this file.

## Review modes (agreed 2026-09-30)

| Mode | When | How | Output |
|---|---|---|---|
| Code review | Before merging each story phase (the "Review" tasks in `tasks.md`) and before release | The `/code-review` skill, run by a reviewer other than the author of the change. Behavior-changing work is reviewed for correctness, reversibility and compliance with constitution principles I to VIII. | A section below per review |
| Security review | Once before release (T072), and a first pass at the end of the safe-and-private story (T051) | The `/security-review` skill plus the `security-oss-app-reviewer` skill (static-first review of egress, credentials, filesystem reach, dependencies and CI risk), covering permissions, private interfaces, network, file access including cleanup, the `swift-argument-parser` dependency, and the build | A section below |
| Automated gates | On every `swift test`, and in CI once T006 lands | Privacy source scan, linked-libraries check, hygiene scan of tracked files, original-file checksums, cleanup safety tests, and Periphery unused-code detection (T007, run by `scripts/periphery.sh`) | Test results |
| Workflow review | Before the CI workflow (T006) is merged | Independent security review of `.github/workflows/ci.yml` and `.github/dependabot.yml`: permissions, secrets, pinned actions | A section below |
| CodeQL (local) | Before release (T072) and whenever the maintainer wants a deeper scan | The CodeQL CLI installed with Homebrew plus a checkout of the CodeQL query repository, pinned to a release tag and found through `CODEQL_REPO`; run by `scripts/codeql-local.sh` (T071), which builds a database from `swift build` and runs the Swift security queries; the script never downloads anything | CodeQL and query-repo versions plus findings, in a section below; raw results stay in the untracked `.codeql/` folder |
| CodeQL (CI) | Optional, later | Could join the CI workflow if runner availability and build time allow; decide when T006 is reviewed | Decision recorded here |

Findings are resolved, or explicitly accepted by the maintainer with the reason recorded
here, before the work is merged or released.

## Reviews

### 2026-10-01: code review of Phases 1 to 7 (author's pass with the `/code-review` skill, high effort)

**Independence caveat:** this pass was run by the same agent that wrote the code, so it does not
yet satisfy the constitution's "independent review". An independent review (a different reviewer, or
`/code-review ultra`, which the maintainer triggers) is still required before merge and release.

Scope: `Sources/`, `Tests/`, `scripts/` at commit `bc48d4e`. Findings and outcomes:

| # | Severity | Finding | Outcome |
|---|---|---|---|
| 1 | high | `Store.transaction` used `withExtendedLifetime(lock) {}`, which does not hold the lock for the body | Fixed with `defer { withExtendedLifetime(lock) {} }`. The concurrency test passed in release builds even before the fix, so the failure was not reproduced; the change follows the correct pattern |
| 2 | medium | A `<uuid>.dnm.<ext>` file unknown to the store (another build's stamp, lost manifest) could be recorded as an original, stacking labels and risking deletion | Fixed: `set` refuses it; test added |
| 3 | low | Set, remove and undo decide from a manifest read outside the lock, and rollback restores a whole snapshot | Accepted for now: the window is small with one CLI user. Revisit when the app shares the store (spec 002) |
| 4 | low | Reporting commands failed on a read-only store because cleanup always wrote | Fixed: cleanup reads first and writes only when something is due; test added |
| 5 | low | The privacy scan's comment stripping could hide forbidden APIs after a URL string | Fixed: string literals are blanked first; test added |

Other results: `swift test` 124 tests pass; `scripts/periphery.sh` reports no unused code.


## Measurements

_Timing (T069), live-run results on macOS 26 and 27 (T070) and the image-quality check are
recorded here._
