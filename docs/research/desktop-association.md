# How macOS ties Desktops to wallpapers, and what it means for labels

Research for spec 001 after a live finding (known issue KI-1). Observed on macOS 27.0.1 with two displays
and "Displays have separate Spaces" on; the maintainer reports the same behavior on macOS 26.7.

## Method

A research tool, `prototype/space-observer.swift` (never part of the product), snapshots three things and
shows what changes after each action: Mission Control's list of Desktops (a private, read-only system call),
macOS's wallpaper store (a private file, read-only), and `dnm`'s own records. Desktops were switched with
the standard Control-arrow shortcuts, labeled with `dnm`, and created, deleted and reordered by hand in
Mission Control.

## What macOS does

1. **Each Desktop has its own wallpaper entry**, keyed by an internal identifier. Public APIs never expose
   that identifier: an app can only read and set the wallpaper of each display's *current* Desktop.
2. **Each display has a default wallpaper for new Desktops, and it mirrors whichever Desktop is first in
   Mission Control.** Setting the first Desktop's wallpaper rewrites the default in the same moment;
   setting any other Desktop does not. Reordering Desktops rewrites the default to match the new first
   Desktop. Mission Control shows this: hovering over + previews the first Desktop's wallpaper, and the
   preview changes after a reorder. On the main display, the system-wide default follows too.
3. **A new Desktop gets its own entry at creation, copied from that default:** the same image file, before
   anyone visits it. (Earlier macOS versions copied the current Desktop instead, per the maintainer.)
4. **Switching Desktops writes nothing; deleting a Desktop leaves its entry behind.**
5. So **one image file can be the wallpaper of several Desktops**, and an app cannot tell which Desktops
   share it.

## What that breaks in `dnm` today

`dnm` treats one labeled image file as one Desktop. With the rules above:

- A label on a display's first Desktop is copied to every new Desktop on that display.
- Removing the label on one of those Desktops retires the shared file, so the other Desktop that still
  shows it looks unlabeled to `dnm`, and `remove` there says "No label" (the live case that started this).
- Cleanup could delete a file that other Desktops (or the default) still show. A read-only check of the
  wallpaper store currently prevents that, but it reads a private file.
- Re-applying the wallpaper before the first label (the first KI-1 fix) does not help: the trigger is the
  first Desktop, not the first change.

## Options (public APIs only, as the product requires)

**A. Treat a labeled image as something any number of Desktops may show (recommended).**
- `set`, `remove` and `undo` act only on the current Desktop of a display, as now, but never change the
  status of the image file because of that: other Desktops may show the same file.
- `set` on a Desktop that shows a shared labeled image gives *this* Desktop a new image of its own; the
  others keep theirs.
- `remove` restores the recorded original on this Desktop and leaves the labeled image in place.
- Files are deleted only when they were never applied (a crash leftover), or when the person asks
  (a new `dnm prune`, with a clear warning that a Desktop still showing the image would lose it).
- `list` shows the labels the tool has made and what each display's current Desktop shows; it cannot
  say which other Desktops show a label, and says so.
- Documentation states the macOS rule: a label on a display's first Desktop is copied to new Desktops
  there; relabel or `dnm remove` the new Desktop, or keep the first Desktop unlabeled.
- Cost: labeled images accumulate until pruned (about 1 to 3.5 MB each).

**B. Keep A and also read the wallpaper store (private file, read-only, optional) for warnings and safe
cleanup.** Better housekeeping and an immediate warning when a label reaches the default, but it uses a
private interface in the product.

**C. Identify Desktops with the private Space list.** Would solve association outright, but it is a private
system call; ruled out for the product.

**D. Leave as is and document.** Does not fix the "No label" error or the cleanup risk.

## Decision (2026-10-05)

Option A, with one change: commands act on **the specified Desktop**, not only the current one. The goal is
to script labeled sets across displays, for example:

```sh
dnm set "LABEL1" --display main --desktop 2
dnm set "LABEL1" --display DP   --desktop 2
dnm set "LABEL2" --display main --desktop 3
dnm set "LABEL2" --display DP   --desktop 3
```

Whether `--desktop N` can be done with public APIs only is being tested as a spike (switch to Desktop N with
the standard keyboard shortcuts, which needs the opt-in Accessibility permission; set; switch back).

## Spike: `--desktop N` with public APIs only (2026-10-05)

Result: **it works.** A small test program, using only public APIs, did this on both displays:

1. Move the pointer to the target display (restored afterwards), so the shortcuts act there.
2. Press Control-Left until macOS stops announcing a Desktop change (the public
   `NSWorkspace.activeSpaceDidChangeNotification`); silence means it is at Desktop 1, and the number of steps
   taken gives the starting position.
3. Press Control-Right N-1 times, each confirmed by the notification; if one is not confirmed, Desktop N
   does not exist.
4. Set the label, then step back to the starting Desktop.

Checked against the private Space list (research only): it reached the intended Desktop every time, labeled
the right one, and returned to the start, on the main display and on an external one.

What it needs and costs:
- The "Move left a space" and "Move right a space" shortcuts enabled (they are by default), and the
  **Accessibility permission** to send them (the constitution allows it as an explicit opt-in for switching).
- The notification arrives only through an application event loop: the command must run briefly as a
  background application (no Dock icon, never takes focus).
- About 0.6 s per step with the slide animation, plus about 1 s to confirm the left edge: 3 to 6 s for a
  label on another Desktop and back. "Reduce motion" should shorten it (not measured).
- The person sees the Desktops slide, and should not type while it runs (it sends keystrokes).
- Full-screen app Spaces sit among the Desktops in the Control-arrow order but are not numbered as Desktops
  by Mission Control, so they can shift the count. Decided: a documented edge case, not handled, since
  the wallpaper is rarely seen on a full-screen Space.

## Effects of option A on spec 001

- FR-018 and SC-006 (cleanup): no automatic deletion of applied labels; add `prune`.
- FR-008, FR-009, FR-022 (remove, replace, undo): act on the current Desktop only; a labeled image is never
  "retired" for every Desktop.
- Data model: a labeled image has no single Desktop; its record keeps its original and label, and
  whether it was ever applied.
- KI-1: reframed as documented macOS behavior with a workaround, not a defect `dnm` can fully fix.
