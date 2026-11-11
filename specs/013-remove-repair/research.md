# Research: `remove` repairs a misreported Desktop (Feature F6)

## R1. Confirming KI-3 and that a repeated set repairs it (spec FR-001)

- **Decision**: a live, read-only confirmation before any product change, on the maintainer's Mac:
  1. Reproduce KI-3's steps on one display with a throwaway `DNM_STORE_DIR`, after backing up `Index.plist`.
  2. In that state, take a `prototype/space-observer.swift` snapshot (research tool, may read the private store) and
     note what the new Desktop's entry holds versus what `dnm show` reports.
  3. Run a one-off prototype (not shipped) that calls `setDesktopImageURL` with the URL and options
     `desktopImageURL(for:)` / `desktopImageOptions(for:)` report for the new Desktop, and look at the screen.
  4. If the screen does not change, try once more with the labeled image first and the original second, and note
     whether that works and how it looks (a flash).
  5. Record the outcome in KI-3 and in this file.
- **Rationale**: the backlog says to confirm the cause first; the repair depends on macOS applying a set of the URL it
  already reports, which is not documented either way.
- **Outcomes**:
  - Step 3 works: build FR-002 as specified.
  - Only step 4 works: amend FR-002 to set the labeled image then the original (an extra set, a brief flash), and ask
    the maintainer before building.
  - Neither works: stop (spec Q5).

- **Result (2026-11-11, macOS 27.2, `0.3.0 build 31 (91d4e7e)`)**: step 1 did not reproduce KI-3. The new Desktop
showed the label and macOS reported the labeled image for it; `dnm show` found the label and plain `dnm remove`
restored the original on screen (confirmed by the maintainer). The snapshot (step 2) showed the display's default for
new Desktops reset to the original, and the new Desktop's own entry still the labeled image. Steps 3-4 were not needed
(`prototype/reset-wallpaper.swift` was written for them). The maintainer closed the feature: nothing to repair.

## R2. Which original and which placement

- **Decision**: a label matches when its `displayUUID` is this display and its recorded original resolves (bookmark,
  then path, as `DesktopLabeler.resolve` does) to the same file as the reported URL (compared after resolving
  symbolic links). With several matches, the most recently created label wins. The recorded placement and fill color
  are used, as `remove` uses them today.
- **Rationale**: the same comparison `remove` and `set` already trust; a match on the file name alone could match an
  unrelated image of the same name.
- **Alternatives considered**: reading the reported placement (`desktopImageOptions(for:)`) and keeping it: in the
  KI-3 state the reported options may be the fallback's too, so the recorded ones are safer.

## R3. Where in `remove`

- **Decision**: in `performRemoveLabel`, the `stamp(for:in:)` lookup that today returns `.noLabel` gains a second
  step: look for a matching original (R2); if found, set it (inside the same exclusive store access), mark seen as
  `remove` does, and return a new outcome `.repaired`. No change record, so `undo` is unaffected (spec FR-006).
- **Rationale**: one place, the lock already held, the same `apply` and settle as every change.

## R4. Messages

- `.repaired`: `No label recorded; set the original wallpaper again in case a label still showed.` (spec Q2), on standard output.
- With several displays, a repaired display is not counted as changed in the part-way message (spec 010 FR-006):
  what macOS reports for it is unchanged and there is nothing to undo, so the suggested `undo` does not name it.
