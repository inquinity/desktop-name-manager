# Research: Desktop Labels and the `dnm` Command-Line Tool

Each entry gives the decision, the reason, and what else was considered. Facts about
macOS behavior come from the prototype tests on macOS 27.0 (see
`docs/research/findings.md`); anything not yet verified is marked **verify**.

## R1. Language and build

- **Decision**: Swift 6.4 with SwiftPM (`swift-tools-version: 6.2` or later, `platforms:
  [.macOS(.v26)]`). One package: library `DesktopNameCore`, executable `dnm`.
- **Why**: the prototype is Swift and uses AppKit, ImageIO and Vision directly (this feature does not need Vision; see R7). A package
  gives the later app (spec 002) the same library. `.v26` needs tools version 6.2 or later
  (checked with the installed toolchain).
- **Alternatives**: an Xcode project (harder to review and build from the command line);
  separate packages for library and CLI (extra ceremony for one person).

## R2. Dependencies

- **Decision**: system frameworks only in the core. The CLI uses `swift-argument-parser`,
  pinned to an exact version with the checksum recorded in `Package.resolved`.
- **Why**: six commands with options, help text, validation messages and shell completions
  are what that package is for, and it is Apple's own. It has no run-time network use,
  needs no permission, uses no private API, and compiles into the binary (so nothing extra
  to notarize). It is reviewed as part of each release's security review.
- **Alternatives**: hand-rolled parsing as in the prototype (about 80 lines, but help,
  errors and completions would all be ours to write and test). Reversible: parsing is
  confined to the `dnm` target.

## R3. Minimum macOS version

- **Decision**: macOS 26.0 (the oldest release that can be tested: macOS 26 and 27 are
  both available to the maintainer).
- **Why**: the constitution's rule is the oldest release that runs the feature with no
  compatibility code. The APIs used (`NSWorkspace` desktop image calls, `NSScreen`,
  ImageIO, CoreImage) have existed since 10.15 at the latest, so
  they do not limit it. The limit is evidence. Constitution principle VII requires live
  checks for behavior that touches the real wallpaper. The per-Space behavior was verified
  on 27.0 in the prototype, and the live checks will run on 26 as well before release. Wallpaper handling changed in macOS 13 and 14, and forum reports
  describe version-specific quirks (for example "Show on all Spaces"). Claiming support we
  cannot test would break that principle.
- **How to lower it**: run the live checks in [quickstart.md](quickstart.md) on an older
  release (hardware or a virtual machine). If they pass with no code changes, lower the
  `platforms` entry and record the result. If they need any special-case code, that release
  stays dropped.
- **Alternatives**: macOS 13 to 15 as a nominal floor (no machine to test them on, so the
  support would be an untested claim); macOS 27 only (needlessly excludes a release we can
  test).

## R4. Identifying displays and the current Desktop (public only)

- **Decision**:
  - The main display is `CGMainDisplayID()`, the same display macOS shows as "Use as: Main
    display".
  - A display's name is `NSScreen.localizedName`. Its stable identity for storage is the
    display UUID from CoreGraphics (public).
  - The current Desktop of a display is identified by the file `NSWorkspace.desktopImageURL(for:)`
    returns. A file inside our store that has an active manifest entry means "labeled".
  - `--display` resolution: `main` first; then a case-insensitive exact name match; then a
    unique case-insensitive partial match. No match or several matches is an error listing
    the candidates.
- **Why**: all public, no permissions. The prototype confirmed that the URL follows Space
  switches immediately.
- **Alternatives**: SkyLight Space identifiers (private; constitution allows only optional
  read-only use, reserved for Quick View in spec 003); position keywords and numbers
  (rejected in clarify).

## R5. Storage layout and identity of stamps

- **Decision**:
  - Store directory: `~/Library/Application Support/<store name>/`. The store name is a
    constant in the core library, `com.altmansoftwaredesign.desktop-name-manager`, with
    `.dev` appended in debug builds (`#if DEBUG`), so a debug build never touches real
    labels. It is not read from a bundle, because a SwiftPM command-line tool has none, and
    the later app must share the same store. Tests and live checks override it with the
    `DNM_STORE_DIR` environment variable.
  - Stamps are named `<uuid>.dnm.<ext>`: a fresh random identifier on every set (not
    content), a marker that identifies our files, and the image format's extension. The tool
    chooses the format, not the source image (v1 writes JPEG: a 5K photo is about 3.5 MB as
    JPEG and several times larger as PNG). The extension is stored with each stamp, so a
    later format change breaks nothing.
  - A JSON manifest (schema versioned) holds all records. A lock file guards every
    read-modify-write.
  - Order of operations on set: write the stamp file, save the manifest with the new entry,
    then call `setDesktopImageURL`.
