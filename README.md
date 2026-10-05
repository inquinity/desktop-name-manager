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

A label is one line of 1 to 30 characters (emoji are fine). You must be on the Desktop you
want to label: macOS lets an app change only the Desktop currently on screen.

| Command | What it does |
|---|---|
| `dnm set <label>` | Label the current Desktop. Options: `--style plain\|halo\|frosted`, `--color light\|dark\|#RRGGBB`, `--position bottom-left\|bottom-right\|top-left\|top-right\|bottom\|top`, `--size small\|medium\|large`. Anything left out is chosen from the wallpaper or uses its default. |
| `dnm remove` | Remove the label and restore the original wallpaper exactly. |
| `dnm undo` | Undo the last change on a display, for 30 minutes (one level). |
| `dnm show` | Show the label on the current Desktop. |
| `dnm list` | List labeled Desktops and the current Desktop of each display. Only those are shown. |
| `dnm displays` | List the connected displays, as `--display` accepts them. |

`--display <name>` picks another display: its name as macOS shows it, or part of the name if
it matches only one display. `main` always works, and it is the default. `show`, `list` and
`displays` accept `--json`.

Exit codes: `0` success; `1` failure (for example macOS denied access to the wallpaper file,
or undo is not possible); `2` invalid input; `3` unsupported wallpaper (dynamic, aerial,
catalog, shuffle, or none reported). Nothing is changed when a command fails.

`dnm --version` says which build you have: a release prints the plain version (for example `0.1.0`);
any other build prints the commit it was built from (for example `0.1.0-dev+9398ae4`, with `.dirty` added if
there were uncommitted changes, and `-dev+unknown` if it was built without a stamp).

Good to know:
- The tool needs no macOS permissions and makes no network connections.
- Turn off "Show on all Spaces" in System Settings > Wallpaper first, **for every display you label**
  (the setting is per display). With it on, macOS applies the first wallpaper change to every Desktop on
  that display and makes it the default for new Desktops. `dnm set` re-applies the wallpaper a Desktop
  already shows before its first label to keep that from happening, and prints a warning with the fix if
  macOS still made the label a default. See `specs/001-labels-and-cli/known-issues.md`.
- Removing or replacing a label keeps its labeled image for 30 minutes, so `undo` works; a
  later command cleans it up.

## Status

Early. Spec 001 (labels and the `dnm` command-line tool) is being implemented; see
`specs/001-labels-and-cli/`. The menu-bar app and the other planned features are not built
yet. `prototype/` holds the proof of concept that validated the approach, and
`docs/research/` holds what testing and research found.

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
