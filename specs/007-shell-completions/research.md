# Research: Shell Completions (Feature F1)

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## R1. Mechanism: the parser's generated scripts with custom callbacks

- `swift-argument-parser` 1.8.2 (already pinned and reviewed) generates completion scripts for zsh, bash and fish
  (`dnm --generate-completion-script <shell>`; 227, 327 and 153 lines for this tool). It also supports
  `completion: .custom { arguments, index, prefix in [String] }` on arguments and options, and fixed lists with
  `.list([...])`.
- A fixed list is written into the script when it is generated. A custom completion makes the script call back
  into the program: `<typed command> ---completion <subcommand> -- <option or positional@N> <word index>
  <cursor index> <words...>`; the program prints one candidate per line (checked 2026-10-09 on the debug build,
  e.g. `dnm ---completion set -- --display 4 0 dnm set x --display ''`).
- Both scripts call the command name the user typed (`COMP_WORDS[0]` in bash, `${command_name}` in zsh), so the
  second name `desktop-name` (the same program) works once its name is registered with the script's function.
- Rejected: a hand-written script per shell (we would own, test and keep in step every command and option);
  a separate completion helper binary (a second thing to sign and notarize).

## R2. What the callback may touch

- The display list is `SystemWallpaperSystem.displays()`, the same public interface as `dnm displays` (about
  20 ms measured), and the aliases come from `DesktopLabeler.aliases()`, which reads the manifest and never
  creates the store (spec 006). Neither needs a permission or a network.
- Verified 2026-10-09: with `DNM_STORE_DIR` pointing at a directory that does not exist, the callback prints the
  display candidates and the directory is still not created.
- Errors: every failure path is `try?` and offers nothing, so no message can land in the user's command line.

## R3. Shells and registration

- **zsh**: the generated file starts with `#compdef dnm` and runs when found on `fpath` (or registers with
  `compdef` when sourced). The second name needs its own file: `#compdef desktop-name` followed by a call to
  `_dnm "$@"`. compinit autoloads every `#compdef` function, so `_dnm` is available from that file.
- **bash**: the generated file ends with `complete -o filenames -F _dnm dnm`. The second name is one more line,
  `complete -o filenames -F _dnm desktop-name`, appended to the same file. `-o filenames` makes bash quote
  candidates that contain spaces ("Built-in Retina Display").
- The generated bash script was run under the macOS system bash 3.2.57 with a simulated Tab (setting
  `COMP_WORDS`, `COMP_CWORD`, `COMP_LINE` and `COMP_POINT` and calling `_dnm`): commands, `--style` values and
  `--display` candidates were produced. Real interactive Tab in bash 4+ with `bash-completion@2`, and in zsh, is
  part of the live check (quickstart).

## R4. Delivery

- The cask artifacts `zsh_completion` and `bash_completion` install a file from the staged download into
  Homebrew's completion folders and remove it on uninstall. The release zip therefore needs the files, generated
  from the binary being released (so a script never describes another version).
- The zip is checked for exactly its expected files (spec 005, FR-005; `release.sh` build stage), so that list
  gains `completions/_dnm`, `completions/_desktop-name` and `completions/dnm.bash`.
- Homebrew's documentation for shell completion is the reference for what the user's shell must load.
