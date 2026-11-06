# Research: Several Displays in One Command (spec 010)

**Date**: 2026-11-06 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

No dependency, interface or permission changes. Each item below is a design question the spec leaves to the plan.

## R1. Where several displays are read

- **Decision:** `DisplayArguments` (spec 008 FR-005) gains `targets(command:words:displayFlags:in:aliases:)` for
  `remove` and `undo` (any number of display words), and `setRequest` returns the ordered displays instead of one.
  `target(...)` stays for `show` (at most one display, refusing two different ones with the existing message). The
  private `resolve` keeps its rules (every value resolved, an empty display refused, the word's hint, notices
  collected once) and returns every distinct display in order, the first naming of each kept.
- **Why:** the reading stays in one function in the core library, so the commands still do no matching (spec 008
  SC-003, the `CommandsStayThinTests` tripwire) and every display is resolved before anything changes (FR-003).
- **Considered:** resolving in the commands (breaks the tripwire); a separate multi-display parser (two readings
  of the same words that could drift).

## R2. Display words for `remove` and `undo`

- **Decision:** `DisplayWords` keeps `first` and turns `extra` into a visible, completed `[String]` argument
  (`[<display> ...]`), so every word offers displays and aliases on Tab (FR-012). Custom usage lines:
  `dnm remove [<display> ...] [options]`, `dnm undo [<display> ...] [options]`. `show` keeps its own one-word
  usage and its "at most one display" error, so `ShowCommand` gets its own words type (or keeps `extra` private).
- **Why:** the spec's clarification (2026-11-06). The parser already reads an array after an optional argument
  (spec 008 spike); only its help and completion change.
- **Considered:** one array argument (`[String]`) for all words: equivalent for parsing, but the first word's help
  text ("Default: main") reads better on its own.
- **As built:** `DisplayWords` is the one array (`words: [String]`), with "Several may be named. Default: main." in
  its help; it completes every word through one callback. `show` has its own `ShowWords` (one word plus a private
  `extra`), so its help, its completion and its "at most one display" message are unchanged.

## R3. Running the change display by display

