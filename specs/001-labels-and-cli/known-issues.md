# Known issues: spec 001

## KI-1: A label on a display's first Desktop is copied to new Desktops

**Status:** resolved in spec 001 (2026-10-05): shared images, `prune`, `--desktop` and the README section
are in; the "re-apply first" fix and the private store reader are removed. The macOS behavior itself remains
and is expected: a new Desktop copies the left-most Desktop on its display, which the user chooses by
reordering. The Desktop 1 note in `set` and the "First Desktop" row in `check` were removed for 0.1.1
(2026-10-07); the README documents the behavior instead. Details: `docs/research/desktop-association.md`.

**What happens.** macOS keeps, for each display, a default wallpaper for new Desktops that mirrors whichever
Desktop is first in Mission Control (hover over + in Mission Control to see it). A new Desktop starts with
that same image file. So a label on Desktop 1 appears on every new Desktop of that display, and reordering
changes which label that is. This is macOS behavior; public interfaces cannot prevent it.

**What was wrong in `dnm`.** It treated one labeled image as one Desktop, so removing the label on a new
Desktop "retired" the image and the first Desktop then looked unlabeled ("No label"). An earlier fix
(re-apply the wallpaper before the first label) rested on a wrong explanation and did not help; the
warning and cleanup safety it added read a private macOS file.

**Resolution (spec 001 amended 2026-10-05).** A labeled image may be shown on any number of Desktops;
every command acts only on the specified Desktop and never retires a shared image; labeled images are
deleted only through `dnm prune`; `--desktop 1` labels come with a note; the README explains the macOS
rule and the fix (`remove` or `set` on the new Desktop, or keep Desktop 1 unlabeled). The product reads
no private interfaces.

## KI-2: Desktops of a display arrangement that is not connected are invisible

**Status:** open (found live 2026-10-06, macOS 27).

**What happens.** macOS keeps each Desktop's wallpaper per display arrangement. Moving a Mac between two
and three monitors swaps in the other arrangement's Desktops (and moves Desktops between displays), and
each comes back with the wallpaper last set there. Public interfaces show only the current Desktop of each
connected display, so `dnm` cannot see Desktops of another arrangement. `prune --yes` (and any future
clean-up-all) can therefore delete a labeled image that a Desktop of a disconnected arrangement still uses;
when that arrangement returns, the Desktop's wallpaper file is gone. Seen live: two images pruned in a
three-monitor arrangement were still used by two Desktops of the two-monitor arrangement.

**Direction.** `prune`'s warning (and the planned clean-up-all) should name this case explicitly, and the
README should advise running them only after checking every arrangement in use. A full fix needs
information macOS does not offer publicly.


## KI-3: A new Desktop that inherited a label reports "no label" once the left-most label is removed

**Status:** open (found live 2026-10-07, `dnm` 0.1.0). Cause not yet confirmed.

**Steps.** One display with three Desktops: unlabeled, label A, label B.
1. Label the left-most Desktop with C.
2. Add a Desktop in Mission Control. It shows C, as expected (it copies the left-most Desktop).
3. Switch to the left-most Desktop and run `dnm remove`. The original wallpaper returns there.
4. Switch to the new Desktop, which still shows C, and run `dnm remove`.

**Expected.** The new Desktop returns to the original wallpaper.
**Actual.** `No label on DISPLAY.`; the Desktop keeps showing C.

**What differs from the tested case.** Live scenario 22 removes the label on the new Desktop *first*, and
that works. Here the left-most Desktop is cleared first. `remove` finds a label by the file name the system
reports for the display's current Desktop, whatever the label's record says, so the record being retired
in step 3 is not what fails: `NSWorkspace.desktopImageURL(for:)` must be reporting a file that is not C.

**Leading hypothesis (to confirm).** Step 3 also rewrites the display's default for new Desktops back to
the original (research finding 4). If the new Desktop's entry is only partly its own, the public reader may
fall back to that default and report the original, while the screen still draws C. Confirm with a read-only
`prototype/space-observer.swift` snapshot in this state: compare the new Desktop's store entries with what
`dnm show` reports.

**Workaround (maintainer).** Drag an unlabeled Desktop to the left-most place, add a new Desktop (it starts
clean), delete the Desktop `dnm` misreads, and label the new one; shell history makes the `dnm set` easy to
repeat. Keeping the left-most Desktop unlabeled avoids the problem altogether, because new Desktops then
never inherit a label.
