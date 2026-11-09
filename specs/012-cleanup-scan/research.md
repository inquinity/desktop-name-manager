# Research: `dnm cleanup --scan` (Feature F9)

Carries over spec 009 research R7 and settles what it left open.

## R1. Walking every Desktop of a display

- **Decision**: a new `DesktopNavigator.walk(on:reading:)` beside `visit(desktop:on:_:)`: point at the display, step
  left until nothing moves (that count gives the starting position), read, then step right reading at each Desktop
  until nothing moves (the last Desktop), then step back to the starting position and restore the pointer. It shares
  `visit`'s guards: the permission check, `nothingMoved` when a display with one Desktop cannot be told from shortcuts
  that are off (a step right and back, as `visit` does for Desktop 1), the announced-changes count (more changes than
  steps means someone else switched: stop, do not switch back), `maximumSteps`.
- **One Desktop or shortcuts off** (spec FR-017): when no step moves on a display, the walk cannot tell the two
  apart. A wrong "one Desktop" would read only the current Desktop and offer labels in use for deletion. So the walk
  reports "nothing moved" (with that display's one read, made before any step) instead of throwing, and the scan
  decides after every display has been walked: if any step in the run was confirmed, the shortcuts are on and each
  such display has one Desktop (its read stands); if none was, the scan throws `nothingMoved` and deletes nothing.
  Deciding at the end means the order of displays does not matter (a main display with one Desktop beside a second
  display with several is scanned).
- **Rationale**: the same public interfaces and the same failure handling as `--desktop`, which is proven live;
  one walk costs about (start − 1) + (N − 1) + (N − start) steps, at most 2N, about a second each
  (`docs/research/timings.md`).
- **Alternatives considered**: calling `visit(desktop:)` for 1, 2, 3, … (about N² steps, and each call finds Desktop
  1 again); reading the private wallpaper store `Index.plist` (forbidden in the product).

## R2. Reading a Desktop's wallpaper after a step

- **Decision**: after each confirmed step, read `currentWallpaper(on:)` for the display; read again about 100 ms
  later while pumping the application's events, and accept the value once two reads agree, bounded by the step
  confirmation timeout (1.5 s). A display with one Desktop is read once, without stepping.
- **Rationale**: `docs/research/findings.md` found that `desktopImageURL(for:)` follows Space switches immediately
  in a long-running process (the scan is one, pumping events). The second read is a cheap guard against a missed
  update, which would report a label in use as unseen (the worst error here). Live-checked by SC-001.
- **Alternatives considered**: a fixed pause per Desktop (slower, still a guess); trusting the first read (no guard).

## R3. "Displays have separate Spaces" off

- **Decision**: read `NSScreen.screensHaveSeparateSpaces` (public; as `Configuration.current()` does, after creating
  the application). When it is on, walk each display in turn, reading only that display. When it is off, all displays
  switch together: walk once, pointed at the main display, and at each Desktop read every connected display.
- **Rationale**: with the setting off a step moves every display, so walking each display would repeat the same
  walk; reading all displays at each stop covers them in one pass. Checked live in the configuration the maintainer
  can set (spec SC-001); the walk's count logic is the same in both cases.
- **Alternatives considered**: refusing the scan when the setting is off (needless); walking each display anyway
  (correct but N times slower, and the announced-changes count would see the other displays' moves).

## R4. Ctrl-C (spec FR-015)

- **Decision**: while the walk runs, install a `SIGINT` handler with `sigaction` that only sets an atomic flag the
  first time; the walk checks the flag before each step and, when set, stops stepping forward, steps back to the
  starting position, restores the pointer, and throws an interrupt error that the command reports (displays already
  scanned, nothing deleted) with exit 130. A second `SIGINT` while the flag is set writes one line with `write(2)`
  ("Stopped; <display> may be on another Desktop.") and calls `_exit(130)`. The previous handler is restored when the
  walk ends, so the questions before and after it keep the default Ctrl-C behavior.
- **Rationale**: only async-signal-safe work in the handler; the walk is a loop on the main thread that already
  pauses between steps, so polling a flag there is simple and testable (the fake switcher can raise the flag at a
  given step).
- **Alternatives considered**: a dispatch signal source on the main queue (delivered only while the run loop turns,
  which the pump does, but harder to test and to order with the walk); leaving Ctrl-C as `--desktop` has it (rejected
  in clarification).

## R5. Choosing the candidates and deleting

- **Decision**: a `ScanResult` (per scanned display, the image file names seen; the displays not connected with
  their label counts). The candidates are the stamps whose `displayUUID` is a connected display and whose file name
  was not seen on any display (an image seen on another display, impossible in practice, still counts as seen). A
  missing image file is a candidate with size 0. Deletion reuses `carryOut`'s shape: one exclusive store change that
  re-reads the manifest, re-checks against the images showing on current Desktops now, marks seen everything the
  scan saw (FR-006), removes the candidate records, clears `maintenance` (the nudge), then deletes the files.
- **Seen without deleting**: when the person declines the second question (or there is nothing to delete), a small
  locked change still marks seen what the scan saw (FR-006).
- **Rationale**: one place for the selection rule, tested with the fake system; the existing `CleanupPlan` and
  `CleanupCandidate` gain a reason `.notOnAnyDesktop` so the report, the JSON and the deletion are shared with the
  age-based cleanup.
- **Alternatives considered**: a separate deletion path for the scan (duplicates the locked change and its tests).

## R6. Command-line surface

- **Decision**: `--scan` is a flag on `cleanup`. `--days` with `--scan` is refused in `validate()` (exit 2,
  "--scan looks at every Desktop, so --days does not apply."); because `--days` has a default, the option becomes
  optional (`Int?`, default applied when absent) so an explicit `--days 30` is also refused. Display words and
  `--desktop` stay unknown to `cleanup` (the parser's usage error, exit 2).
- **Order**: refuse options → Accessibility check (no output before it, FR-001) → describe → ask (or `--yes`; no
  terminal or `--json` without `--yes`: describe and exit 0) → walk with one `Scanning <display>…` line per display
  on a terminal (FR-016, written with `Output.err`: a progress message, not a warning or note, so spec 011's gate
  does not apply) → report → ask again → delete.
- **Estimate in the description**: Desktops cannot be counted beforehand, so it says "about 2 seconds per Desktop on
  each display" and names the displays.

## R7. Quiet mode and the nudge

- The description, questions, progress lines and results are not warnings or notes; quiet mode (spec 011) leaves
  them. The nudge text MAY mention `--scan` (spec 009 FR-008); decided: leave it unchanged in this feature, to keep
  spec 011's nudge tests stable.

## R8. Version

0.3.0 with F7, which is built and merged first and moves `Version.xcconfig` to 0.3.0 (spec 011 T001).
