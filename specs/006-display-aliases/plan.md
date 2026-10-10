# Implementation Plan: Feature F2 — Display Aliases

**Branch**: n/a (spec directory `006-display-aliases`; work happens on main) | **Date**: 2026-10-08 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/006-display-aliases/spec.md`

## Summary

Implement display aliases in `DesktopNameCore` and `dnm`. An alias is a short, user-defined name (e.g., `dp` or `desk`) mapped to a connected display's stable identity (`Display.uuid`), with the display's name recorded for showing it while disconnected. Aliases are persisted in `manifest.json` (schema version 2) under the store's lock. Once set, aliases resolve via `--display <value>` in every command that takes it (`set`, `remove`, `undo`, `show`).

The implementation covers:
1. Alias data model in `Manifest`, reading versions 1 and 2 and writing the version from the content.
2. Alias operations (set, move, remove, list) on `DesktopLabeler`, using `Store.transaction`.
3. Name validation rules (1–30 chars, alphanumeric + `_`/`-`, no spaces/special chars, not only digits, not `main`, no matching connected display) and identity checks (stable UUID, unique among connected displays).
4. `DisplayResolver` updates: exact display name → alias → minimum unique substring. Override detection and stderr warnings.
5. New CLI command `dnm alias` with set, remove, and list modes (text and JSON).
6. Integration with `dnm displays` and `dnm check`.
7. Documentation: spec 001 FR-023 and its CLI contract, the README, the `--display` help, and the release notes.

## Technical Context

**Language/Version**: Swift 6.4 (Xcode 27 toolchain), Swift 6 language mode

**Primary Dependencies**: Apple system frameworks (AppKit, CoreGraphics, Foundation). CLI: `swift-argument-parser` (already approved and pinned in package).

**Storage**: Files under `~/Library/Application Support/com.altmansoftwaredesign.desktop-name-manager/manifest.json` (or `$DNM_STORE_DIR`). Aliases stored in `aliases: [DisplayAlias]`; schema version 2 (reads 1 and 2; older releases are not supported, an accepted risk).

**Testing**: Swift Testing for unit and contract tests with mock display fixtures. Contract tests for CLI commands in `dnmTests`.

**Target Platform**: macOS 26.0 and later.

**Project Type**: Library (`DesktopNameCore`) plus CLI tool (`dnm`).

**Constraints**: Public APIs only; 0 macOS permissions; local-only storage; no network/telemetry; exact reversibility; Gatekeeper and Homebrew cask compatible; no UUIDs in repo.

## Constitution Check

*GATE: Must pass before Phase 0 research and implementation.*

| Principle | Status | How the plan meets it |
|---|---|---|
| **I. Public APIs only** | **Pass** | Uses only `NSScreen.localizedName`, `CGDisplayCreateUUIDFromDisplayID`, and CoreGraphics display identifiers. No SkyLight, private frameworks, or undocumented system files. App Store compatible. |
| **II. Never require SIP changes** | **Pass** | Operates strictly within user Application Support storage. Touches no system processes or protected files. |
| **III. Least permission** | **Pass** | Display alias management requires **zero macOS permissions** (no Accessibility, no Screen Recording). Declining permissions has zero impact. |
| **IV. Local-only** | **Pass** | Stored strictly in local `manifest.json`. No network frameworks imported; zero telemetry or analytics. |
| **V. Reversible changes** | **Pass** | Creating or deleting aliases modifies only local alias mappings and touches no wallpapers. Aliases can be cleanly removed via `dnm alias --remove`. |
| **VI. Distributable via Homebrew** | **Pass** | Compiled into the standard `dnm` binary; signs and notarizes cleanly for Homebrew cask distribution. |
| **VII. Tested** | **Pass** | Unit tests cover decoding, CRUD, name validation, precedence, and overrides. Contract tests cover CLI argument parsing and formatting. |
| **VIII. Public-repo hygiene** | **Pass** | Tests use synthetic display names and mock UUIDs. No real machine paths, usernames, or hardware UUIDs committed. |

No violations exist. Complexity Tracking table is empty.

## Project Structure

### Documentation (this feature)

```text
specs/006-display-aliases/
├── spec.md              # Feature specification
├── plan.md              # This implementation plan
├── research.md          # Research findings (R1: monitor naming disambiguation)
├── data-model.md        # Data model and schema updates
├── quickstart.md        # Test scenarios and manual validation checklist
├── checklists/
│   └── requirements.md  # Specification quality checklist
└── contracts/
    └── cli.md           # CLI syntax and contract details
```

### Source Code Changes

```text
Sources/
├── DesktopNameCore/
│   ├── Model/
│   │   ├── DisplayAlias.swift         # New: DisplayAlias model and name validation
│   │   └── Stamp.swift                # Updated: Manifest includes aliases; version from content
│   ├── Displays/
│   │   └── DisplayResolver.swift      # Updated: Alias resolution, precedence, overrides
│   ├── Operations/
│   │   ├── Aliases.swift              # New: set, move, remove and list on DesktopLabeler
│   │   ├── Check.swift                # Updated: Aliases row
│   │   └── Reports.swift              # Updated: Reports.Display includes aliases; alias report
│   └── Store/
│       └── Store.swift                # Updated: reads versions 1 and 2
└── dnm/
    ├── Commands/
    │   ├── AliasCommand.swift         # New: dnm alias command implementation
    │   └── DisplaysCommand.swift      # Updated: Surface aliases inline
    ├── DisplayOption.swift            # Updated: --display help mentions aliases
    ├── Context.swift                  # Updated: Context passes aliases to resolver
    └── Dnm.swift                      # Updated: Register AliasCommand subcommand

