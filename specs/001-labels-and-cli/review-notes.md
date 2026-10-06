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


### 2026-10-01: independent code review (cloud `/code-review ultra`, review 1 of 3)

An independent reviewer (the cloud multi-agent review) read the whole branch as of `main` when it was
launched (94 files). It satisfies the constitution's "independent review" for the code up to that
point; later changes (the fixes below and the security-pass fixes) were reviewed only by the author.

| # | Severity | Finding | Outcome |
|---|---|---|---|
| 1 | normal | A display whose CoreGraphics UUID lookup fails got the empty string as its identity, so several such displays would share one identity | Fixed: fall back to the vendor, model, serial and display numbers. Not unit-testable (the lookup cannot be made to fail in tests); covered by review |
| 2 | normal | Rollback after a failed wallpaper set overwrote the whole shared manifest with a stale snapshot, discarding a concurrent run's commit | Fixed together with 3: the whole operation now runs under the store lock |
| 3 | normal | Set, remove and undo decided from a manifest read before taking the lock, so two runs on one display could both retire the same stamp and leave two active stamps and a lost change record (this repeats finding 3 of the author's pass, which had been accepted) | Fixed: `Store.exclusive` holds the lock for read, decide, write and the wallpaper set; it is re-entrant on a thread. Remove and undo skip the lock when nothing is stored. Tests: a second run waits for the lock; two concurrent replacements leave one active stamp |
| 4 | nit | `print_colored` passed the message as a printf format string, so a `%` in a path or argument was mangled (in four scripts) | Fixed: `printf '%b%s%b\n'` |
| 5 | nit | The color helper block is copied into four scripts instead of being sourced from one file | Not changed: the maintainer's shell-script convention is self-contained scripts with this block, and the helper is now a single trivial line |

The earlier "accepted" decision on concurrency is withdrawn: it was wrong to defer once two reviewers
rated it a real defect.

### 2026-10-01: first security pass (author's static pass, `security-oss-app-reviewer` method)

**Independence caveat:** run by the agent that wrote the code, so it is a first pass, not the independent
security review required before release (T072). Static only; nothing was executed except the tool
against scratch folders to confirm finding 1. Scope: `Sources/`, `Tests/`, `scripts/`, `.github/`,
`Package.swift`, `Package.resolved`.

**Findings**

| # | Severity | Finding (evidence) | Outcome |
|---|---|---|---|
| 1 | medium | A stamp's `fileName` in `manifest.json` was trusted. A manifest edited by another process of the same user could carry `../x`, and cleanup would delete that file outside the store (confirmed in a scratch folder: a file one level above the store was deleted by `dnm displays`). `Store.removeFile` and `fileURL` joined the name unchecked | Fixed: manifests whose stamp names are not exactly `<uuid>.dnm.<ext>` are refused and left alone; `removeFile`, `stampFileExists` and `writeStampFile` reject any other name. Tests added; the scratch demonstration now exits 1 and the file survives |
| 2 | low | The store directory and files were created with default permissions (0755 and 0644) and hold label text, original paths and copies of the wallpaper. The default location is under `~/Library` (0700), but `DNM_STORE_DIR` can point anywhere | Fixed: directory 0700, manifest and stamps 0600; test added |
| 3 | low | The lock file was opened following symlinks, so a planted symlink in a shared `DNM_STORE_DIR` could make the tool open an unintended file | Fixed with `O_NOFOLLOW`; test added |
| 4 | low | `Tests/live/live-label.sh` pasted the `--dnm` path into `bash -c` strings and deleted a stamp path read from the manifest | Fixed: checks are functions, and the deletion is limited to the private store |
| 5 | low | CI (`.github/workflows/ci.yml`) runs pull-request code (`swift build` and `swift test`) on a GitHub runner. The workflow has read-only permissions, no secrets and no third-party actions, so the exposure is limited to the runner | Recommendation for the maintainer: in the repository settings require approval before workflows run for first-time contributors. Open until T006 is reviewed and approved |
| 6 | info | `scripts/live-*.sh` leave the `Index.plist` backup in the temp folder (by design, for restore); it lists wallpaper paths | Documented; remove it yourself after a successful run |

**Access map (reviewed evidence)**

| Area | Observed | Notes |
|---|---|---|
| Network egress | None in `Sources/`; the only URL is the repository fetch in CI | Enforced by `PrivacyScanTests` and `LinkedLibrariesTests` (no networking framework linked) |
| Telemetry | None | Same tests |
| Credentials | None read, stored or forwarded | The only environment variable read is `DNM_STORE_DIR` |
| Subprocesses | None in `Sources/` | Scripts call `sandbox-exec`, `plutil`, `shasum`, `git`, `codeql`, `python3` with fixed arguments |
| Filesystem | Reads the wallpaper image the system reports and its recorded original; writes only inside the store; deletes only `<uuid>.dnm.<ext>` files named by a validated manifest or found in a folder that has our manifest | A denied read is reported, never worked around |
| Private APIs | None | `PrivacyScanTests`, `LinkedLibrariesTests` |
| Dependencies | `swift-argument-parser` exactly 1.8.2, revision pinned in the tracked `Package.resolved`; fetched over HTTPS at build time only | Release review should re-check the revision |
| CI | Read-only token, no secrets, no third-party actions, no signing | Runner label `macos-26` unverified |

**Not reviewed:** runtime behavior on the real wallpaper (live checks), the CodeQL scan (query tag not
pinned yet), the built release binary's signature (spec 005), and macOS-level behavior of
`NSWorkspace.setDesktopImageURL`.

### 2026-10-05: code and security review of Phase 10 (author's pass, high effort)

**Independence caveat:** run by the agent that wrote the code, so T091 still needs an independent review
(`/code-review ultra`, triggered by the maintainer). Scope: commits `a726d4b` to the T091 commit:
shared images, `prune`, `DesktopNavigator` and `SystemDesktopSwitcher`, `--desktop`, `about`, `check`.

| # | Severity | Finding | Outcome |
|---|---|---|---|
| 1 | medium | FR-027 requires stopping when the person switches Desktops during the command; the navigator counted only its own confirmed steps, so an extra switch would shift the target and label the wrong Desktop | Fixed: the switcher exposes macOS's count of announced Desktop changes; the navigator stops before labeling when it exceeds the steps taken, and reports when a change arrives while labeling. It cannot know its position then, so it does not switch back; FR-027 and the contract were corrected to say so. Tests added |
| 2 | low | `dnm check` reported "Displays share one set of Spaces" on a Mac with separate Spaces: `NSScreen.screensHaveSeparateSpaces` reads false until the process has an `NSApplication` | Fixed before commit: `Configuration.current()` creates the shared application first |
| 3 | low | `SetLabelResult.warnings` stayed after T079 removed the only warning | Removed |
| 4 | low | With the shortcuts remapped or off, the Control-Left/Right presses reach the frontmost app (for example a terminal moves a word) | Accepted: one press each way before the tool stops with the "shortcuts are off" message; documented in the README |
| 5 | info | A failure inside the operation hides a failure to switch back (`try?`) | Accepted: the operation's error is the one to show; the next command still acts correctly |

Security notes (static): the only events posted are Control-Left/Right key presses at the HID tap and pointer
moves, which are restored; Accessibility is checked with `AXIsProcessTrusted` and never prompted; no private
interfaces (the privacy scan passes); `check` reads only and creates nothing; `about` prints the data
directory with the home folder as `~`. Results: 196 tests pass (177 core, 18 CLI, 1 snapshot); Periphery
reports no unused code.

## Measurements

### Live run, 2026-10-03, macOS 27.0.1 (this Mac), main display, `Tests/live/live-label.sh`

The first runs on 2026-10-01 and 2026-10-02 found two problems, both fixed before the passing run:
(1) macOS reports a newly set wallpaper a moment late, so `remove`, `undo` and a second `set` run
straight after `set` misjudged the Desktop (fixed by waiting for the system to report the file; tests
reproduce each symptom); (2) the script did not say which display it labels, so a first "no" was the
person watching another screen (the script now names the display).

Passing run: scenarios 1, 2, 3, 5, 6, 7, 8, 9, 10, 11 and 19 passed, and the wallpaper was restored.
Gaps: scenario 4 (restart, reorder, Show Desktop; needs a log out), 16 (30-minute cleanup;
`--with-cooldown`), 17 (solid color) and 18 (image quality) were not run; macOS 26 was not available.
In scenario 3 the large label was on screen too briefly to judge; the script now pauses on it, so
scenario 3 should be re-run. The automatic style on the dark leafy test wallpaper was "halo", which
looks like plain text on a dark picture (the glow is invisible there); a possible refinement is to prefer
"plain" when the glow could not show. Not changed yet.

Follow-up by hand on 2026-10-03 (same Mac): the large label was shown and compared with the medium one
(`dnm set "Mail" --size large`, then `dnm remove`), result: pass, so scenario 3's size check is covered.
The sequence `dnm set "Mail" --size large && dnm remove`, which failed before the wait for macOS to
report the wallpaper, now labels and removes cleanly on the real system.

### Timing (T069), 2026-10-05, macOS 27.0.1, Apple M5 Pro, release build, SC-001 and FR-019

`dnm set "Timing"` then `dnm remove`, wall-clock time including the wait for macOS to report the change:

| Display | Pixels | `set` | `remove` |
|---|---|---|---|
| Built-in Liquid Retina XDR (main), 3 runs | 3456 x 2234 | 0.35, 0.32, 0.33 s | 0.20, 0.19, 0.25 s |
| External DP, 1 run | 5120 x 2880 (5K) | 0.40 s | 0.22 s |

The budget is under one second on a 5K display on an Apple-silicon Mac; it is met with wide margin. The
automatic style on this wallpaper is now "plain" (the dark-backdrop rule: a halo could not show).

### Live run, 2026-10-06, macOS 26.7.1 (25G241), Apple silicon, three displays, `dnm 0.1.0-dev+90fc96f`

Run by the maintainer with the live-test kit (`Tests/live/live-label.sh`), log reviewed. Scenarios 1, 2, 3
(both sizes), 5 (original byte-identical and placement back), 6 (undo, and a second undo has nothing to undo),
7, 8, 9, 10, 11 and 19 passed; the wallpaper was restored at the end. The safety script was reported as passed
by the maintainer (log not reviewed).

Observation: every label in this run was on the main display's first Desktop, and each time the (since
superseded) store check warned that macOS also made it the default for new Desktops. That matches the macOS
behavior found on 27 (`docs/research/desktop-association.md`): the first Desktop provides the default on
macOS 26 as well. The warning's advice ("Show on all Spaces") is wrong and the check is removed in T079.