- **Why**:
  - The prototype named files by content hash, which avoids macOS showing a cached image for
    a reused path. A random name per set does the same and adds something the spec needs:
    two Desktops with the same label and image would share one content-named file, and
    removing one label would then delete the other's wallpaper after the cool-down. One file
    per set means one owner.
  - Saving the manifest before the wallpaper call means a crash leaves either nothing, a
    stray unused file (deleted after the cool-down), or an active entry that was never
    applied (a small leak), never a wallpaper pointing at a file we do not know about.
  - The lock keeps two `dnm` runs, or later the app and the CLI, from corrupting the
    manifest.
- **Alternatives**: a database (more than needed); content-hash names (the sharing bug
  above).

## R6. Unsupported wallpapers (FR-014)

- **Decision**: decline, with the "unsupported wallpaper" exit code, when any of these is
  true: no file URL is reported; the URL is a catalog wallpaper (`.madesktop`); it is a
  video; it is a folder (shuffle); or the image has more than one frame or carries dynamic
  wallpaper metadata. Solid colors are **verify**: if macOS reports an ordinary image file
  for them, they are treated as images; if it reports nothing, they fall under the first
  rule.
- **Why**: stamping any of these as a plain still would freeze or break the wallpaper.
  Spec 006 handles them properly.
- **Alternatives**: stamping the first frame (silently changes behavior).

## R7. Rendering

- **Decision**: port the prototype's pipeline into `Render/`: compose the backdrop exactly
  as macOS shows it on that display (pixel size, fill/fit/center/stretch, fill color), sample
  the label's area, choose text color and one of plain, halo or frosted, draw the text
  (SF Pro Semibold) and write the image. Changes from the prototype: the Vision saliency map is dropped (it only served the automatic-position feature, which is out of scope, and it stalled when many renders ran at once); single line of at most
  30 characters; "pill" removed (not in the spec); automatic position removed (fixed corner,
  bottom-left, unless the user chooses one); emoji drawn through normal font fallback.
  Because the image already matches the display exactly, it is set with scale-to-fill and
  the original fill color, which is lossless (prototype finding).
- **Why**: the approach passed all 23 test wallpapers; the decisions in the spec remove
  scope rather than add it.
- **Output format**: JPEG at high quality, as in the prototype, unless the quality check
  (live scenario 18: look at fine detail and flat color areas, and measure the difference
  against the composed backdrop away from the label) shows visible loss, in which case the
  decision is revisited.

## R8. Restoring exactly, and undo

- **Decision**:
  - First label on a Desktop records an `Original`: file path, a bookmark to the file
    (follows renames and moves), scaling, clipping, and the fill color as an archived
    `NSColor` so its color space round-trips. Nothing is copied.
  - Every stamp keeps its `Original`. Replacing a label creates a new stamp with the same
    `Original`, and the new image is rendered from that recorded `Original`, never from the
    previous stamp, so labels do not stack and a replacement works even if the old stamp
    file is gone.
  - Retiring a stamp (replace, remove, undo) records the time and the reason; the file stays
    until the cool-down has passed.
  - `undo` takes the display's most recent change, checks that it is still within the
    cool-down and that the display's current wallpaper equals what that change produced, and
    re-applies the state before it: the previous stamp (still on disk) or the original.
- **Why**: the prototype already proved exact restore. A bookmark survives the user moving
  the image; a private copy would double the privacy footprint and storage.
