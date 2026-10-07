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
| 5 | Packaging and release: signed, notarized, Homebrew cask | [specs/005-packaging-and-release](specs/005-packaging-and-release/) | Draft, not clarified. Its first part (a notarized build in an unlisted cask) is in the MVP |
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

A release procedure that builds, signs with the Developer ID, notarizes and publishes to GitHub Releases,
with a cask in the `inquinity/homebrew-tap` tap. It comes in two stages:

- **MVP stage:** the command-line tool, notarized, in an **unlisted** cask under a quiet name (spec 005
  User Stories 1 and 2), so it installs with one `brew install`.
- **Official release (later):** the cask listed in the tap's README, with every release gate of the
  constitution met, and later a submission to Homebrew itself. The app joins after feature 2.

### 6. Live and dynamic wallpapers

Labels on dynamic, aerial and shuffling wallpapers, which `dnm` refuses today (exit 3).

## Minimum viable product

**The command-line tool (feature 1), signed, notarized and installable from an unlisted cask in the
`inquinity/homebrew-tap` tap (the first stage of feature 5).** Decided 2026-10-07.

Exit criteria:

1. One timing run (`Tests/live/live-timing.sh`) and one `Tests/live/live-desktops.sh` run pass on this
   Mac with the measured `--desktop` settings.
2. Spec 005 clarified for the MVP stage, then planned and built: a release procedure that signs with the
   Developer ID, notarizes, publishes the download on GitHub Releases, and updates the unlisted cask.
3. `brew install` of the quiet cask works on macOS 26 and 27 (Apple silicon and Intel), and Gatekeeper
   accepts the tool.
4. A period of daily use; problems go to `specs/001-labels-and-cli/known-issues.md` or the backlog.

The menu-bar app (feature 2) comes after the MVP.

## Gates: MVP versus official release

| Gate | MVP (unlisted cask) | Official release (listed) |
|---|---|---|
| Unit, contract and Periphery checks pass | yes | yes |
| Live checks on macOS 26 and 27 | the ones above | the full quickstart (T070) |
| Signed and notarized build | yes | yes |
| Independent code review (`/code-review ultra`) | **open question** | yes (T091, T072) |
| Security review and CodeQL | **open question** | yes (T072) |
| CI workflow | no | yes (T006) |

The constitution requires its code and security reviews before any build is "signed and published". An
unlisted cask is still a published, signed download, so the MVP needs either those reviews or a written
constitution amendment for a preview stage; see the open decision in the maintainer's notes.

## Related

- [docs/backlog.md](docs/backlog.md): ideas not yet placed, such as batch labeling, multi-line labels,
  cleaning up all labeled images, and a separate full-featured build.
- [specs/001-labels-and-cli/known-issues.md](specs/001-labels-and-cli/known-issues.md): KI-1 (the first
  Desktop's wallpaper is copied to new Desktops) and KI-2 (Desktops of a display arrangement that is not
  connected are invisible).
- [docs/research/](docs/research/): how macOS ties Desktops to wallpapers, and Desktop-switching timings.
