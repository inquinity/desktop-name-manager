# Quickstart: Quiet Mode (Feature F7)

Validation for [spec.md](spec.md) against [contracts/cli.md](contracts/cli.md).

## Automated

```bash
just build
just test
just periphery
```

Expected: all pass, including `QuietModeTests`, `NudgeDecisionTests` (quiet: no line, store not asked),
`CompletionTests` (`-q` and `--quiet` in both scripts) and the binary tests that compare output with and without
quiet mode. Periphery stays clean.

## By hand (no wallpaper change)

Use a throwaway store for every command: `export DNM_STORE_DIR="$(mktemp -d)"`. `<name>` below is the main
display's name as `dnm displays` shows it (not recorded anywhere).

`dnm alias` refuses a name a connected display already has, so an overridden alias only arises when that display
connects later. To get one without a second monitor, seed the throwaway store with an alias of that name bound to a
made-up display (loading does not re-check names):

```bash
printf '{"schemaVersion":3,"stamps":[],"changes":[],"aliases":[{"name":"%s","displayUUID":"00000000-0000-0000-0000-000000000000","displayName":"Elsewhere"}]}' '<name>' >"$DNM_STORE_DIR/manifest.json"
```

| # | Scenario | Command | Expected |
|---|---|---|---|
| 1 | Overridden alias warns | `dnm show '<name>'` | the result on standard output; one `dnm: warning:` line on standard error |
| 2 | Quiet after the command | `dnm show '<name>' -q` | the same standard output; nothing on standard error; exit 0 |
| 3 | Quiet before the command | `dnm -q show '<name>'` | as 2 |
| 4 | Environment | `DNM_QUIET=1 dnm show '<name>'` | as 2; `DNM_QUIET=0 dnm show '<name>'` warns as 1 |
| 5 | Alias list | `dnm alias -q` | the `(overridden by connected display …)` marker in the list; no warning line |
| 6 | Errors stay | `dnm show NOPE -q` | `dnm: No display matches "NOPE" ...`; exit 2 |
| 7 | Usage errors stay | `dnm -q set` | the usage error and `Run \`dnm --help\` for usage.`; exit 2 |
| 8 | JSON unchanged | `dnm show '<name>' --json -q` | the same JSON document as without `-q`; nothing on standard error |
| 9 | Help | `dnm --help`, `dnm set --help` | both list `-q, --quiet` with the contract's text |
| 10 | Completion (bash and zsh, completions installed) | type `dnm -q se` and Tab; `dnm set --q` and Tab | `set`; `--quiet` |

Afterwards: remove the throwaway store.

## Live (changes the wallpaper)

Follow the live-test rules in `CLAUDE.md`: back up `Index.plist`, use a throwaway `DNM_STORE_DIR`, and remove the
labels with `dnm remove` afterwards. `Tests/live/live-syntax.sh` runs scenarios 1 to 8 for `set`, `remove` and
`undo` with the overridden alias: the label is applied and removed as without quiet mode, and standard error is
empty in quiet mode.

The nudge (SC-005) is covered by the unit tests; a live check needs a hand-aged store, as in spec 009's quickstart
scenario 6, and is optional.