- **Limits**: undo cannot tell apart two Desktops on one display that show the identical
  image (see the plan's proposed amendments).
- **Alternatives**: a full history per Desktop (scope beyond the spec); storing a copy of
  the original (more files, privacy cost).

## R9. Cleanup

- **Decision**: at the start of every command, under the lock, delete (a) stamp files whose
  entry was retired more than the cool-down ago, and (b) files in the store directory that
  have no manifest entry, are older than the cool-down, and match `<uuid>.dnm.<ext>`
  exactly. It never deletes the manifest, the lock file, subfolders or any other file, and
  does nothing in a folder with no manifest of ours, so a mistyped `DNM_STORE_DIR` cannot
  damage other files. The cool-down is a constant of 30 minutes in the core (not a user
  setting), read through a clock object so tests can
  advance time. No background process of any kind.
- **Why**: matches the clarified spec. An entry is "in use" while it is active, because the
  tool cannot see other Desktops without a private interface.
- **Alternatives**: read the system's wallpaper store (private format) to find unreferenced
  files (precise, but conflicts with "public first"; left as an optional later improvement);
  a user-adjustable cool-down (more surface for no stated need).

## R10. Verifying the privacy rules

- **Decision**: three automated checks. (1) A test scans `Sources/` for networking APIs
  (`URLSession`, `Network`, `CFNetwork`, sockets) and for private-framework loading
  (`dlopen`, SkyLight). (2) A test inspects the built binary's linked libraries for
  anything unexpected. (3) A live check runs every command with network access blocked and
  confirms it still works. File integrity of originals is checked by checksum before and
  after.
- **Why**: turns constitution principles I and IV into tests instead of promises.
- **Alternatives**: manual review only (does not catch regressions).

## R11. Exit codes and output streams

- **Decision**: `0` success; `1` failure (I/O, access denied, nothing to restore, undo not
  possible); `2` invalid input (bad label, bad option, unknown or ambiguous `--display`);
  `3` unsupported wallpaper. Normal output and `--json` on standard output; messages and
  warnings on standard error. "Remove" on a Desktop with no label exits `0`.
- **Why**: the spec asks for distinct, documented codes for success, invalid input,
  unsupported wallpaper and failure. Keeping to those four is the smallest set that does.
- **Alternatives**: a separate code for "nothing to undo" (more to document; scripts can
  read the message or JSON).

## R12. Testing approach

- **Decision**: operations are written against a `WallpaperSystem` protocol
  (list displays, read current wallpaper and placement for a display, set wallpaper). Unit
  tests use a fake; the real implementation is exercised by the hand-run live scripts.
  Render tests use synthetic generated images for the committed suite and the local
  `wallpaper-samples/` for the legibility sweep (SC-002), which reports skipped when the
  folder is absent. Legibility means that, in the finished image, the text has a
  contrast ratio of at least 3:1 (the WCAG large-text threshold) against at least 95% of the
  pixels directly behind it, after any halo or frosted backing. The prototype's rules (plain
  only when under 5% of the area is weak, halo under 20%, otherwise frosted) were tuned to
  this measure. A manual look at every rendering backs it up.
- **Why**: keeps almost all logic testable without touching the user's wallpaper, which
  matches the project's rule about protecting it during live tests.

## R13. Desktops and labeled images (amendment 2026-10-05)

- **Decision**: a labeled image (stamp) may be shown on any number of Desktops. Any of our stamp files
  shown on the targeted Desktop counts as its label, whatever its record says; `set`, `remove` and `undo`
  change only that Desktop; a stamp's record keeps `applied` (it was set on a Desktop at least once) and a
  status for `prune`, but no status ever deletes an applied stamp automatically.
- **Why**: macOS gives each new Desktop a copy of the first Desktop's wallpaper by reference to the same
  file, and public interfaces cannot show which Desktops share it (`docs/research/desktop-association.md`).
- **Alternatives**: reading the private wallpaper store or Space list (rejected: the product is public
  only); refusing to label Desktop 1 (cannot be known without `--desktop`, and too restrictive).

## R14. Reaching Desktop N with public interfaces (`--desktop`)

- **Decision**: move the pointer to the display's centre (restored afterwards); press Control-Left until no
  change is announced within 1 s (that is Desktop 1, and the count gives the starting position); press
  Control-Right N-1 times, each confirmed by `NSWorkspace.activeSpaceDidChangeNotification`; act; return
  the same way. The command runs briefly as a background application (accessory policy, never active),
  because the notification arrives only through the application event loop. Keystrokes need the
  Accessibility permission, checked without prompting (`AXIsProcessTrusted`); the "Move left/right a
  space" shortcuts must be enabled (read from the public symbolic hot keys preferences).
- **Why**: proven in the spike (on both displays, including landing on the right Desktop, detecting a
  missing Desktop and returning), using public interfaces only.
- **Alternatives**: private Space switching (rejected); "Switch to Desktop N" shortcuts (off by default
  and numbered across the whole Mac, not per display); scripting Mission Control's interface (fragile).
- **Open**: full-screen app Spaces are in the Control-arrow order but not numbered as Desktops; how to
  detect them publicly is a task (T086); until then the tool stops if a step lands somewhere it cannot
  confirm as a Desktop.

## R15. Private interfaces leave the product

- **Decision**: remove the wallpaper-store reader and the KI-1 "re-apply first" step from the product. The
  research tools in `prototype/` keep reading private interfaces, read-only, and are never shipped.
- **Why**: the maintainer's rule for the product is public interfaces only, and the re-apply step rested on
  a wrong explanation.

## Open items carried to implementation

- Solid-color wallpapers: what `desktopImageURL` returns (R6). Scheduled as live scenario 17.
- JPEG quality versus visible loss (R7). Scheduled as live scenario 18.
- "Show on all Spaces": the prototype warns when it is on, but detecting it means reading
  the system's private wallpaper store. This feature does not read it, so the README
  documents the setting instead. A read-only, optional check can come later in an isolated
  module.
