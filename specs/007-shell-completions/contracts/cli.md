# Contract: Shell Completions

**Feature**: F1 | **Spec**: [spec.md](../spec.md)

## 1. What Tab offers

| Position | Offered | Source |
|---|---|---|
| `dnm <Tab>` | commands, `--help`, `--version` | generated |
| `dnm <command> -<Tab>` | the command's options | generated |
| `--style` | `plain` `halo` `frosted` | `Look.allCases` |
| `--position` | `bottom-left` `bottom-right` `top-left` `top-right` `bottom` `top` | `Position.allCases` |
| `--size` | `small` `medium` `large` | `Size.allCases` |
| `--color` | `light` `dark` | fixed (a `#RRGGBB` value is typed) |
| `--display` (`set`, `remove`, `undo`, `show`) | `main`, connected display names, usable aliases | live, `DisplayResolver.completionCandidates(includeAliases: true)` |
| `dnm alias <name>` | nothing (a new name) | |
| `dnm alias --remove <name>` | every stored alias | live, stored aliases |
| `dnm alias <name> <display>` | `main`, connected display names | live, `includeAliases: false` |
| `--desktop`, labels, `--json` values | nothing | |

Candidates are one per line, in this order: `main`, displays in the order macOS lists them, then aliases sorted
by name ignoring case. Duplicates (ignoring case) appear once. Control characters are replaced. A usable alias
is one whose display is connected and that no connected display's own name overrides (spec 006).

## 2. The callback

The scripts run `<typed command name> ---completion <subcommand> -- <option or positional@N> <word index>
<cursor index> <words...>`. This is the parser's internal convention, not a user feature; it is not stable and
is not documented in `--help`. On success it prints the candidates and exits `0`. On any failure it prints
nothing, writes nothing to standard error, and exits `0`. It never creates or writes the store.

## 3. Printing the scripts

`dnm --generate-completion-script zsh|bash|fish` prints the script to standard output (the parser's built-in
option, listed in `--help`). It is the way to install completions without Homebrew.

## 4. Release artifacts

The release zip holds, besides the files of spec 005:

```text
completions/_dnm            zsh, from `dnm --generate-completion-script zsh`
completions/_desktop-name   zsh, `#compdef desktop-name` followed by `_dnm "$@"`
completions/dnm.bash        bash, the generated script plus `complete -o filenames -F _dnm desktop-name`
```

The release `build` stage generates them from the release binary and fails if one is missing, empty, or does
not register both command names. The cask:

```ruby
zsh_completion "completions/_dnm"
zsh_completion "completions/_desktop-name"
bash_completion "completions/dnm.bash", target: "dnm"
```

The cask test installs the cask from the temporary tap, checks that the three files exist in Homebrew's
completion folders and that uninstalling removes them.
