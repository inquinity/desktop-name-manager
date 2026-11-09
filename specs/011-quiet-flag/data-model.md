# Data Model: Quiet Mode (Feature F7)

No stored data changes: the manifest stays format 3, and nothing about quiet mode is written anywhere.

## In memory, per run

- **Quiet mode** (`Bool`): on when the parsed command line has `-q` / `--quiet` (before the command name, among its
  options, or both) or when the environment has `DNM_QUIET` equal to exactly `1`. Decided once, after parsing and
  before the command runs; not changed afterwards.

## Kinds of standard-error text

| Kind | Prefix | Today | In quiet mode |
|---|---|---|---|
| Error | `dnm: ` (and the usage hint `Run \`dnm --help\` for usage.`) | every failure | printed, unchanged |
| Warning | `dnm: warning: ` | an alias overridden by a connected display's name (commands that resolve it; `dnm alias`) | held back |
| Note | `dnm: note: ` | the cleanup nudge after `set` or `remove` (spec 009) | held back, and not counted as shown |
| Message | none | from 0.3.0, the scan's progress lines, `Scanning <display>…` (spec 012 FR-016), and the scan's interrupt and failure reports | printed, unchanged |

Standard output (results, lists, `--json` documents, cleanup's description and questions) is not standard-error
text and is never affected.

A new piece of standard-error text names its kind in its spec; a warning or note goes through the same gate.

## The nudge's record

Spec 009 stores when the nudge was last shown and how large the amount was. In quiet mode the store is not asked
whether the nudge is due, so that record is not touched (the same as when standard error is not a terminal).