### Live run, 2026-10-06, macOS 26.7 (25G229), **Intel (x86_64)**, one display, `dnm 0.1.0-dev+90fc96f`

Run by the maintainer on a 2019 Intel MacBook Pro with the universal live-test kit, log reviewed. Scenarios
1, 2, 3 (both sizes), 5 (original byte-identical and placement back), 6, 7, 8, 9, 10, 11 and 19 passed, and
the wallpaper was restored. The automatic style chose dark text on this wallpaper, and halo for the large
label, so a second style path was exercised live. This is the first evidence that the Intel build works;
Intel support is still decided at packaging (spec 005).

### Live run, 2026-10-06, macOS 27.0.1, Apple silicon, three displays, `Tests/live/live-desktops.sh`, `dnm 0.1.0-dev+ed72078`

Earlier label names (LABEL1, LABEL2, First). Log kept locally (`working-notes/`).

- Pre-check: all three displays reached Desktop 3 read-only. An earlier attempt correctly stopped
  ("Built-in Retina Display has 2 Desktops; there is no Desktop 3") after macOS moved Desktops between
  displays when the monitors changed.
- Scenario 21: all six `set --desktop` commands succeeded and `show --desktop` found every label. Times
  3.4 to 6.9 s, except **9.3 s** for main Desktop 3 (over the 8 s of SC-008). Two LOOK checks were answered
  "no" (each display back where it started; labels on the right Desktops) without a description; the
  script now asks what was seen.
- Scenario 22: the Desktop 1 note was printed. The run then stopped at the new-Desktop number prompt (a
  non-number was typed); the prompt now asks again. Scenario 23 did not run.
- Found afterwards: known issue KI-2 (`prune --yes` earlier deleted images still used by Desktops of the
  two-monitor arrangement).

Script changes since: labels name their place ("Display N - Desktop M"), a display legend, every display
covered, a read-only Desktop 3 pre-check, the number prompt re-asks, and failed LOOKs record what was seen.

### Still to record

The full quickstart (T070): scenarios 4, 16, 17 and 18 on both versions, and 20 to 23 after Phase 10.
The independent review of Phase 10 (T091).


