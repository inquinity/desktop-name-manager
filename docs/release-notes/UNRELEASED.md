
- **Shell completions for bash and zsh**, for `dnm` and `desktop-name`. Tab completes commands, options and the
  values of `--style`, `--position`, `--size` and `--color`, and `--display` offers `main`, the displays
  connected right now and your aliases; `dnm alias --remove` offers your aliases. The Homebrew cask installs
  the completion files (a new shell picks them up if it loads Homebrew's completions); without Homebrew, use
  `dnm --generate-completion-script zsh|bash`. See the README.
