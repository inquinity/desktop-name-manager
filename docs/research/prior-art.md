# Prior art (checked 2026-09-28)

None of these puts a label into each Space's wallpaper. Only code under MIT or BSD
licenses can be reused, with attribution. Repos with no license are for reading only.

## Worth studying

| Project | License | Why it matters |
|---|---|---|
| [cumanzor/spacetools](https://github.com/cumanzor/spacetools) (0★, Aug 2026, "verified on macOS 26.5") | none | Closest in breadth. Names keyed by Space UUID; a per-Space corner badge window (the overlay approach); a name strip under the Mission Control Spaces bar; switch by name. It creates and removes Desktops by driving **Mission Control through Accessibility** (the Dock performs the action itself), with no SIP changes. It also has `layout save` / `layout restore`, "the one-command fix for macOS eating your spaces during a display reconfiguration": it recreates missing Desktops and reapplies names **by position**, but doesn't move Desktops between monitors. Relevant to Spikes S2 and S3. |
| [ZimengXiong/SpaceCommand](https://github.com/ZimengXiong/SpaceCommand) (30★, inactive since Dec 2025) | none | Closest to **Quick View**: a hotkey palette (⌘⇧Space) to jump to a Space by name. Its native backend needs the ⌃1…⌃0 "Switch to Desktop" shortcuts turned on; it prefers yabai. It ships unsigned and asks users to strip quarantine, which Homebrew now rejects. |
| [carusiphilip/SpaceNameBar](https://github.com/carusiphilip/SpaceNameBar) (0★, Sep 2026) | none | Menu-bar names keyed by UUID, plus experimental labels drawn over Mission Control thumbnails via Accessibility. It also **moves windows back to their saved Space UUIDs after login**, which is an alternative route for Spike S3. It cites Hammerspoon's `spaces.lua` (the Mission Control Accessibility hierarchy) and yabai's `mission_control.c`. |
| [ruittenb/Spaceman](https://github.com/ruittenb/Spaceman) (133★) | **MIT** | Mature menu-bar Space switcher. `ShortcutSwitcher` / `GestureSwitcher` are the reference for Spike S2. |
| [gechr/WhichSpace](https://github.com/gechr/WhichSpace) (841★) | **MIT** | Long-lived (since 2015) menu-bar indicator and switcher. A reference for reading Spaces robustly across macOS versions. |
| [jakehilborn/displayplacer](https://github.com/jakehilborn/displayplacer) (4.5k★) | **MIT** | Display identity: persistent vs contextual vs serial screen IDs. It warns that persistent IDs can swap when monitors wake in a random order. Informs the site and role matching for home/work monitors. |

## Not worth more time

- **McSim85/spacelabel** (MIT, Python): UUID-keyed menu-bar, HUD and overlay labels. It
  overlaps our CLI but has nothing we lack.
- **neonwatty/space-labeler** (MIT): a basic menu-bar name and color.
- **wiggly-sheets/spaces-renamer** (MIT): renames Spaces inside Mission Control by
  injecting into the Dock. Needs SIP changes.
- **jaywcjlove/deskmark**: the repo holds only docs and issue templates. The App Store
  app is closed source and draws one watermark for screen recording, not per Space.
  Relevant only as the name conflict.
- **DeskNamer** (`jorgecosta/desknamer`): a closed-source paid app ("Buy License" via
  Stripe, Sparkle updates, macOS 13+). The repo holds only DMG releases and an update
  feed, and the homepage returns 404. Its release notes mention a "switcher" with
  horizontal/vertical orientation. Nothing more is public without downloading the DMG.
- **Desktop Space Renamer** (App Store, $4.99): closed source, menu-bar only.
