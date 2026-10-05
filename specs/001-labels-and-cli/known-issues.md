# Known issues: spec 001

## KI-1: A label can become the default for new Desktops (and spread to other Desktops)

**Status:** open, found 2026-10-05 in live use. **Severity:** medium (wrong wallpaper on new Desktops; a
cleanup gap that can leave macOS pointing at a deleted image).

**What was seen.** On an external display with two Desktops, labeling one Desktop ("set") made every
**new** Desktop created on that display show the same label, whichever Desktop the new one was created from.

**What the wallpaper store shows (macOS 27.0.1, read-only inspection of `Index.plist`).**
- macOS keeps an entry per Desktop, a **default entry per display** (used for new Desktops), and a template
  entry for new Desktops. A label set on the built-in display touched only that Desktop's own entries
  (confirmed by a before and after comparison, then removed).
- On the affected display, the first label was also written into that display's **default entry**. Later labels
  on that display changed only their own Desktop's entries.
- This matches a known macOS behavior (Apple Developer Forums report, cited in the research notes): with
  "Show on all Spaces" on for a display, the first programmatic wallpaper set applies to every Desktop on
  it, after which macOS turns the setting off. The setting is per display, so checking it for one display
  does not protect another. That the setting was on for the affected display is an inference.
- The built-in display's template entry for new Desktops still pointed at a stamp from an earlier test run
  (in a temporary folder), so new Desktops there can also show an old label.

**Why `dnm` did not notice.** It sees only the current Desktop of each display through public APIs. It cannot
see defaults or other Desktops, so its idea of "labeled Desktops" and of which stamps are "in use" is
incomplete.

**Related gap.** Cleanup deletes a retired stamp 30 minutes after a removal or replacement. If a default
entry still points at that stamp, macOS is left pointing at a missing image.

**Workaround today (no code).** For each display you label: System Settings > Wallpaper > choose the display,
turn "Show on all Spaces" ON, pick the normal wallpaper (this resets that display's default and all its
Desktops), turn it OFF, then label Desktops one at a time. The README now says to do this for every display.

**Planned fix (tasks T073 to T078).**
1. A read-only, optional reader of the wallpaper store, isolated in one module (constitution principle I allows
   private reads that are read-only and optional; failure to read must never block labeling).
2. After `set`, check whether the new stamp also appears in a default or template entry or on other
   Desktops. If it does, undo (which restores the original everywhere the stamp landed) and tell the user to
   turn off "Show on all Spaces" for that display and run again.
3. Make cleanup keep any stamp the wallpaper store still references.
4. Say which display and which setting in the first warning.
5. Tests from small synthetic stores; a live check on a display with the setting on.

**Spec effects when fixed.** Amendment to FR-018 ("in use" can then use the store), and an assumption change:
"Show on all Spaces" is detected after the fact rather than only documented.
