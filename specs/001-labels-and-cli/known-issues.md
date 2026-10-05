# Known issues: spec 001

## KI-1: A label on a display's first Desktop is copied to new Desktops

**Status:** understood and redesigned (2026-10-05); the old "re-apply first" fix and the private store reader
are being removed. Details: `docs/research/desktop-association.md`.

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
