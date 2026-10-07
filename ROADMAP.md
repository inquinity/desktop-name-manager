# Roadmap

Where Desktop Name Manager is going, in build order. Each feature gets its own Spec Kit specification in
`specs/` (specify, clarify, plan, tasks, implement); the specification is the source of truth once it
exists. Ideas with no place in the order yet are in [docs/backlog.md](docs/backlog.md).

## Features in build order

| # | Feature | Specification | Status |
|---|---|---|---|
| 1 | Labels and the `dnm` command-line tool | [specs/001-labels-and-cli](specs/001-labels-and-cli/) | **Built.** Live-tested on macOS 26 and 27, Apple silicon and Intel; release gates open (below) |
| 2 | The menu-bar app and label editor | not written | Notes only |
| 3 | Quick View: see every label, switch to one | not written | Notes only |
| 4 | Desktop groups, display roles and sites (home and work monitors) | not written | Notes only |
| 5 | Packaging and release: signed, notarized, Homebrew cask | [specs/005-packaging-and-release](specs/005-packaging-and-release/) | Draft, not clarified |
| 6 | Live and dynamic wallpapers | not written | Idea only |

### 1. Labels and the `dnm` command-line tool

Label the Desktop on screen or any Desktop by number (`--desktop`), remove, undo, show, list, prune,
`about` and `check`. Public macOS interfaces only; labeling needs no permission, `--desktop` needs
Accessibility as an explicit opt-in.

Open: the full quickstart on both macOS versions (T070), the CI workflow (T006), the independent and
security reviews (T091, T072), and confirming the measured `--desktop` timings
([docs/research/timings.md](docs/research/timings.md)).

### 2. The menu-bar app and label editor

A menu-bar app over the same core library: a popover editor with live preview and style, position, size
and color choices; the current Desktop's label in the menu bar (icon, icon and label, or hidden); an
optional hotkey; an About window (the same content as `dnm about`) and Help > Configuration (the same as
`dnm check`).

### 3. Quick View

See every labeled Desktop and pick one to switch there. Public interfaces cannot list Desktops, so the
specification must settle what Quick View can show without private interfaces (the constitution allows
none in the product).

### 4. Desktop groups, display roles and sites

Groups of Desktops across monitors (one Desktop per monitor; a Desktop can be in several groups), and
matching home and work monitor setups so Desktops return to where they belong after a monitor change.
macOS keeps Desktops per display arrangement (known issue KI-2), which this feature has to work with.

### 5. Packaging and release

A release procedure that refuses to run until the constitution's gates are met, then builds, signs with
the Developer ID, notarizes and publishes to GitHub Releases, with a cask in the `inquinity/homebrew-tap`
tap (unlisted at first). The first release ships the command-line tool only; the app joins it later.

### 6. Live and dynamic wallpapers

Labels on dynamic, aerial and shuffling wallpapers, which `dnm` refuses today (exit 3).

## Minimum viable product

**Proposed (open for the maintainer to confirm): the command-line tool, installed locally for daily use.**
It already does the core job: name each Desktop on every display, from the terminal or a script.

Exit criteria:

1. One timing run (`Tests/live/live-timing.sh`) and one `Tests/live/live-desktops.sh` run pass on this
   Mac with the measured `--desktop` settings.
2. Installed for the maintainer: `just release`, then `dnm` and `desktop-name` on the PATH.
3. A period of daily use; problems go to `specs/001-labels-and-cli/known-issues.md` or the backlog.

The alternative MVP is the menu-bar app (feature 2), which still needs its specification.

## Gates: using it versus releasing it

| Gate | Personal use | Public release |
|---|---|---|
| Unit, contract and Periphery checks pass | yes | yes |
| Live checks on macOS 26 and 27 | the ones above | the full quickstart (T070) |
| Independent code review (`/code-review ultra`) | no | yes (T091, T072) |
| Security review and CodeQL | no | yes (T072) |
| CI workflow | no | yes (T006) |
| Signed and notarized build | no (a local build) | yes (feature 5) |

The constitution requires its reviews before a **release**; building and running the tool on the
maintainer's own Mac is not a release.

## Related

- [docs/backlog.md](docs/backlog.md): ideas not yet placed, such as batch labeling, multi-line labels,
  cleaning up all labeled images, and a separate full-featured build.
- [specs/001-labels-and-cli/known-issues.md](specs/001-labels-and-cli/known-issues.md): KI-1 (the first
  Desktop's wallpaper is copied to new Desktops) and KI-2 (Desktops of a display arrangement that is not
  connected are invisible).
- [docs/research/](docs/research/): how macOS ties Desktops to wallpapers, and Desktop-switching timings.