Tests/
├── DesktopNameCoreTests/
│   ├── DisplayAliasTests.swift        # New: Alias validation, model, schema version tests
│   ├── AliasOperationTests.swift      # New: set, move, remove, identity checks
│   └── DisplayResolverTests.swift     # Updated: Alias resolution and override tests
└── dnmTests/
    └── AliasCommandTests.swift        # New: Contract tests for dnm alias
```

## Architecture & Implementation Phases

### Phase 1: Core Data Model & Storage
1. Define `DisplayAlias` (`name`, `displayUUID`, `displayName?`) in `Sources/DesktopNameCore/Model/DisplayAlias.swift`. No timestamp.
2. Add validation: length 1–30; ASCII alphanumeric, `-`, `_`; not only digits; not `main`.
3. Update `Manifest` in `Sources/DesktopNameCore/Model/Stamp.swift`:
   - Add `public var aliases: [DisplayAlias]`, decoded with `decodeIfPresent … ?? []`.
   - `currentSchemaVersion = 2`; every save writes 2.
4. `Store` keeps its generic `readManifest` and `transaction`; its "newer manifest" check now allows 1 and 2.
5. Alias operations live on `DesktopLabeler` in `Sources/DesktopNameCore/Operations/Aliases.swift`
   (**recommendation, review finding 12**): every other operation (`setLabel`, `removeLabel`, `prune`) is a
   `DesktopLabeler` method over `Store.transaction`, and the operation needs the display list from the
   `WallpaperSystem` for its identity checks, which `Store` does not have. `Store` gets no alias methods.
   - `aliases() throws -> [DisplayAlias]` (read only; never creates the store)
   - `setAlias(_ name:, display:) throws -> AliasChange` (`.created`, `.unchanged`, `.moved(from:)`)
   - `removeAlias(named:) throws`

### Phase 2: Resolver & Override Logic
1. Update `DisplayResolver.resolve`, the **only** display resolution in the code (FR-019):
   - Signature takes a mode: full (`aliases: [DisplayAlias]`) or display-only (no aliases), and returns any override warning with the display. The display-only mode is the same function without the alias step, not a copy.
   - No command, including `dnm alias`, matches names or aliases itself; they all call this function.
   - Exact connected display name checked first (the physical display takes precedence over an alias).
   - If an alias matches the query but a connected display has that exact name, report the override.
   - If no exact display name matches, check exact alias name (case-insensitive):
     - Target display UUID connected → return it.
     - Not connected → throw `DnmError.invalidInput("The display aliased as <name> is not connected.")`.
   - Then the minimum-unique partial display name match, as today.
2. In `Context.swift`, pass the aliases read from the store to `DisplayResolver`, and print any warning to stderr.
3. Identity checks for `dnm alias`: refuse a display whose `uuid` starts with `no-uuid-`, or whose `uuid` another connected display also has.

### Phase 3: CLI Commands & Formatting
1. Create `AliasCommand.swift`:
   - Positional arguments: `name: String?`, `display: String?`.
   - Flags: `--remove`, `--json`. (A short `-d` existed in 0.1.1 and was removed in 0.2.0, spec 008.)
   - Branching:
     - `--remove <name>`: delete alias.
     - `name` provided: set/update alias for `display` (defaulting to `main`). Check that `name` does not match any currently connected display name.
     - `name` omitted: list aliases (text table or JSON). Warn if any alias is overridden.
   - `--json` only when listing; with a name it is invalid input (exit 2).
   - Messages print alias and display names without quotes (FR-014). Moving an alias prints `Moved alias …`.
2. Update `Dnm.swift`: register `AliasCommand.self`.
3. Update `DisplaysCommand.swift`: print `aliases: a, b` after the name and main marker (contract §5). `Reports.Display` gets `aliases: [String]` (always present).
4. Update `Check.swift` (core): add the Aliases row (contract §6).
5. Update `DisplayOption.swift`: the `--display` help names aliases.

### Phase 3b: Documentation
1. Amend spec 001: FR-023 and `contracts/cli.md` (the resolution order, with aliases).
2. README: aliases in the `--display` description and a short `dnm alias` section.
3. `docs/release-notes/UNRELEASED.md`: the new command, and that the store moves to schema 2 (older releases refuse it).

### Phase 4: Testing & Quality Gates
1. Unit tests for `DisplayAlias` validation and `Manifest` versions (1 reads; 2 is written; newer is refused).
2. Unit tests for `DisplayResolver` precedence and overrides.
3. Contract tests for CLI commands and error exits.
4. Run `just test` and `just periphery` to ensure clean build and zero dead code.