- **Decision:** a small core helper, `DisplayBatch.run(_:each:)`, takes the resolved displays and a closure that
  changes one display and prints its line. It records each display that succeeded; on an error it rethrows the same
  `DnmError` case (so the exit status is the error's own, FR-006) with the message extended when at least one display
  was already changed:
  `<error> Changed before this: <names>. To put them back within 60 seconds: dnm undo <quoted names>.`
  The display that failed is named in the error (every display error already names its display; where one does
  not, for example "macOS denied access", the helper prefixes `On <name>: `). When the first display fails, the
  error is passed through unchanged (User Story 4, scenario 2; FR-009 for one display).
- **Why:** keeps the partial-failure rule, its wording and the quoting of the suggested command (`ShellQuoting`) in
  one tested place; the commands stay a loop over lines they already print. Lines are printed as each display
  succeeds, so the output before the error is the record of what changed.
- **The undo command it suggests** names the changed displays by the words the person used where those resolve to
  them, else by display name, quoted for a POSIX shell (spec 008 FR-007's function).
- **Considered:** rolling back (rejected by the maintainer, 2026-11-06); continuing after a failure (same).
- **As built:**
  - `DisplayBatch.run(_:undoArguments:_:)`. The extended error is a new case, `DnmError.partWay(message, exitCode:)`,
    which carries the stopping error's exit status: several cases wrap their message in fixed text, so the same case
    cannot carry a longer message. A failure on the first display still throws the original error unchanged.
  - "Nothing was changed." in the stopping error becomes "Nothing was changed on <display>.", since other displays
    were changed (likewise "Nothing was labeled.").
  - The closure returns whether it changed the display: `remove` on a display without a label is not named as
    changed.
  - The suggested `dnm undo` uses the word that first named each display (`Targets.references`, `main` when none was
    named), written `--display=` when it starts with a dash, and adds `--desktop N` when it was given. `undo` itself
    suggests no command (an undo cannot be undone; spec 001 FR-022 keeps one level), and only names the displays.

## R4. Checks before anything changes, and `--desktop`

- **Without `--desktop`** everything FR-003 lists can be checked first: the label and options (already validated
  before displays are resolved), every display resolved, and for `undo` a read-only check per display. `UndoLabel`
  already makes all its checks (a record for the display, within the window, the current wallpaper is the one the
  change produced, the files it needs exist) before changing anything; they move into
  `DesktopLabeler.checkUndo(on:)`, which `undoLastChange` calls first and the command calls for every display before
  the first change.
- **With `--desktop N`** two of the checks need the Desktop to be on screen: public interfaces cannot tell how many
  Desktops a display has, or what a Desktop that is not showing shows, without stepping there with the shortcuts
  (spec 001 research R14), and each step takes about a second (`docs/research/timings.md`: median 1006 ms on the
  built-in display). The display-level checks (resolution, Accessibility, an undo record within its window) still
  run first. For the Desktop-level ones there are two options:
  1. **Recommended: check while changing.** A display without Desktop N, or whose Desktop N no longer shows what
     the change produced, fails when it is reached, and the part-way rule (FR-006) applies. Cost: none. This needs
     an amendment of spec FR-004 and User Story 5, scenario 2 ("checked for every named display first").
  2. **A checking pass first.** Visit Desktop N of every display, check, return; then visit each again to change it.
     Keeps FR-004 as written; doubles the switching (for two displays on Desktop 3 of 4, roughly 6 to 10 seconds more)
     and doubles the window in which the person switching Desktops by hand aborts the command.
- **Decision (maintainer, 2026-11-06): option 1, check while changing.** The spec's FR-004 and User Story 5 are
  amended. With `--desktop`, `undo` checks each display's record and window first (`checkUndo` without the
  current-wallpaper comparison), and the full check runs on Desktop N as part of the change.

## R5. Output and the reminder

- **Decision:** each display prints the line a single command prints (`place.describe` gives "Desktop 2 of ..."
  with `--desktop`), as it succeeds. The override warning for an alias is printed once per name, before any change,
  after the label and options are validated (as today). `Nudge.showIfDue` is called once, after the loop, and only
  when the loop completed; a failure ends the command before it, as a failing single command does today.
- **Why:** FR-007, FR-011; no new output format, so scripts that read one line per display keep working.

## R6. Tests without a real wallpaper

- **Decision:** `FakeWallpaperSystem` gains a per-display failure (`setErrors[uuid]`, keeping the global `setError`)
  so a failure on the second of three displays can be made (SC-002). Tests:
  - `DisplayArgumentsTests`: the table of every invocation in the spec with its ordered displays (SC-001), including
    duplicates by different names, the word's hint, an empty display, `show` refusing two;
  - `DisplayBatchTests`: success in order, a failure on the first (unchanged error), on the second of three (first
    changed, third untouched, message and exit status), quoting of names with spaces;
  - `UndoLabelTests`: `checkUndo` refuses exactly what `undoLastChange` refuses and changes nothing;
  - `dnmTests` contract tests through the binary for the refusals (exit status, nothing created) and in-process
    parse tests for the new word arrays and completion by position.
- **Live:** `Tests/live/live-syntax.sh`'s checks that two displays are refused for `set` become checks that both are
  changed; it gains `set`, `remove` and `undo` on every connected display in one command each, a `show` refusal, and
  restores every wallpaper (SC-004). It runs only with two or more displays and follows the project's backup rules.

## R7. Minimum macOS

- **Decision:** unchanged, macOS 26 (the project minimum). Nothing in this feature uses a newer interface.

## R8. `Context.onDesktop` with several displays (tasks T022)

- **Checked, no change:** `onDesktop` makes a new `SystemDesktopSwitcher` for each call and `DesktopNavigator.visit`
  restores the pointer and returns to the starting Desktop for each display, so a loop over displays needs nothing
  more. The Accessibility check runs on the first display reached, before anything changes (contract §3, item 4).
