# Review Notes: Desktop Labels and the `dnm` Command-Line Tool

Records of the reviews required by the constitution (principle VII and Development
Workflow). Findings, decisions and acceptances go here. Never put personal paths, user
names, display or Space identifiers, or keychain profile names in this file.

## Review modes (agreed 2026-09-30)

| Mode | When | How | Output |
|---|---|---|---|
| Code review | Before merging each story phase (the "Review" tasks in `tasks.md`) and before release | The `/code-review` skill, run by a reviewer other than the author of the change. Behavior-changing work is reviewed for correctness, reversibility and compliance with constitution principles I to VIII. | A section below per review |
| Security review | Once before release (T071), and a first pass at the end of the safe-and-private story (T050) | The `/security-review` skill plus the `security-oss-app-reviewer` skill (static-first review of egress, credentials, filesystem reach, dependencies and CI risk), covering permissions, private interfaces, network, file access including cleanup, the `swift-argument-parser` dependency, and the build | A section below |
| Automated gates | On every `swift test`, and in CI once T006 lands | Privacy source scan, linked-libraries check, hygiene scan of tracked files, original-file checksums, cleanup safety tests | Test results |
| Workflow review | Before the CI workflow (T006) is merged | Independent security review of `.github/workflows/ci.yml` and `.github/dependabot.yml`: permissions, secrets, pinned actions | A section below |
| CodeQL (local) | Before release (T071) and whenever the maintainer wants a deeper scan | The CodeQL CLI installed with Homebrew plus a checkout of the CodeQL query repository, pinned to a release tag and found through `CODEQL_REPO`; run by `scripts/codeql-local.sh` (T070), which builds a database from `swift build` and runs the Swift security queries; the script never downloads anything | CodeQL and query-repo versions plus findings, in a section below; raw results stay in the untracked `.codeql/` folder |
| CodeQL (CI) | Optional, later | Could join the CI workflow if runner availability and build time allow; decide when T006 is reviewed | Decision recorded here |

Findings are resolved, or explicitly accepted by the maintainer with the reason recorded
here, before the work is merged or released.

## Reviews

_None yet._

## Measurements

_Timing (T068), live-run results on macOS 26 and 27 (T069) and the image-quality check are
recorded here._
