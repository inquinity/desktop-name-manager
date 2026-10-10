# Contract: `dnm alias` and Display Options

**Feature**: F2 — Display Aliases | **Spec**: [spec.md](../spec.md)

## 1. Syntax

```text
dnm alias <name> [<display>]
dnm alias --remove <name>
dnm alias [--json]
```

### Modes

| Invocation | Action |
|---|---|
| `dnm alias <name> [<display>]` | Sets or updates alias `<name>` to point to `<display>`. If `<display>` is omitted, targets the main display. |
| `dnm alias --remove <name>` | Removes the alias `<name>`. (A short `-d` existed in 0.1.1; removed in 0.2.0, spec 008.) |
| `dnm alias` | Lists all configured aliases in human-readable columns. |
| `dnm alias --json` | Lists all configured aliases as one JSON object. |

`--json` with a name, or `--remove` with a display, is invalid input (exit `2`).

---

## 2. Validation & Exit Codes

### Alias Name Rules
* 1 to 30 characters.
* Allowed characters: ASCII alphanumeric (`A-Z`, `a-z`, `0-9`), hyphens (`-`), underscores (`_`).
* **Forbidden names** (exit `2`):
  * `main` (case-insensitive): `dnm: main is reserved and cannot be used as an alias.`
  * Only digits (e.g., `1`, `12`): `dnm: An alias cannot be only digits, because --display does not accept numbers.`
  * Names containing spaces or special characters (`$`, `\`, quotes, etc.): `dnm: Alias names cannot contain spaces or special characters. Use letters, numbers, hyphens, or underscores.`
  * Empty: `dnm: An alias name cannot be empty.`
  * Longer than 30 characters: `dnm: Alias names can be at most 30 characters.`
  * Any name matching a currently connected display (case-insensitive): `dnm: <display-name> is already the name of a connected display and cannot be used as an alias.`

### Display Targeting Rules
* `[<display>]` is resolved by the same algorithm as `--display` (§4), in display-only mode. It accepts:
  * `main` (the primary display).
  * An exact display name as macOS shows it (case-insensitive).
  * A minimum-unique partial display name (case-insensitive).
  * Not another alias.
* If ambiguous (matches multiple displays, including two displays with the same name): exits `2` with candidates listed.
* If no match: exits `2` with connected displays listed.
* If the display has no stable identity: exits `2`: `dnm: <display> has no stable identity that macOS keeps across reconnects, so it cannot have an alias.`
* If another connected display reports the same identity: exits `2`: `dnm: <display> and <other> report the same identity to macOS, so an alias could point at either. Nothing was changed.`

### Exit Codes

| Code | Condition |
|---|---|
| `0` | Success (alias created, updated, moved, removed, or listed). |
| `1` | Store failure (cannot write `manifest.json`, disk full, permission denied, manifest newer than this tool). |
| `2` | Invalid input (bad alias name, name matches connected display, unknown/ambiguous target display, display without a stable or unique identity, nonexistent alias on `--remove`, `--json` with a name). |

---

## 3. Output Formatting & Streams

### Quoting Rules
* Messages print alias names and display names **without quotes** (FR-014).

### Messages on stdout

* **Set alias**:
  ```text
  Aliased DP1 to LG Ultra HD.
  ```
* **Set alias on main display**:
  ```text
  Aliased desk to Built-in Retina Display (main).
  ```
* **Set again, same display** (idempotent): the same `Aliased …` message.
* **Move alias to another display**:
  ```text
  Moved alias DP1 from LG Ultra HD to Studio Display.
  ```
  (`(main)` follows the new display's name when it is the main display, as in the line above.)
* **Remove alias**:
  ```text
  Removed alias DP1.
  ```
* **No aliases** (bare `dnm alias`):
  ```text
  No aliases. Set one with: dnm alias <name> [<display>]
  ```

### List Output (`dnm alias`)

Columns are aligned; a disconnected display is shown by its recorded name, or by its identity when no name is
recorded:

```text
desk  Built-in Retina Display  (main)
DP1   LG Ultra HD
work  LG Ultra HD
old   Studio Display           (not connected)
dp2   LG Ultra HD              (overridden by connected display DP2)
```

If an alias is overridden, a diagnostic notice is printed to stderr:
```text
dnm: warning: alias dp2 is not used while a display named DP2 is connected.
```

### JSON Output (`dnm alias --json`)

One object, like every other `--json` output:

```json
{
  "aliases": [
    {
      "name": "desk",
      "display": "Built-in Retina Display",
      "connected": true,
      "isMain": true,
      "overridden": false
    },
    {
      "name": "old",
      "display": "Studio Display",
      "connected": false,
      "isMain": false,
      "overridden": false
    },
    {
      "name": "dp2",
      "display": "LG Ultra HD",
      "connected": true,
      "isMain": false,
      "overridden": true,
      "overriddenBy": "DP2"
    }
  ]
}
```

`display` is the connected display's name, else the recorded name, else the identity. `isMain` is `false`
when the display is not connected.

---

## 4. Updates to `--display <value>`

Every command accepting `--display <value>` (`set`, `remove`, `undo`, `show`) evaluates `<value>` with the one resolution algorithm, in full mode, in this order (display-only mode, used by `dnm alias`, skips step 4):

1. Empty / `main` → Main display.
2. Only digits → Rejected (exit `2`).
3. **Exact connected display name** → Returns the connected display (exit `2` if several displays have that name).
   * *If an alias with the same name exists, emits stderr warning*:
     ```text
     dnm: warning: DP1 is a connected display, which overrides alias dp1 (LG Ultra HD).
     ```
4. **Exact alias** (case-insensitive; aliases are never matched partially) →
   * Target display connected → Returns that display.
   * Target display not connected → Exits `2`: `dnm: The display aliased as DP1 is not connected.`
5. **Minimum-unique partial display name** → Matches uniquely among connected displays. Only display names are matched partially: `--display des` does not find the alias `desk`.

Because step 4 comes before step 5, an alias such as `LG` resolves to its own display even when `LG` is part of
several connected display names (`LG Ultra HD`, `LG UltraFine`); it is never reported as ambiguous.

---

## 5. Updates to `dnm displays`

* **Text format**: active (not overridden) aliases follow the name and the main marker.
  ```text
  Built-in Retina Display  (main)  aliases: desk
  LG Ultra HD                      aliases: DP1, work
  Studio Display
  ```
* **JSON format (`dnm displays --json`)**: every display has an `aliases` array.
  ```json
  {
    "displays": [
      { "name": "Built-in Retina Display", "isMain": true, "aliases": ["desk"] },
      { "name": "LG Ultra HD", "isMain": false, "aliases": ["DP1", "work"] },
      { "name": "Studio Display", "isMain": false, "aliases": [] }
    ]
  }
  ```

F1 (shell completions) offers these names and aliases for `--display`.

---

## 6. Updates to `dnm check`

A new **Aliases** row after **Displays**:

* No aliases: information, `None set.`
* All fine: `ok`, for example `3 aliases; 1 for a display not connected now.`
* An overridden alias: `fix`, naming it and the display that overrides it, with how to fix it (`dnm alias --remove <name>`, or set it under another name).
