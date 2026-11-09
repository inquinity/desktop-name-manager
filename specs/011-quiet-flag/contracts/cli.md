# CLI Contract: Quiet Mode (Feature F7)

Amends `specs/001-labels-and-cli/contracts/cli.md` (streams, short options), `specs/006-display-aliases/spec.md`
FR-012 and the nudge rules of `specs/009-stamp-reuse-and-cleanup/spec.md`. `desktop-name` behaves identically.

## 1. The option

```text
dnm [-q | --quiet] <command> [<command options and arguments>] [-q | --quiet]
```

- `-q` and `--quiet` are the same flag. They are accepted before the command name, anywhere among the command's own
  options and arguments, or both; repeating them is not an error.
- Every command accepts them: `set`, `remove`, `undo`, `show`, `list`, `displays`, `alias`, `cleanup`, `prune`
  (which still fails with its message naming `cleanup`), `about`, `check`, and `dnm` itself with `--help` or
  `--version`.
- `-q` is the second short option of the tool, after `-h` (decision recorded here, as the short-options rule
  requires).
- Help, for `dnm --help` and each command's `--help`:

  ```text
  -q, --quiet             Hide warnings and notes; results and errors are always shown. DNM_QUIET=1 does the
                          same.
  ```

## 2. The environment variable

- `DNM_QUIET=1` turns quiet mode on for every command, as `-q` does.
- Any other value (unset, empty, `0`, `true`, ...) leaves quiet mode off; it is never an error.
- There is no option to turn quiet mode off; unset the variable instead.

## 3. What quiet mode holds back

| Standard-error text | Example | Quiet mode |
|---|---|---|
| Warning | `dnm: warning: DP1 is a connected display, which overrides alias DP1 (Studio Display).` (commands that resolve `DP1`); `dnm: warning: alias DP1 is not used while a display named DP1 is connected.` (`dnm alias`) | not printed |
| Note | `dnm: note: about 60 MB (2 labels) of old labeled images could be freed: run dnm cleanup.` | not printed; not counted as the weekly showing |
| Error and usage hint | `dnm: No display matches "NOPE". ...`, `Run \`dnm --help\` for usage.` | printed, unchanged |

## 4. What quiet mode never changes

- Standard output, byte for byte, including `--json` documents, `dnm alias`'s `(overridden by connected display …)`
  marker, `dnm check`'s rows, and `dnm cleanup`'s description, plain warning sentence and questions.
- Exit statuses.
- What a command does: labels, wallpapers, stored records, undo records.
- The part-way failure message of a several-display command (spec 010), with the displays already changed and the
  undo to run: it is an error.

## 5. Streams rule (spec 001, amended)

Results on standard output; messages, warnings, notes and errors on standard error. With `--json`, standard output
holds exactly one JSON document and nothing else. In quiet mode, warnings (`dnm: warning: `) and notes
(`dnm: note: `) are not printed; errors always are.

## 6. Completion

The generated bash and zsh scripts offer `-q` and `--quiet` before the command name and for every command; after a
leading `-q`, command names and each command's options and values complete as without it.
