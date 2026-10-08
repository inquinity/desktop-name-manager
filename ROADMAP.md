# Roadmap

Where Desktop Name Manager is going, in build order. Each feature gets its own Spec Kit specification in
`specs/` (specify, clarify, plan, tasks, implement); the specification is the source of truth once it
exists. Ideas with no place in the order yet are in [docs/backlog.md](docs/backlog.md).

## Major milestones

The features in build order. Each milestone is reached when its feature is done; **M1 is the MVP** and
**M5 is version 1.0.0, feature complete** (the official release). M6 comes after 1.0.0.

| Milestone | Feature | Specification | Status |
|---|---|---|---|
| **M1 (MVP)** | Labels and the `dnm` command-line tool | [specs/001-labels-and-cli](specs/001-labels-and-cli/) | **Released as 0.1.0 (build 1), 2026-10-07**: notarized, in the unlisted `desktop-name-manager` cask. Installed and checked on macOS 26 and 27; in daily use. The Intel refusal check remains |
| M2 | The menu-bar app and label editor | not written | Notes only |
| M3 | Quick View: see every label, switch to one | not written | Notes only |
| M4 | Desktop groups, display roles and sites (home and work monitors) | not written | Notes only |
| **M5 (1.0.0)** | Packaging and release: signed, notarized, Homebrew cask | [specs/005-packaging-and-release](specs/005-packaging-and-release/) | Draft, not clarified. Its first stage (a notarized build in an unlisted cask) is part of M1 |
| M6 | Live and dynamic wallpapers | not written | Idea only |

### M1. Labels and the `dnm` command-line tool

Label the Desktop on screen or any Desktop by number (`--desktop`), remove, undo, show, list, prune,
`about` and `check`. Public macOS interfaces only; labeling needs no permission, `--desktop` needs
Accessibility as an explicit opt-in.

Open: the full quickstart on both macOS versions (T070), the CI workflow (T006), the independent and
security reviews (T091, T072), and confirming the measured `--desktop` timings
([docs/research/timings.md](docs/research/timings.md)).

### M2. The menu-bar app and label editor

A menu-bar app over the same core library: a popover editor with live preview and style, position, size
and color choices; the current Desktop's label in the menu bar (icon, icon and label, or hidden); an
optional hotkey; an About window (the same content as `dnm about`) and Help > Configuration (the same as
`dnm check`).

### M3. Quick View

See every labeled Desktop and pick one to switch there. Public interfaces cannot list Desktops, so the
specification must settle what Quick View can show without private interfaces (the constitution allows
none in the product).

### M4. Desktop groups, display roles and sites

Groups of Desktops across monitors (one Desktop per monitor; a Desktop can be in several groups), and
matching home and work monitor setups so Desktops return to where they belong after a monitor change.
macOS keeps Desktops per display arrangement (known issue KI-2), which this feature has to work with.

### M5. Packaging and release

A release procedure that builds, signs with the Developer ID, notarizes and publishes to GitHub Releases,
with a cask in the `inquinity/homebrew-tap` tap. It comes in two stages:

- **MVP stage (part of M1):** the command-line tool, notarized, in an **unlisted** cask under a quiet name (spec 005
  User Stories 1 and 2), so it installs with one `brew install`.
- **Official release, 1.0.0 (M5):** the cask listed in the tap's README, with every release gate of the
  constitution met, and later a submission to Homebrew itself. The app (M2) joins it.

### M6. Live and dynamic wallpapers

Labels on dynamic, aerial and shuffling wallpapers, which `dnm` refuses today (exit 3).

### Feature map

Features smaller than a milestone, with the release each is planned for. A feature gets a specification
(or an amendment to an existing one) before it is built. "Not set" means it is in the backlog with no
release yet.

| Description | Feature | Target release |
|---|---|---|
| Display aliases: short names for displays, tied to the display's identity ([backlog](docs/backlog.md)). Comes before F1 | F2 | 0.1.1 |
| Shell completions for bash and zsh: every command and option, with display names and aliases (F2) offered live for `--display` (as git offers branch names) and the fixed values of `--style`, `--color`, `--position` and `--size`; installed by the cask | F1 | 0.1.1 |
| Clean up all labeled images after a manual reset, for example `dnm prune --all` ([backlog](docs/backlog.md)) | F4 | 0.1.2 |
| Batch labeling: several Desktops in one command ([backlog](docs/backlog.md)) | F3 | 0.1.3 |
| Multi-line labels: an app feature (M2), not a CLI one ([backlog](docs/backlog.md)) | F5 | After 1.0.0 at the earliest |
| `remove` repairs a Desktop that still shows a label macOS no longer reports (known issue KI-3) | F6 | Not set |

## Minimum viable product (M1)

**The command-line tool (M1's feature), signed, notarized and installable from an unlisted cask in the
`inquinity/homebrew-tap` tap (the first stage of the M5 feature).** Decided 2026-10-07.

Exit criteria:

1. One timing run (`Tests/live/live-timing.sh`) and one `Tests/live/live-desktops.sh` run pass on this
   Mac with the measured `--desktop` settings.
2. Spec 005 clarified for the MVP stage, then planned and built: a release procedure that signs with the
   Developer ID, notarizes, publishes the download on GitHub Releases, and updates the unlisted cask.
3. `brew install` of the quiet cask works on macOS 26 and 27 (Apple silicon and Intel), and Gatekeeper
   accepts the tool.
4. A period of daily use; problems go to `specs/001-labels-and-cli/known-issues.md` or the backlog.

The menu-bar app (M2) comes after the MVP.

## Gates: M1 (MVP) versus M5 (1.0.0)

| Gate | M1: MVP (unlisted cask) | M5: 1.0.0 (listed) |
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

- [docs/backlog.md](docs/backlog.md): ideas not yet placed, such as display aliases, batch labeling, multi-line labels,
  cleaning up all labeled images, and a separate full-featured build.
- [specs/001-labels-and-cli/known-issues.md](specs/001-labels-and-cli/known-issues.md): KI-1 (the left-most
  Desktop's wallpaper is copied to new Desktops), KI-2 (Desktops of a display arrangement that is not
  connected are invisible) and KI-3 (a new Desktop that inherited a label can report "No label").
- [docs/research/](docs/research/): how macOS ties Desktops to wallpapers, and Desktop-switching timings.
