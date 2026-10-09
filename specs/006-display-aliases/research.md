# Research: Display Aliases (Feature F2)

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## R1. macOS Display Naming & Duplicate Disambiguation

### Background & Constraint
When two monitors of the exact same make and model (e.g. two Studio Displays or two LG UltraFine displays) are connected to a Mac:
- Constitution Principle I explicitly forbids calling private window-server interfaces (such as SkyLight or `CGSCopySpacesForWindows`) or querying private display arrangement plists.
- Discovering cursor position to identify "the screen you are currently looking at" via private APIs is rejected.
- We rely strictly on public macOS interfaces: `NSScreen.localizedName` and CoreGraphics display identifiers.

### Findings (third-party reports, collected 2026-10-08; not verified on hardware)
1. **Names**: macOS identifies a display from its EDID (the monitor's own description of its maker, model and
   serial number). For identical monitors, System Settings > Displays appends a number: `Model (1)`,
   `Model (2)`. Whether `NSScreen.localizedName` carries the same suffix is to be confirmed when such a setup
   is available; nothing in the design depends on it beyond "names are usually distinct".
2. **Identities**: macOS derives each display's UUID from the EDID plus a part that depends on the port, so
   two identical monitors on different kinds of port (HDMI and USB-C, for example) get different identities.
3. **The edge case**: if both monitors carry the same EDID serial (blank or duplicated at the factory) *and*
   use the same kind of port, macOS itself cannot tell them apart reliably: their order, and which one is
   `(1)`, can swap after sleep or a restart.
4. **In `dnm`**: `CGDisplayCreateUUIDFromDisplayID(id)` gives the identity
   (`Sources/DesktopNameCore/System/SystemWallpaperSystem.swift`). When a display has none (virtual or
   capture devices), `dnm` builds `no-uuid-<vendor>-<model>-<serial>-<display ID>`; the display ID can change
   after a reconnect or restart, so that identity is not stable.

Sources (as reported by the maintainer): notes.alinpanaitiu.com "Weird monitor bugs"; Apple StackExchange
questions 396530 and 418067; MacRumors thread 2195237; Stack Overflow question 38156493.

### Decision
- Bind an alias to the display's UUID, and record the display's name at the time for showing it later.
- Refuse to alias a display whose identity is the `no-uuid-…` fallback, or one whose identity another
  connected display also reports (finding 3, or a fallback collision). Refusing is better than an alias that
  silently points at the wrong monitor.
- If two connected displays report the same name, choosing one by name stays ambiguous (the current
  resolver rule), so the alias cannot be created for it. This limits the rare setup in finding 3, not the
  feature.

---

## R2. Precedence and Shadowing

### Finding
If a display named `DP1` is connected, allowing an alias named `dp1` pointing to a different display would lead to severe user confusion and potential misapplication of desktop changes.
- **Decision**: An alias cannot be created if its name matches any connected display.
- If an alias was created while that display was disconnected, connecting the physical display takes precedence and **shadows** the alias.
- Emitting diagnostic warnings on stderr and annotating `dnm alias` keeps users informed without breaking scripted workflows or changing wallpapers unexpectedly.
- An exact alias is checked before partial display names, so an alias such as `LG` resolves to its display even when `LG` is also part of several connected names.

---

## R3. Storage and Downgrades

### Finding
The store is one `manifest.json` with `schemaVersion` 1. Swift's `Codable` ignores keys it does not know, so a
release without aliases would read a manifest that has them and drop them on its next write.

### Decision
- Keep aliases in `manifest.json` (one store, no fragmentation as the schema grows).
- Raise the schema to version 2. This release reads 1 and 2 and writes 2; older releases refuse version 2
  instead of dropping the aliases.
- Loss of backward compatibility is an accepted risk: at 0.1 the tool has one user, who will not downgrade.
- Alternatives rejected: a separate `aliases.json` (splits the store), and writing version 1 while no alias
  exists (protects a downgrade path nobody needs).
