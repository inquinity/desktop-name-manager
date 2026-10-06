# Known issues: spec 001

## KI-1: A label on a display's first Desktop is copied to new Desktops

**Status:** resolved in spec 001 (2026-10-05): shared images, `prune`, `--desktop`, the Desktop 1 note and the
README section are in; the "re-apply first" fix and the private store reader are removed. The macOS behavior
itself remains. Details: `docs/research/desktop-association.md`.

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

