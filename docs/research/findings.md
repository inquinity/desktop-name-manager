# Findings from the prototype (macOS 27.0, September 2026)

Tested on macOS 27.0 (26A428) with two displays and "Displays have separate Spaces" on,
using `prototype/dnm-prototype.swift`.

## Labeling through the wallpaper

| Question | Result |
|---|---|
| Does `NSWorkspace.setDesktopImageURL(_:for:options:)` affect only the current Space? | Yes. In the wallpaper store (`~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`), only that Space's "Default" slot and its slot for that display changed. Other Spaces and other displays were untouched. |
| Is the label visible under Show Desktop? | Yes. It is the wallpaper. |
| Does it stay off other Spaces? | Yes. |
| Mission Control | macOS 27 collapses the Spaces bar to "Desktop 1 / 2 / 3" text and shows thumbnails only on hover. At 3% of screen height, the label can't be read in thumbnails. |
| How fast? | 261 ms for the command: load 81 ms, analyze and render ~110 ms, write 18 ms, set 6 ms. The label is visible 350–450 ms after the command starts. Rendering for a 5K display took 120–350 ms per image. |
| Can we read the current wallpaper? | Yes, for image files. `NSWorkspace.desktopImageURL(for:)` returns the current Space's file. In a long-running process it follows Space switches immediately, with no stale cache. |
| Permissions needed? | None. No entitlements either. |
| Does macOS cache its own copy? | No. The store records a file URL only (no bookmark, no copy), so labeled images must stay on disk while any Space uses them. |
| Can the original be restored exactly? | Yes: same file, same placement, same color space. The fill color comes back rounded to 10 decimal places, which is invisible. |
| Private interfaces used | None for labeling. Reading the Space list (SkyLight `SLSCopyManagedDisplaySpaces`) and the wallpaper store is optional and read-only, used by `list`. |

## Automatic style

The prototype checked 23 varied photographs at 5K: night, water, glacier, snow, grass,
waterfall, portraits, and a 692×577 source. At the label's spot it measures:
- luminance;
- the share of weak-contrast pixels for white text and for black text;
- texture;
- Vision attention saliency.

It then picks the text color and one of three backings: plain, halo, or frosted (blur
plus tint). All 23 labels were legible.

Picking the corner automatically tended to choose the sky corners, where desktop icons
usually sit, so a fixed corner with automatic style is the better default.

## An overlay window per Space (the alternative)

A borderless window at desktop level with `.stationary` and without `.canJoinAllSpaces`
stays on the Space where it was created and survives Show Desktop (tested). Recreating
such windows after a restart needs the Space identity (private, read-only), and the app
has to keep running.

## Wallpaper types

- Apple's catalog wallpapers (`.madesktop`, 63 on macOS 27) are small plists pointing to
  on-demand downloads.
- Some bundled HEICs are dynamic. For example, `Sonoma.heic` holds 2 images with
  `apple_desktop:apr` metadata.
- Aerials are videos.

None of these can be stamped as-is. See "live and dynamic wallpapers" in the
specification.

## Other constraints found

- Per an Apple Developer Forums report for Tahoe, if "Show on all Spaces" is on, the first
  programmatic set applies to every Space, and then macOS turns the switch off.
- Moving a Space to another display has no public API. yabai does it by injecting into
  the Dock, which requires SIP changes. Homebrew does not accept casks that need SIP
  disabled.
- Spaceman, the best-known menu-bar Space namer, keys names by `ManagedSpaceID` with a
  position fallback. Its README says it is incompatible with "Automatically rearrange
  Spaces based on most recent use".
