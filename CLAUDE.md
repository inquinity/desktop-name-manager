# Desktop Name Manager: notes for coding agents

A macOS app and CLI (`dnm`) that labels each Desktop (Space) by stamping the label into a copy of that Desktop's wallpaper and setting it with `NSWorkspace.setDesktopImageURL`.

## Workflow

This project uses Spec Kit (`.specify/`, `/speckit-*` skills). Work from the written artifacts in `specs/` and `.specify/memory/constitution.md`, not from chat history. Local,
untracked notes may exist in `working-notes/`; if `working-notes/HANDOFF.md` exists, read it first.

## Rules

- **Public repository.** Never commit personal paths, user names, display or Space   UUIDs, keychain profile names, or personal images.
- **Local material stays local.** `wallpaper-samples/` and `working-notes/` are excluded in `.git/info/exclude` and must stay untracked. Never run `git clean -x` or `-X`: it
  would delete them.
- **Nothing may require disabling SIP.**
  - Labeling must need no macOS permissions.
  - Any Accessibility use must be explicit and opt-in.
  - No private macOS interfaces in the product (no SkyLight calls, no undocumented system files or preferences, not even read-only); the App Store is a goal. Research tools in `prototype/` may use them and are never shipped.
- **No network access and no telemetry** in the app or CLI.
- **Protect the user's wallpaper during live tests.** Tests change the real wallpaper:
  - back up `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` first,
  - Restore wallpapers using `dnm remove` afterwards; restore `Index.plist` only if necessary.
- **No Spec Kit extensions without a review.** Some install Claude Code hooks. After any `specify` command, check `git status` for `.claude/settings.json`.
- **Keep two skills manual.** Leave `disable-model-invocation: true` on `speckit-implement` and `speckit-taskstoissues`.

## Build and test

- Build and test with `just build`, `just test` and `just build-release` (Swift 6.4, macOS 26 or later). They pass `--scratch-path build.noindex`, so build output goes to `build.noindex/` and not SwiftPM's `.build/`; keep it that way (plain `swift build` creates `.build/`, which is only git-ignored). Unit and contract tests use a fake wallpaper system and a temporary store; they never change the real wallpaper.
- The version and build number live in `Version.xcconfig` (as in the sibling project; `just version`).  Builds made with `just` are stamped with them and the commit (`scripts/build-stamp.sh`), so `dnm --version` prints `0.1.0 (1) <commit>[+]`; only a release build (spec 005, `just release` then `just publish`) prints `0.1.0 (1)`. Quote `dnm --version` when reporting what you tested.
- `just periphery` (`scripts/periphery.sh`) runs the unused-code gate (it must stay clean).
- Set `DNM_STORE_DIR` to a throwaway directory for any live run so real labels are untouched, and follow the backup and restore rules in the live-test bullet above.
- Local-only render checks run over `wallpaper-samples/` when it exists (`just test --filter LegibilitySweep`).
