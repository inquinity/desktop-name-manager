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

## Install

With [Homebrew](https://brew.sh), on macOS 26 or later with Apple silicon (Intel Macs are not supported
yet):

```sh
brew tap inquinity/tap
brew trust --tap inquinity/tap   # Homebrew 7 and later load casks only from taps you trust
brew install --cask inquinity/tap/desktop-name-manager
```

This installs `dnm` and the same tool as `desktop-name`. The release is signed and notarized by Apple; the
first run needs a network connection once, for macOS's notarization check, and after that the tool works
offline and never connects to the network. To check a download yourself, follow the steps in its
[release notes](https://github.com/inquinity/desktop-name-manager/releases).

To build from source instead (Xcode 27 command-line tools): `just build-release`, then use
`build.noindex/release/dnm`.

## Try it

```sh
dnm set "Status Report"   # label the Desktop you are on
dnm set DP "Status Report"  # the Desktop showing on the display named DP
dnm remove                # put the original wallpaper back
```

A label is one line of 1 to 30 characters (emoji are fine). Commands act on the Desktop on
screen, because macOS lets an app change only that one; `--desktop <n>` switches to another
Desktop for you (see below).

| Command | What it does |
|---|---|
| `dnm set [<display>] <label>` | Label the current Desktop (of the main display, or of the display you name first; add more with `--display`). Options: `--style plain\|halo\|frosted`, `--color light\|dark\|#RRGGBB`, `--position bottom-left\|bottom-right\|top-left\|top-right\|bottom\|top`, `--size small\|medium\|large`. Anything left out is chosen from the wallpaper or uses its default. |
| `dnm remove [<display> ...]` | Remove the label and restore the original wallpaper exactly. |
| `dnm undo [<display> ...]` | Undo the last change on each display named, for 60 seconds (one level). |
| `dnm show [<display>]` | Show the label on the current Desktop. |
| `dnm list` | List labeled Desktops and the current Desktop of each display. Only those are shown. |
| `dnm displays` | List the connected displays, as `--display` accepts them, with their aliases. |
| `dnm alias` | Give a display a short name for `--display`: `dnm alias <name> [<display>]`. Without arguments it lists the aliases; `--remove <name>` deletes one. |
| `dnm cleanup` | Find old labeled images no Desktop is known to show, describe them, and delete them when you agree (`--days N`, `--yes`). |
| `dnm cleanup --scan` | Visit every Desktop of every connected display, then list the labels no Desktop shows and delete them when you agree (needs Accessibility). |
| `dnm about` | Version, where data is kept, and what permissions the tool uses and why. |
| `dnm check` | How this Mac is set up for labels and `--desktop`, and how to fix what is missing. |

`show`, `list`, `displays`, `alias`, `cleanup`, `about` and `check` accept `--json`.

## Choosing a display

The display comes first: `dnm set DP "Mail"`, `dnm show DP`, `dnm remove DP`, `dnm undo DP`. A display is `main`
(the default), a display's name as macOS shows it, an alias (below), or the beginning of a name that matches only one
display (`LG Ultra` for `LG Ultra HD`, not `Ultra` or `HD`). Quote a name with spaces:

```sh
dnm set "LG Ultra" "My label is great"   # the beginning of the display's name, then the label
dnm set main "Notes"                     # the main display, said outright
dnm set "Notes"                          # the same: one word is the label for the main display
dnm set lg "Mail"                        # an alias avoids the quotes
```

- **One word or two.** With two words to `set`, the first is the display and the second the label; with one, it is
  the label for the main display. More than that is an error that says what to type (`set` takes a label, or a
  display and a label; quote anything with spaces). `remove` and `undo` take any number of displays; `show` takes
  one.
- **A lone word that is a display is refused.** `dnm set DP` is probably a label forgotten after the display, so
  `dnm` stops and shows both ways: `dnm set DP "<label>"` to label that display, and `dnm set --label DP` to use
  `DP` as the label. This covers exactly `main`, a display's full name and an alias, ignoring case; a part of a
  name (`dnm set LG`) is a label. The same goes for a label that equals an alias: write `dnm set --label desk`.
- **`--label` names the label outright** (`dnm set DP --label "Mail"`), and then the only word is the display. A
  label that starts with a dash is written `--label=-x`.
- **`--display` still works** (`dnm set "Mail" --display DP`) and is the explicit form for scripts, together with
  `--label`: whether a lone word is refused depends on the displays connected and the aliases you have, which the
  flags do not. Naming the same display twice (a word and `--display`, or a name and its alias) is one display.
- **Several displays.** `set`, `remove` and `undo` act on every display named, in order: the display words first,
  then each `--display`. `set` takes one display word, so add the others with `--display`:

  ```sh
  dnm set main "Mail" --display DP   # label the current Desktop of both displays
  dnm remove main DP                 # and remove both labels
  dnm undo main DP                   # undo the last change on each, within 60 seconds
  ```

  Every display is checked first, so a typo, an invalid label or a display with nothing to undo changes nothing. If a
  display fails part-way (its wallpaper is not supported, say), the command stops there: the displays before it stay
  changed, and the error names them and the `dnm undo` that puts them back. With `--desktop N`, each display's
  Desktop N is labeled in turn. `show` stays one display (its `--json` is one document) and refuses two with
  "Multiple displays for a single command are not currently supported."
- **Order.** Options may come before, between or after the words; the examples put the display first because it
  reads best.

## Display aliases

A long monitor name is tedious to type. Give it a short one:

```sh
dnm alias desk                     # the main display
dnm alias dp "LG Ultra HD"         # a display, by its name or part of it
dnm set dp "Mail" --desktop 2
dnm alias                          # list; dnm alias --remove dp deletes
```

`dnm alias` reads like a shell alias: the new name first, then what it stands for. `set` reads display, then
label.

An alias is 1 to 30 letters, digits, hyphens or underscores (not only digits, and not `main`). It is matched
in full, ignoring case, never partially. A display is looked up, in order, as `main`, a display's exact name,
an alias, then the beginning of a name (case-insensitive) that only one display's name starts with. So a connected display's own name wins over an alias of the same
name (say you alias `DP1` to the LG and then plug in a monitor called `DP1`): `DP1` reaches the
monitor, with a warning (hide it with `-q`, see [Quiet mode](#quiet-mode)), and `"LG Ultra"` still reaches the
LG. `dnm alias` and `dnm check` flag such an alias. `dnm` refuses to alias a display that macOS gives no stable identity, or two displays that
share one. Aliases are kept in the store, so they follow the display, not its name. They make the stored
data format 2, which 0.1.0 cannot read.

## Quiet mode

`-q` (or `--quiet`) hides warnings and notes: the lines that start `dnm: warning:` or `dnm: note:`, such as the
warning for an alias that a display's name overrides, or the cleanup reminder. Results and errors are always shown,
so unlike `2>/dev/null` it never hides a real problem. It goes before or after the command name, and works with every
command:

```sh
dnm -q set DP1 "Mail"
dnm show DP1 --quiet
export DNM_QUIET=1                 # quiet for every command in this shell or script
```

`DNM_QUIET` must be exactly `1`; any other value leaves quiet mode off. A cleanup reminder held back by quiet mode is
not used up: the next run without it shows the reminder if it is still due. `dnm alias` still marks an overridden
alias in its list, and `dnm check` still reports it.

## Shell completions

Tab completes `dnm` and `desktop-name` in zsh and bash: commands, options, the values of `--style`,
`--position`, `--size` and `--color`, and, for `--display`, `main`, the displays connected right now and your
aliases, as git completes branch names. `dnm alias --remove` completes your aliases. Completion only reads: it
needs no permission, never creates the store, and prints nothing if something is wrong.

With Homebrew the completion files come with the cask and go with it. Your shell has to load Homebrew's
completions, as for any Homebrew program (see Homebrew's
[shell completion](https://docs.brew.sh/Shell-Completion) page: in zsh, Homebrew's `site-functions` folder
on `fpath` before `compinit`; in bash, `bash-completion@2`). Open a new shell after installing. zsh keeps a
cache of the completions it found: if Tab still completes file names, rebuild it with `rm -f ~/.zcompdump*; compinit`
(a `.zshrc` that runs `compinit -C` never rescans, so it needs this after every new completion).

Without Homebrew, print the script and load it yourself:

```sh
dnm --generate-completion-script zsh > ~/.zfunc/_dnm     # a folder on your fpath
dnm --generate-completion-script bash > ~/.dnm-completion.bash && echo 'source ~/.dnm-completion.bash' >> ~/.bashrc
```

## Cleaning up

Deleting a Desktop in Mission Control is something `dnm` is never told about, so its label stays in the store
(and in `dnm list`), with its image, about 2 to 6 MB each. Two things keep that in check:

- **Reuse.** Label a new Desktop the way an old one was labeled (same wallpaper, text, options and display) and `dnm`
  uses the existing image instead of making another, so deleting and recreating Desktops adds nothing.
- **`dnm cleanup`** finds the labeled images that no Desktop is known to show and that were removed, replaced or last
  seen at least 30 days ago (`--days N` for another age; `--days 0` for everything no Desktop shows now). It lists them
  with why and how old, says plainly that **a Desktop that is not on screen now might still show one of them**,
  including a Desktop on a display that is not connected (it would fall back to the Mac's default wallpaper until you
  choose another or label it again), and asks before deleting. With
  no terminal it only describes, unless you pass `--yes`. `--json` prints the list. A change made moments ago can no
  longer be undone once cleanup has deleted the image it would bring back. Nothing is ever deleted unless you
  agree: no command cleans up by itself. After a label is set or removed, on a terminal, `dnm` may add one line
  (at most weekly) when 50 MB or more could be freed; quiet mode (`-q`) holds it back.

"Seen" means a label's image was showing on a Desktop when a command that changes labels (`set`, `remove`, `undo`,
`cleanup`) looked; commands that only read, like `list` and `show`, change nothing. `dnm check` says how much
`cleanup` could free.

### Scanning every Desktop

`dnm cleanup` guesses by age because it can see only the Desktop showing on each display. **`dnm cleanup --scan`**
looks instead: it visits every Desktop of every connected display, as `--desktop` does, notes which labeled image
each one shows, and lists the labels that no Desktop shows, whatever their age.

- It needs the Accessibility permission, like `--desktop` (see `dnm check`), and asks before it starts. The Desktops
  slide by and the pointer moves, about 2 seconds per Desktop; do not type until it is done. Each display returns to
  the Desktop it started on, and the pointer to where it was.
- It lists each label no Desktop showed (display, text, size, when it was last seen) and asks again before deleting.
  `--yes` answers both questions; with no terminal and no `--yes` it only describes what it would do. `--json`
  prints one document (with `--yes`, after scanning and deleting).
- Labels of displays that are not connected are left alone and named (`Not checked: …`), because their Desktops
  cannot be seen.
- Ctrl-C during the scan returns the display to its Desktop, deletes nothing and exits 130; a second Ctrl-C stops
  at once.
- On a Mac with one display and one Desktop, or with the "Move left a space" and "Move right a space" shortcuts
  off, nothing moves and the scan cannot tell the two apart; it stops and deletes nothing. `dnm cleanup` still works.

Prefer the scan when you have deleted Desktops recently and want an exact answer; the age-based `cleanup` needs no
permission and does not move anything. If you move your Mac between display arrangements (for example two and three
monitors), each arrangement keeps its own Desktops, and the scan sees only the one connected now: a label it offers
to delete may still be used by a Desktop of another arrangement (known issue KI-2).

## Label sets of Desktops

`set`, `remove`, `undo` and `show` accept `--desktop <n>`: the Nth Desktop of the display, numbered as
Mission Control numbers them. A script can then label the same position on every display:

```sh
dnm set main "Mail"     --desktop 2
dnm set DP   "Mail"     --desktop 2
dnm set main "Projects" --desktop 3
dnm set DP   "Projects" --desktop 3
```

In a script, prefer the explicit form, which cannot be misread: `dnm set --display DP --label "Mail" --desktop 2`.

What you see: the display slides to that Desktop, the label is applied, and it slides back to the
Desktop it started on. The pointer moves to that display and returns. Don't type or move the pointer while it runs:
the shortcuts act on the display under the pointer.

`--desktop` is opt-in and needs two things, which `dnm check` reports:
- **Accessibility** for the app you run `dnm` from (your terminal): System Settings > Privacy &
  Security > Accessibility on macOS 26, or **Device Control and Data Access** on macOS 27 (which has no
  Accessibility item there). Quit and reopen the app after turning it on. macOS gives apps no public way to switch Desktops, so `dnm` presses
  macOS's own "Move left a space" and "Move right a space" shortcuts. Nothing else is typed or read.
  `dnm` never asks for the permission itself; without it, `--desktop` stops and changes nothing.
  **Know what you are granting:** a command-line tool has no app of its own, so macOS gives the permission
  to the terminal app, and every program you run in that terminal can then send keystrokes and clicks
  too. Grant it only if you need `--desktop`, consider a separate terminal app just for it, and turn it
  off when you no longer need it. The planned menu-bar app will hold the permission itself, so the
  terminal will not need it.
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

`dnm --version` says which build you have: a release prints its version and build number (for example
`0.2.2 build 6`); any other build adds the commit it was built from (for example `0.2.2 build 7 (9398ae4)`,
with `+` if there were uncommitted changes). A build without a stamp says so.

Good to know:
- Labeling the Desktop on screen needs no macOS permissions; only `--desktop` needs Accessibility.
  The tool makes no network connections and collects no telemetry.
- A new Desktop starts with a copy of the wallpaper of the **left-most** Desktop on its display (hover over
  + in Mission Control to see it), label included. To choose what new Desktops start with, drag a
  different Desktop to the left-most place in Mission Control; to change one new Desktop, run `dnm set` or
  `dnm remove` on it. Tip: leave the left-most Desktop unlabeled, so new Desktops always start clean.
  See `docs/research/desktop-association.md`.
- For the same reason one labeled image can be on several Desktops, so removing or replacing a label
  never deletes its image; `dnm cleanup` does that later, when you ask (see "Cleaning up" below).

## Uninstall

```sh
brew uninstall --cask desktop-name-manager
```

This removes `dnm` and `desktop-name`. Your wallpapers stay exactly as they are, labeled ones included, and
so do `dnm`'s stored labels, in case you reinstall.

**Full removal.** A labeled Desktop shows an image from `dnm`'s storage, so deleting that storage would
leave such Desktops without their picture. To remove everything:

1. Before uninstalling, run `dnm remove` (with `--display` or `--desktop` as needed) on each Desktop whose
   label you want gone, then `dnm cleanup --days 0 --yes` to delete every labeled image that no Desktop on screen
   shows. That includes the images of labeled Desktops you skipped that are not on screen: they fall back to the
   Mac's default wallpaper until you choose another.
2. Uninstall as above.
3. Delete the storage folder: `~/Library/Application Support/com.altmansoftwaredesign.desktop-name-manager`.

Homebrew never deletes that folder itself.

## Status

Early. The command-line tool (spec 001, `specs/001-labels-and-cli/`) is built and its first preview
release, 0.1.0, is being prepared (spec 005, `specs/005-packaging-and-release/`). The menu-bar app and the other planned features are not built
yet. `prototype/` holds the proof of concept that validated the approach, and
`docs/research/` holds what testing and research found. The build order and the MVP are in
[ROADMAP.md](ROADMAP.md).

## Development

```sh
just build        # build the library and the tool (output goes to build.noindex/, not .build/); adds one to the build number
just test         # unit and contract tests (they never change your real wallpaper)
just build-release  # optimized build: build.noindex/release/dnm (a new build number, the version and commit are stamped in)
just version      # the version and build number from Version.xcconfig, e.g. "0.2.2 build 6"
just bump <s>     # start a different next version (major, minor or revision); a release already moves to the next revision
just release      # cut a release of the version in Version.xcconfig: new build number, notes, commit, signed tag
just publish <stage> [--confirm]  # run a stage of scripts/release.sh for that version (see spec 005)
just periphery    # unused-code scan (needs `brew install periphery`)
just kit          # assemble the live-test kit to copy to another Mac
```

Without `just`, add `--scratch-path build.noindex` to `swift build` and `swift test`.

Live checks change your real wallpaper. They are listed in
`specs/001-labels-and-cli/quickstart.md`; back up the wallpaper store first and use a private
store directory (`DNM_STORE_DIR`) as described there.

## License

[MIT](LICENSE). The download carries the notices of the third-party code compiled into `dnm`, in
`Licenses/`. [Acknowledgements](Acknowledgements.md), also shown by `dnm about`, lists each component and
the license it is used under, linked to that license at the version that ships.
