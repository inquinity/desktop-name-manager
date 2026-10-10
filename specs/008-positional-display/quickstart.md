# Quickstart & Verification: Display as a Positional Argument (Feature F8)

Use a private store: `export DNM_STORE_DIR="$(mktemp -d)/s"`. Commands that change a wallpaper follow the
project's live-test rules: back up `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` first
and restore it afterwards.

## Read-only scenarios (no wallpaper changes)

1. `dnm show` and `dnm show main --json` agree; `dnm show "<a display name>"` and `dnm show --display "<same>"`
   print the same.
2. `dnm alias lg "<a display name>"`, then `dnm show lg` names that display.
3. Errors, each exit 2 with nothing changed: `dnm show main main` (E5); `dnm show main --display main` (E4);
   `dnm set a b c` (E1); `dnm set Nonexistent Inbox` (E2, with the quoting hint); `dnm set main` and
   `dnm set lg` (E3, naming both forms).
4. `dnm set 2` is not refused (a number is a label); with a display named `2` impossible (digits are rejected).

## Live scenarios (change the wallpaper; back up and restore)

5. `dnm set "<a display name>" "Hello world"` labels that display; `dnm remove "<same>"` restores it; `dnm undo "<same>"`
   brings the label back; `dnm set main "Main label"`; `dnm remove main`.
6. `dnm set lg "Via alias"` with the alias from 2; `dnm remove lg`.
7. `dnm set "Plain label"` still labels the main display; `dnm set --display "<name>" "Old syntax"` still works.
8. With `--desktop`: `dnm set "<name>" "On two" --desktop 2` (needs Accessibility; announce live control).

## Completion

9. In zsh and bash, `dnm set <Tab>`, `dnm show <Tab>` and `dnm remove <Tab>` offer `main`, the displays and the
   aliases; `dnm set DP <Tab>` offers nothing; `dnm set x --style <Tab>` still offers the styles.
