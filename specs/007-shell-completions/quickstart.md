# Quickstart & Verification: Shell Completions (Feature F1)

Use a private store so no real labels or aliases are touched: `export DNM_STORE_DIR="$(mktemp -d)/s"`.

## Scenarios

1. **Script output.** `dnm --generate-completion-script zsh` and `... bash` print non-empty scripts; the bash one
   ends with `complete` lines for `dnm` and, in the release file, `desktop-name`.
2. **Callback.** `dnm alias desk` then `dnm ---completion set -- --display 4 0 dnm set x --display ''` prints
   `main`, each display name and `desk`; `dnm ---completion alias -- positional@1 3 0 dnm alias x ''` prints no
   aliases; `dnm ---completion alias -- positional@0 3 0 dnm alias --remove ''` prints `desk`.
3. **Nothing is written.** Point `DNM_STORE_DIR` at a directory that does not exist and run the callback: the
   candidates print, standard error is empty, and the directory is still not there.
4. **Simulated Tab in bash** (bash 3.2 is enough): source the script, set `COMP_WORDS`, `COMP_CWORD`,
   `COMP_LINE`, `COMP_POINT`, call `_dnm`, read `COMPREPLY` (see research R3).
5. **Release zip.** After `just publish build`, `zipinfo -1 build.noindex/release-artifacts/<v>/dnm-<v>-arm64.zip`
   lists the three `completions/` files, and the cask test checks them after install and after uninstall.
6. **Live install check** (the maintainer's Mac, after publishing): `brew install --cask inquinity/tap/desktop-name-manager`,
   open a new zsh, press Tab after `dnm `, after `dnm set x --style ` and after `dnm show --display `; the same
   for `desktop-name`; then in bash if `bash-completion@2` is set up. `brew uninstall --cask` and check the files
   are gone (reinstall afterwards).
