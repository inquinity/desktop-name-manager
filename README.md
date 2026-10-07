# Desktop Name Manager

Label each macOS Desktop (Space) with what it's for, such as "Status Report" or "Mail &
Chat", right on the desktop background.

Desktop Name Manager draws the label into a copy of the Desktop's wallpaper and sets it
with the public macOS wallpaper API. From then on macOS itself keeps the label with that
Desktop, through restarts, reordering and Show Desktop. The label's style adapts to what
is behind it, so it stays readable without getting in the way.

Planned:
- a menu-bar app with a label editor;
- Quick View, to jump to a Desktop by its label;
- Desktop groups across monitors;
- matching monitors between places, such as home and work, so Desktops return to where
  they belong.

The command-line tool is `dnm`.

## Try the command-line tool

Not packaged yet; build it from source (macOS 26 or later, Xcode 27 command-line tools):

```sh
swift build -c release --scratch-path build.noindex
build.noindex/release/dnm set "Status Report"   # label the Desktop you are on
build.noindex/release/dnm remove                # put the original wallpaper back
```

A label is one line of 1 to 30 characters (emoji are fine). Commands act on the Desktop on
screen, because macOS lets an app change only that one; `--desktop <n>` switches to another
Desktop for you (see below).

| Command | What it does |
|---|---|
| `dnm set <label>` | Label the current Desktop. Options: `--style plain\|halo\|frosted`, `--color light\|dark\|#RRGGBB`, `--position bottom-left\|bottom-right\|top-left\|top-right\|bottom\|top`, `--size small\|medium\|large`. Anything left out is chosen from the wallpaper or uses its default. |
| `dnm remove` | Remove the label and restore the original wallpaper exactly. |
| `dnm undo` | Undo the last change on a display, for 30 minutes (one level). |
| `dnm show` | Show the label on the current Desktop. |
| `dnm list` | List labeled Desktops and the current Desktop of each display. Only those are shown. |
| `dnm displays` | List the connected displays, as `--display` accepts them. |
| `dnm prune` | List labeled images no longer in use as a label, and with `--yes` delete them. |
| `dnm about` | Version, where data is kept, and what permissions the tool uses and why. |
| `dnm check` | How this Mac is set up for labels and `--desktop`, and how to fix what is missing. |

`--display <name>` picks another display: its name as macOS shows it, or part of the name if
it matches only one display. `main` always works, and it is the default. `show`, `list`,
`displays`, `prune`, `about` and `check` accept `--json`.

## Label sets of Desktops

`set`, `remove`, `undo` and `show` accept `--desktop <n>`: the Nth Desktop of the display, numbered as
Mission Control numbers them. A script can then label the same position on every display:

```sh
dnm set "Mail"     --display main --desktop 2
dnm set "Mail"     --display DP   --desktop 2
dnm set "Projects" --display main --desktop 3
dnm set "Projects" --display DP   --desktop 3
```

What you see: the display slides to that Desktop, the label is applied, and it slides back to the
Desktop it started on. The pointer moves to that display and returns. Don't type while it runs.

`--desktop` is opt-in and needs two things, which `dnm check` reports:
- **Accessibility** for the app you run `dnm` from (your terminal): System Settings > Privacy &
  Security > Accessibility on macOS 26, or **Device Control and Data Access** on macOS 27 (which has no
  Accessibility item there). Quit and reopen the app after turning it on. macOS gives apps no public way to switch Desktops, so `dnm` presses
  macOS's own "Move left a space" and "Move right a space" shortcuts. Nothing else is typed or read.
  `dnm` never asks for the permission itself; without it, `--desktop` stops and changes nothing.
- **The shortcuts turned on**: System Settings > **Keyboard** (near the bottom of the sidebar) >
  Keyboard Shortcuts… > Mission Control, then **expand** the Mission Control group and turn on "Move left
  a space" and "Move right a space". The Shortcuts… button in Desktop & Dock does not list them.
  Their state cannot be read publicly; if nothing moves, `dnm` says the display has one Desktop or
  the shortcuts are off, and changes nothing.

Without `--desktop` there is no switching and no permission.

A full-screen app takes a place among the Desktops in Mission Control, so it can shift the count:
with one open, `--desktop 3` may land on a different Desktop than you expect. This edge case is not
handled; leave full-screen apps or count them in.

Exit codes: `0` success; `1` failure (for example macOS denied access to the wallpaper file,
or undo is not possible); `2` invalid input; `3` unsupported wallpaper (dynamic, aerial,
catalog, shuffle, or none reported). Nothing is changed when a command fails.

`dnm --version` says which build you have: a release prints the plain version (for example `0.1.0`);
any other build prints the commit it was built from (for example `0.1.0-dev+9398ae4`, with `.dirty` added if
there were uncommitted changes, and `-dev+unknown` if it was built without a stamp).

Good to know:
- Labeling the Desktop on screen needs no macOS permissions; only `--desktop` needs Accessibility.
  The tool makes no network connections and collects no telemetry.
- macOS gives every new Desktop a copy of the **first** Desktop's wallpaper on that display (hover over +
  in Mission Control to see it), and reordering Desktops changes which one that is. A label on Desktop 1
  therefore appears on new Desktops too; run `dnm remove` or `dnm set` on the new Desktop, or keep
  Desktop 1 unlabeled. See `docs/research/desktop-association.md`.
- For the same reason one labeled image can be on several Desktops, so removing or replacing a label
  never deletes its image: `dnm prune` lists the ones no longer in use and deletes them with `--yes`.

## Status

Early. Spec 001 (labels and the `dnm` command-line tool) is being implemented; see
`specs/001-labels-and-cli/`. The menu-bar app and the other planned features are not built
yet. `prototype/` holds the proof of concept that validated the approach, and
`docs/research/` holds what testing and research found. The build order and the MVP are in
[ROADMAP.md](ROADMAP.md).

## Development

```sh
just build        # build the library and the tool (output goes to build.noindex/, not .build/)
just test         # unit and contract tests (they never change your real wallpaper)
just release      # optimized build: build.noindex/release/dnm (the commit is stamped into the binary)
just periphery    # unused-code scan (needs `brew install periphery`)
just kit          # assemble the live-test kit to copy to another Mac
```

Without `just`, add `--scratch-path build.noindex` to `swift build` and `swift test`.

Live checks change your real wallpaper. They are listed in
`specs/001-labels-and-cli/quickstart.md`; back up the wallpaper store first and use a private
store directory (`DNM_STORE_DIR`) as described there.

## License

MIT. See [LICENSE](LICENSE).
