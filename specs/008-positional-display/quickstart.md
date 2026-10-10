# Quickstart & Verification: Display as a Positional Argument (Feature F8)

Use a private store: `export DNM_STORE_DIR="$(mktemp -d)/s"`. Commands that change a wallpaper follow the
project's live-test rules: back up `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` first
and restore it afterwards.

## Read-only scenarios (no wallpaper changes)

1. `dnm show` and `dnm show main --json` agree; `dnm show "<a display name>"` and `dnm show --display "<same>"`
   print the same.
2. `dnm alias lg "<a display name>"`, then `dnm show lg` names that display.
3. Each of these exits 2 with nothing changed and a message that says what to type:
   - `dnm show main main` (too many words) and `dnm show main --display main` (display given twice);
   - `dnm show --display main --display "<a display name>"` (display given twice, as `--display` repeated);
   - `dnm set a b c` (too many words; the message mentions quoting and aliases);
   - `dnm set Nonexistent Inbox` (no display matches; the hint says to quote the label);
   - `dnm set main` and `dnm set lg` (a lone word that is a display; both forms are shown, quoted if the name has spaces);
   - `dnm set "x" --label "y"` and `dnm set --label "a" --label "b"` (label given twice).
4. `dnm set 2` is not refused (a number is a label); `dnm set 2 "x"` fails as before (numbered displays).

## Live scenarios (change the wallpaper; back up and restore)

5. `dnm set "<a display name>" "Hello world"` labels that display; `dnm remove "<same>"` restores it; `dnm undo "<same>"`
   brings the label back; `dnm set main "Main label"`; `dnm remove main`.
6. `dnm set lg "Via alias"` with the alias from 2; `dnm remove lg`.
7. `dnm set "Plain label"` still labels the main display; `dnm set --display "<name>" "Old syntax"` still works.
8. Fully named: `dnm set --label main` labels the main display "main"; `dnm set "<name>" --label "Named"` labels that display.
9. With `--desktop`: `dnm set "<name>" "On two" --desktop 2` (needs Accessibility; announce live control).

## Completion

10. In zsh and bash, `dnm set <Tab>`, `dnm show <Tab>` and `dnm remove <Tab>` offer `main`, the displays and the
    aliases; `dnm set DP <Tab>` and `dnm set x --label <Tab>` offer nothing; `dnm set x --style <Tab>` still
    offers the styles.
