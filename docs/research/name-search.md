# Name search (2026-09-27)

Channels checked for each name:
- Homebrew (formula and cask API);
- the Mac and iOS App Store (iTunes Search API, name contains the term);
- GitHub repositories (name contains the term);
- npm, PyPI and crates.io, plus MacPorts for "deskmark";
- .com and .app domains (registry RDAP; 404 means unregistered);
- the web, for commercial products;
- USPTO trademark search (tmsearch.uspto.gov, basic wordmark search; checked it works
  with "nameplate", which returns 21 results).

## Deskmark: not usable

- **Mac App Store:** "Deskmark", a free Productivity app from 楚江 王 (Wang Chujiang),
  v1.9, updated 2026-09-12. It "adds text and icon watermarks to your desktop". Same
  category as ours.
- **GitHub:** `jaywcjlove/deskmark` (23★, Swift, updated 2026-09-13), the source of that
  app. Homepage wangchujiang.com/deskmark.
- **Other GitHub repos:** about 25 unrelated ones, mostly 2016–2018 React tutorial apps.
  `DKJRJUH/deskmark` (0★, created 2026-09-27) has a boilerplate "Simplify your
  note-taking" description typical of lure repos. I didn't open it.
- **Clear:** Homebrew, npm, PyPI, crates, MacPorts and USPTO. deskmark.com has been
  registered since 2000.

## Candidates

| Name | Homebrew | App Store | GitHub | npm/PyPI/crates | .com / .app | USPTO | Web / commercial |
|---|---|---|---|---|---|---|---|
| **Roomplate** | free | none | 0 repos | free | **free / free** | no results | nothing found |
| **Desktag** | free | none | 3 repos, incl. `zharinov-nikita/DeskTag` (1★, a Windows 11 badge showing the virtual desktop name) | free | taken / free | no results | nothing specific |
| **Deskplate** | free | none | 3 repos, incl. `takashyx/DeskPlate` (0★, a Windows 11 app showing the virtual desktop name) | free | taken / free | one dead mark (VISO-DESKPLATE, 1957, desk shelf coverings) | "DESK PLATE", a Japanese web and iPhone development agency (deskplate.net) |
| Deskcrest | free | none | 0 | free | taken / free | not checked | too close to **DeskRest**, a macOS break-reminder app |
| Deskname | free | none | `jorgecosta/desknamer`, "DeskNamer: macOS desktop organiser" | free | taken / free | not checked | conflict |
| Nameplate | free | 4 apps | `steipete/Nameplate` (66★, "brand every Mac… name tag, watermark") | npm taken | taken | many marks | conflict |
| Placard, Lintel, Waymark, Doorplate, Deskpin, Wallmark, Spacemark | crowded on GitHub and/or the App Store and/or registries | | | | | | |

## Desktop Name variants (2026-09-28)

| Check | desktop-name | desktop-name-mgr | desktop-name-manager |
|---|---|---|---|
| Homebrew formula/cask | free | free | free |
| App Store titles containing "desktop name" | none | none | none |
| GitHub repos with the name | 69, mostly unrelated | – | **0** |
| npm / PyPI | free | – | free |
| .com / .app | **both free** | – | **both free** |

Nearby projects to know about, none an exact match:
- `supreetsharma/DesktopNamer` (1★, Swift, a menu-bar utility for naming Spaces);
- `binaryage/totalspaces2-desktopname` (3★, an old TotalSpaces2 plugin);
- `lutz/VirtualDesktopNameDeskband` (22★, Windows);
- DeskNamer (paid, closed source);
- Desktop Space Renamer (App Store).

USPTO wasn't rechecked. Descriptive names like these are hard to register as trademarks
anyway.

## Not checked

- EUIPO / WIPO Global Brand Database (their search UIs need manual use).
- Google Play.
- A professional clearance search. This is a private tap, so the risk is low, but it's
  worth doing before any public release.
