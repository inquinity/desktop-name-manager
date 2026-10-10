# Contract: the `desktop-name-manager` cask

Rendered by `scripts/release.sh <version> cask` from `packaging/desktop-name-manager.rb.template` into
`Casks/desktop-name-manager.rb` in the tap. Required content:

| Stanza | Value | Why |
|---|---|---|
| `version` | the release version | FR-009 |
| `sha256` | the zip's SHA-256 | FR-009; Homebrew refuses a mismatch |
| `url` | `https://github.com/inquinity/desktop-name-manager/releases/download/v#{version}/dnm-#{version}-arm64.zip` | FR-007, FR-009 |
| `name` | `Desktop Name Manager` | |
| `desc` | one line describing what it does | Homebrew audit |
| `homepage` | `https://github.com/inquinity/desktop-name-manager` | |
| `livecheck` | `url :url`, `strategy :github_latest` | FR-009 (detect new versions) |
| `depends_on macos:` | `:tahoe` (macOS 26 or later) | FR-009, FR-012 |
| `depends_on arch:` | `:arm64` | FR-009, FR-012 (Apple silicon only for 0.1.0) |
| `binary` | `"dnm"` and `"dnm", target: "desktop-name"` | both commands on the PATH (FR-009) |
| `zsh_completion`, `bash_completion` | `"completions/_dnm"`, `"completions/_desktop-name"`, and `"completions/dnm.bash", target: "dnm"` | shell completions from 0.1.2 (spec 007) |
| `caveats` | the Accessibility note (security plan S1) and where full removal is documented | FR-015 |

Must not contain:

- a `zap` stanza (stored data is never removed automatically, FR-015);
- any credential, personal path, user name or identifier (FR-019);
- anything that changes the tap's README (FR-010).

Acceptance: `brew audit --cask --strict --online` passes in a temporary local tap, and installing it there
gives working `dnm --version` and `desktop-name --version` with the same output, the three completion files in
Homebrew's `share/zsh/site-functions` and `etc/bash_completion.d`, and uninstalling removes them, before
anything is pushed (FR-011). The test installs and uninstalls the cask under its real name, so the `cask` stage
refuses to run while the cask is installed on that Mac.
