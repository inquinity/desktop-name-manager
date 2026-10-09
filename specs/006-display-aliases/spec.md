# Feature Specification: Display Aliases (Feature F2)

**Feature Directory**: `specs/006-display-aliases`

**Created**: 2026-10-08

**Status**: Draft (reviewed 2026-10-08)

**Target release**: 0.1.1, before shell completions (F1)

**Input**: User description: "Display aliases: short names for displays, tied to the display's identity (backlog). Comes before F1 (shell completions). Allows users to assign short, friendly names to displays (e.g. `dnm alias DP1 \"LG Ultra HD\"`)."

## Clarifications

### Session 2026-10-08

- **Q: How should the CLI syntax for managing aliases be structured?**
  - **A**: Positional command with flags:
    - `dnm alias <name> [<display>]` to set or update an alias (defaults to `main` display if omitted).
    - `dnm alias --remove <name>` (or `-d <name>`) to delete an alias.
    - Bare `dnm alias` (with no arguments) to list current aliases.
    - `--json` applies to the listing only.
- **Q: How does `dnm` match display names when assigning an alias?**
  - **A**: Public interfaces only. Matching supports `main`, exact display name, and minimum-unique-string partial matching (e.g., `LG Ultraf` matches `LG UltraFine` vs `LG Ultra HD`). Matching is case-insensitive, and strings with embedded spaces require quotes. Discovering cursor position or active display via private APIs is rejected.
- **Q: Can a display have more than one alias?**
  - **A**: Yes. A display can have multiple aliases (many-to-one: distinct alias names mapping to the same display identity). Each alias name is unique, case-insensitively. Repeating `dnm alias <name> <display>` updates the association and succeeds idempotently without error.
