# Desktop Name Manager: notes for coding agents

A macOS app and CLI (`dnm`) that labels each Desktop (Space) by stamping the label into a
copy of that Desktop's wallpaper and setting it with `NSWorkspace.setDesktopImageURL`.

## Workflow

This project uses Spec Kit (`.specify/`, `/speckit-*` skills). Work from the written
artifacts in `specs/` and `.specify/memory/constitution.md`, not from chat history. Local,
untracked notes may exist in `working-notes/`; if `working-notes/HANDOFF.md` exists, read
it first.

## Rules

- **Public repository.** Never commit personal paths, user names, display or Space
  UUIDs, keychain profile names, or personal images.
- **Local material stays local.** `wallpaper-samples/` and `working-notes/` are excluded
  in `.git/info/exclude` and must stay untracked. Never run `git clean -x` or `-X`: it
  would delete them.
- **Nothing may require disabling SIP.**
  - Labeling must need no macOS permissions.
  - Any Accessibility use must be explicit and opt-in.
  - Private macOS interfaces must be read-only and optional.
- **No network access and no telemetry** in the app or CLI.
- **Protect the user's wallpaper during live tests.** Tests change the real wallpaper:
  back up `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` first,
  and restore the original afterwards.
- **No Spec Kit extensions without a review.** Some install Claude Code hooks. After any
  `specify` command, check `git status` for `.claude/settings.json`.
- **Keep two skills manual.** Leave `disable-model-invocation: true` on
  `speckit-implement` and `speckit-taskstoissues`.
