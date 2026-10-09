# Quickstart & Verification: Display Aliases (Feature F2)

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

This quickstart lists the verification scenarios for manual testing and live check verification.

Always back up your wallpaper store before running live tests:
```sh
cp -a ~/Library/Application\ Support/com.apple.wallpaper/Store/Index.plist /tmp/Index.plist.bak
```
Use an isolated store directory so personal labels remain untouched:
```sh
export DNM_STORE_DIR="$(mktemp -d -t dnm-alias-test.XXXXXX)"
```

---

## Scenarios

### Scenario 1: Basic Alias Creation and Listing
1. Run `dnm displays` to inspect connected displays.
2. Alias the main display:
   ```sh
   dnm alias desk
   ```
   Verify output: `Aliased desk to <main-display-name> (main).`
3. List aliases:
   ```sh
   dnm alias
   ```
   Verify `desk` is listed with its target display name.
4. List aliases in JSON:
   ```sh
   dnm alias --json
   ```
   Verify one JSON object, `{"aliases": [...]}`, with `connected: true` and `isMain: true` for `desk`.

### Scenario 2: Using Alias with `--display`
1. Label the display using the alias:
   ```sh
   dnm set "TestLabel" --display desk
   ```
   Verify label is applied without errors.
2. Show the label:
   ```sh
   dnm show --display desk
   ```
   Verify label `"TestLabel"` is reported.
3. Clean up:
   ```sh
   dnm remove --display desk
   ```

### Scenario 3: External Display and Minimum-Unique Matching
1. For an external display (e.g. `"LG UltraFine"`):
   ```sh
   dnm alias ext "LG Ultraf"
   ```
   Verify output (no quotes): `Aliased ext to LG UltraFine.`
2. Run `dnm displays` and verify `aliases: ext` appears after that display's name.

### Scenario 4: Re-association and Idempotency
1. Run the identical command again:
   ```sh
   dnm alias desk
   ```
   Verify it succeeds cleanly without error.
2. Re-assign `desk` to another display:
   ```sh
   dnm alias desk "LG Ultraf"
   ```
   Verify output: `Moved alias desk from <main-display-name> to LG UltraFine.`
3. Run `dnm alias DESK "LG Ultraf"` and verify `dnm alias` now lists it as `DESK`.

### Scenario 5: Alias Removal
1. Remove the alias:
   ```sh
   dnm alias --remove desk
   ```
   Verify output: `Removed alias desk.`
2. Verify `dnm alias` no longer lists `desk`.
3. Try removing it again:
   ```sh
   dnm alias --remove desk
   ```
   Verify exit code 2 and error message: `dnm: No alias named desk exists.`

### Scenario 6: Name Validation Checks
Verify rejection with exit code 2 for each invalid name:
1. `dnm alias main` → Rejected (`main` is reserved).
2. `dnm alias 1` → Rejected (only digits).
3. `dnm alias "my desk"` → Rejected (contains spaces).
4. `dnm alias "desk$1"` → Rejected (contains special character).
5. `dnm alias DP1` (where DP1 is a connected display name) → Rejected (`DP1 is already the name of a connected display...`).

### Scenario 7: Store Version
1. After any change, check that `$DNM_STORE_DIR/manifest.json` has `"schemaVersion" : 2`.
2. `dnm alias --json desk` exits 2 (`--json` is only for listing).

### Scenario 8: Shadowing Behavior
1. Create an alias when the matching display is not connected.
2. Connect the display (or simulate via mock in tests).
3. Verify `dnm alias` marks it as shadowed and prints warning to stderr.
4. Verify `--display <name>` targets the physical display and warns on stderr.

---

## Cleanup

Restore wallpaper store and remove temporary directory:
```sh
unset DNM_STORE_DIR
cp -a /tmp/Index.plist.bak ~/Library/Application\ Support/com.apple.wallpaper/Store/Index.plist
```