- **Q: What syntax rules apply to alias names?**
  - **A**: 1 to 30 characters. Allowed characters: ASCII alphanumeric, hyphens (`-`), and underscores (`_`). Forbidden: spaces, characters with special meaning (`\`, `$`, `"`, `'`, `/`, `*`, `?`, `~`, `|`, `;`, `&`, `(`, `)`), names made only of digits (`1`, `2`, `10`), and the reserved word `main`. Matching is case-insensitive; the capitalization last typed is what is stored and shown.
- **Q: Can an alias match a connected display name?**
  - **A**: No. At creation time, `dnm alias <name>` refuses if `<name>` matches any currently connected display name (exit code 2).
- **Q: What happens if an alias exists and a display with that name connects later?**
  - **A**: The connected display's name takes precedence over the alias. The alias becomes shadowed and inactive while that display is connected. A warning is emitted when listing aliases (`dnm alias`), when resolving `--display` using that name, and in `dnm check`.
- **Q: How should output be quoted?**
  - **A**: Messages print alias names and display names without quotes (e.g., `Aliased DP1 to LG Ultra HD.`). Revisit if this proves confusing.
- **Q: Where are aliases stored, and is storage user-modifiable?**
  - **A**: In the existing `manifest.json` under `~/Library/Application Support/com.altmansoftwaredesign.desktop-name-manager/` (or `$DNM_STORE_DIR`), not in a separate file, so the store does not fragment as the schema grows. This release writes schema version 2. It is valid JSON but not meant for manual editing: aliases bind to display identities and are managed under the store's file lock.
- **Q: How do aliases integrate with `dnm displays`?**
  - **A**: Aliases appear after the display name: `LG Ultra HD  aliases: DP1, work`. In `dnm displays --json`, each display object includes an `aliases` array (empty when it has none). Shadowed aliases are left out.

### Review 2026-10-08

- **Q: Two identical monitors report the same name. How does the user alias the second one?**
  - **A**: macOS is reported to number identical monitors in their names (`Model (1)`, `Model (2)`) and to give each its own identity from the display data and the port (research R1). `dnm` relies on that. If two connected displays still report the same name, choosing one by name stays ambiguous and alias creation is refused; that limits one unusual setup, not the feature.
- **Q: What if a display has no stable identity, or two connected displays report the same identity?**
  - **A**: `dnm alias` refuses (exit 2) and says why. An alias on an identity that can change after a reconnect would silently stop working, and one shared by two displays would pick either.
- **Q: How is an alias shown when its display is not connected?**
  - **A**: By the display name recorded when the alias was set; if no name is recorded, by the display's identity.
- **Q: What does an older `dnm` do with the new manifest?**
  - **A**: This release reads version 1 and writes version 2. An older release refuses a version 2 manifest ("newer than this tool understands"). Losing backward compatibility is an accepted risk: at 0.1 the tool has one user, who will not downgrade, so no downgrade path is provided.

---

## User Scenarios & Testing

### User Story 1 - Create and Use a Display Alias (Priority: P1)

As a user with an external monitor that has a long or awkward name (e.g., `LG UltraFine 5K Display`), I want to assign a short alias like `dp` or `desk` so that I can easily target it with `--display dp` in every command that takes `--display` (`set`, `remove`, `undo`, `show`).

**Independent Test**:
Run `dnm alias dp "LG UltraFine 5K Display"`, then run `dnm show --display dp`. The display is resolved and its current label is shown.

**Acceptance Scenarios**:
1. **Given** a connected display `LG UltraFine 5K Display`, **When** the user runs `dnm alias dp "LG UltraFine 5K Display"`, **Then** `dnm` outputs `Aliased dp to LG UltraFine 5K Display.` and records the alias with that display's identity and name.
2. **Given** no display argument is provided, **When** the user runs `dnm alias desk`, **Then** `dnm` aliases `desk` to the main display.
3. **Given** an alias `dp` mapped to a connected display, **When** the user runs `dnm set "Meeting" --display dp`, **Then** the label is applied to that display.
4. **Given** alias `dp` points to display A, **When** the user runs `dnm alias DP B`, **Then** `dnm` outputs `Moved alias DP from A to B.`, the alias points to B, and it is stored and shown as `DP`.
5. **Given** an alias `LG` and connected displays `LG Ultra HD` and `LG UltraFine`, **When** the user passes `--display LG`, **Then** the alias is used, without an ambiguity error, because an exact alias is checked before partial names.

---

### User Story 2 - List and Remove Display Aliases (Priority: P2)

As a user with configured display aliases, I want to view all defined aliases and remove ones I no longer need.

**Independent Test**:
Run `dnm alias` to view configured aliases in tabular text format and `dnm alias --json` for structured output. Run `dnm alias --remove dp` to delete an alias.

**Acceptance Scenarios**:
1. **Given** aliases `desk` and `dp` exist, **When** the user runs `dnm alias`, **Then** the tool lists each alias, its display's name, and its status.
2. **Given** the user runs `dnm alias --json`, **Then** standard output is one JSON object, `{"aliases": [...]}`, whose entries have the fields `name`, `display`, `connected`, `isMain` and `shadowed` (plus `shadowedBy` when shadowed).
3. **Given** an alias `dp` exists, **When** the user runs `dnm alias --remove dp`, **Then** `dnm` outputs `Removed alias dp.` and deletes the mapping.
4. **Given** no alias `unknown` exists, **When** the user runs `dnm alias --remove unknown`, **Then** `dnm` exits 2 with `dnm: No alias named unknown exists.`.
5. **Given** an alias whose display is not connected, **When** the user runs `dnm alias`, **Then** the alias is listed with its recorded display name (or, if none is recorded, the display's identity) and marked not connected.

---

### User Story 3 - Collision Handling and Shadowing (Priority: P3)

As a user whose display configuration changes (e.g. plugging in or unplugging monitors), I want clear safeguards when an alias collides with a connected display's name.

**Independent Test**:
Attempt to create an alias matching an active display; connect a display that matches an existing alias and observe precedence and warnings.

**Acceptance Scenarios**:
1. **Given** a connected display named `DP1`, **When** the user runs `dnm alias DP1 main`, **Then** `dnm` exits 2 with `dnm: DP1 is already the name of a connected display and cannot be used as an alias.`.
2. **Given** an alias `dp1` pointing to display A, and a display named `DP1` (display B) is currently connected, **When** the user runs `dnm alias`, **Then** `dp1` is marked `(shadowed by connected display DP1)` and a warning is printed to stderr.
3. **Given** alias `dp1` is shadowed by display B, **When** the user runs `dnm show --display dp1`, **Then** display B is targeted, and a warning is printed to stderr indicating `dp1` was shadowed.
4. **Given** a display with no stable identity, or two connected displays that report the same identity, **When** the user tries to alias it, **Then** `dnm` exits 2, says why, and stores nothing.

---

### User Story 4 - Integration with `dnm displays` and `dnm check` (Priority: P4)

As a user checking my system setup, I want `dnm displays` to surface my configured aliases and `dnm check` to verify their health.

**Independent Test**:
Run `dnm displays` and verify aliases appear inline; run `dnm check` to inspect configuration.

**Acceptance Scenarios**:
1. **Given** display `LG Ultra HD` has alias `dp`, **When** the user runs `dnm displays`, **Then** it prints `LG Ultra HD  aliases: dp`.
2. **Given** a display has multiple aliases `dp` and `work`, **Then** it prints `LG Ultra HD  aliases: dp, work`.
3. **Given** `dnm displays --json`, **Then** each display entry includes an `aliases` array, for example `"aliases": ["dp", "work"]`, and `[]` for a display with none.
4. **Given** a shadowed alias exists, **When** running `dnm check`, **Then** the check output flags the shadowed alias.

---

## Edge Cases

- **Target display disconnected**: If an alias points to a display that is not currently plugged in, using `--display <alias>` fails with exit 2: `dnm: The display aliased as <alias> is not connected.`
- **Reserved and invalid names**: Names matching `main`, names made only of digits (`1`, `12`), strings with spaces, or shell special characters (`$`, `\`, quotes) fail with exit 2 and an explanation.
- **Re-association**: Re-running `dnm alias <name> <new-display>` updates the alias's display without requiring prior removal, and says it moved.
- **Case insensitivity**: `dnm alias dp "LG"` allows resolution via `--display DP` or `--display dp`. Creating an alias `DP` when `dp` already exists updates the existing alias and stores the new capitalization (cosmetic only).
- **Alias that is part of a display name**: An alias such as `LG` resolves to its own display even when it is also part of several connected names; partial matching applies only when no exact name or alias matches.
- **Identical monitors**: Displays are told apart by the names and identities macOS reports. When two connected displays report the same name, choosing either by name is ambiguous, so `dnm alias` cannot target it by name and refuses.
- **Unstable or shared identity**: A display whose identity is not a stable UUID (the fallback built from the display's current connection), or whose identity another connected display also reports, cannot be aliased.
- **Older versions**: Once this release writes the manifest, it is schema 2, and older releases refuse it. Accepted risk; no downgrade path.

---

## Requirements

### Functional Requirements

- **FR-001**: The CLI MUST provide a `dnm alias` command supporting creation, removal, and listing.
- **FR-002**: `dnm alias <name> [<display>]` MUST associate `<name>` with the specified display's identity (defaulting to the main display if omitted), and record that display's name as shown by macOS.
- **FR-003**: Display resolution for alias creation MUST support `main`, exact display name, and minimum-unique-string partial matching (case-insensitive). It does not accept other aliases.
- **FR-004**: `dnm alias <name>` MUST refuse with exit 2 if `<name>` matches any currently connected display name (case-insensitive).
- **FR-005**: Alias names MUST be 1–30 characters, consisting only of ASCII alphanumeric characters, `-`, and `_`. Names made only of digits and `main` MUST be rejected.
- **FR-006**: Multiple aliases MAY map to the same physical display.
- **FR-007**: Re-assigning an existing alias MUST update its target display without error. When the display changes, the confirmation MUST say it moved (`Moved alias <name> from <old display> to <new display>.`). The capitalization given last is stored.
- **FR-008**: `dnm alias --remove <name>` (or `-d <name>`) MUST delete the alias, or exit 2 if it does not exist.
- **FR-009**: Bare `dnm alias` MUST list all configured aliases, their display names, and connection / shadow status. A disconnected alias's display MUST be shown by its recorded name, or by its identity if no name is recorded.
- **FR-010**: `dnm alias --json` MUST output one JSON object with an `aliases` array. `--json` is accepted only when listing.
- **FR-011**: Resolution of `--display <value>` in `set`, `remove`, `undo` and `show` MUST evaluate:
  1. Empty / `main` → Main display.
  2. Only digits → Rejected (exit 2).
  3. Exact connected display name → Physical display (shadowing any alias of that name; more than one display of that name is ambiguous, exit 2).
  4. Exact alias (case-insensitive) → Its display (or exit 2 if not connected).
  5. Minimum-unique partial display name → Matched display (or exit 2 if ambiguous / no match).
- **FR-012**: If an alias is shadowed by a connected display, `dnm alias` and commands resolving `--display` with that name MUST emit a warning to stderr.
- **FR-013**: `dnm displays` MUST show each display's active aliases after its name and include an `aliases` array for every display in JSON output.
- **FR-014**: Messages added or changed by this feature MUST print display and alias names without quotes.
- **FR-015**: Aliases MUST be stored in `manifest.json`, changed only under the store's lock, and never change a wallpaper or need a permission.
- **FR-016**: `dnm alias` MUST refuse (exit 2, nothing stored) to alias a display whose identity is not a stable UUID, or whose identity another connected display also reports.
- **FR-017**: The manifest MUST be written as schema version 2. This release MUST read versions 1 and 2. Backward compatibility with older releases is not kept (accepted risk).
- **FR-018**: The documentation MUST be updated with the feature: spec 001's FR-023 and CLI contract (the `--display` resolution order), the README, the `--display` help text, and the release notes.

### Dependencies

- **F1 (shell completions)** builds on this feature: it completes `--display` with the connected display names and the aliases of connected displays, and it reads them through the same core interfaces as `dnm displays`. F2 ships first.

---

## Success Criteria

- **SC-001**: Any valid alias can be passed to `--display` in every command that takes it (`set`, `remove`, `undo`, `show`).
- **SC-002**: 100% of invalid alias names (spaces, special characters, only digits, `main`, existing connected display names) are rejected with exit code 2 and a clear error message.
- **SC-003**: An existing version 1 `manifest.json` is read without loss and saved as version 2 on its next write.
- **SC-004**: Unit and contract tests pass with 100% clean check on `just test` and `just periphery`.

## Assumptions

- macOS gives identical monitors distinct names and identities in most setups (research R1, from third-party reports; not verified on hardware). Where it does not, aliases cannot help and `dnm` refuses rather than guesses.
- Downgrading to an older release is not supported once the manifest is version 2 (accepted risk at 0.1, one user).
- Public interfaces list only connected displays, so a disconnected display's name is known only from what was recorded when the alias was set.
