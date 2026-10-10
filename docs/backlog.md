# Backlog

Ideas recorded for later. None is part of a current spec.

- **Full-featured build with optional private interfaces** (2026-10-05). The product is public-only and
  aims to stay App Store compatible (constitution I). A second, separately built and distributed edition
  could add features that need private interfaces, for example: checking whether the "Move left/right a
  space" shortcuts are on, listing every Desktop (Quick View), knowing which Desktops share a labeled
  image, and warning when a label becomes the default for new Desktops. The research tools in
  `prototype/` show how. Needs its own spec, and keeps the two builds' features clearly separated.
- **App Store readiness research.** Before an App Store build: check what the sandbox allows for reading a
  wallpaper image outside the app's container, for setting wallpapers, for sending the Desktop-switching
  shortcuts with Accessibility, and for shipping the command-line tool.
- **Multi-line labels** (roadmap F5, after 1.0.0 at the earliest). An app feature (M2), not a CLI one.
  Labels are one line of 30 characters for now (spec 001).
- **Clean up all labeled images after a manual reset** (2026-10-06; roadmap F4, 0.2.1). After a person resets wallpapers by
  hand (picking a picture in System Settings > Wallpaper on each Desktop, or turning "Show on all Spaces"
  on, which is one setting for every display, picking a picture, and turning it off again), the
  store still holds images and records for labels no Desktop shows. `prune` deletes only retired labels,
  so these stay (seen live: a label still marked active after every Desktop was reset). The CLI (for
  example `dnm prune --all`) and the app (spec 002) need a way to delete every labeled image and record.
  Public interfaces only see each display's current Desktop, so it must: keep any image a current Desktop
  shows, warn that a Desktop still showing one would lose its wallpaper, and require confirmation (`--yes`
  in the CLI). The README should describe the manual reset it follows. It must also warn about Desktops of
  display arrangements not connected now (known issue KI-2), which it cannot see.

  **Revised 2026-10-10: cleanup after deleted Desktops (maintainer's proposal; to be continued).** The common
  workflow is deleting a Desktop in Mission Control, not unlabeling and reusing it. `dnm` is never told, so the
  label stays active (a ghost in `list` and `check`, about 1.9 MB of image). Proposal: `dnm cleanup` (also
  `dnm clean`) replaces `dnm prune`, which has little value outside a scan:
  - `dnm cleanup [--days N]`: remove anything older than N days (default 30, suggested).
  - `dnm cleanup --scan`: after checking that Accessibility is granted (before saying anything else), describe what
    it is about to do and ask permission, then walk every Desktop of each connected display to find labels that
    no Desktop shows.
  Points raised in review, still open:
  - **What "older" measures.** Age since creation would delete labels on Desktops that are alive. `--days` can
    safely mean "retired at least N days ago" (removed, replaced or undone), not "unused for N days"; ghosts need
    the scan (or, later, the menu-bar app's record of which labels it has seen, spec 002).
  - **Age is not proof.** A retired image can still be another Desktop's wallpaper (new Desktops copy the
    left-most one). Idea: delete the image but keep a small record of it, so a Desktop left pointing at the
    deleted file can still be put right with `dnm remove` (needs a live check that macOS still reports the path).
  - **Describe, then ask.** Every mode describes what it will do; on a terminal it asks, otherwise it needs
    `--yes` (and without it only describes). A confirmation prompt is new behavior for the tool.
  - **The scan's risk** is reading a Desktop's wallpaper before macOS updates it (as the settle wait in `set`
    handles); a missed read means a false ghost. Needs a settle and a live test; the kept record is the net.
  - **What `--days` means with `--scan`** (probably nothing: whatever no Desktop shows is eligible).
  - **Names:** two spellings (`clean`, `cleanup`) both appear in Tab and sit next to `check`; and the automatic
    per-command housekeeping is called "Cleanup" in specs 001 and 005, which clashes; rename it in the docs.
  - **Never delete a stamp inside the 30-minute undo window.**
  - **Staging:** the age-based part is small (the rename of `prune`); the scan is the larger piece
    (navigator support to enumerate Desktops, timings, live tests) and could ship after it.

  **Decisions so far (maintainer, 2026-10-10)**
  - **No automatic deletion** of labeled images by any command, in the CLI. A label that is in use suddenly
    replaced by the Mac's default wallpaper, with no visible cause, is the worst failure; a store that grows is
    not. (Reverses nothing: FR-018 of spec 001 already forbids it.)
  - **A nudge instead:** about 50 MB of images that cleanup could free (roughly 8 to 25 labels) triggers a one-line
    stderr note after `set`, `remove` or `undo`, on a terminal only, at most weekly (sooner only if the amount
    doubled), reset by a cleanup, silenced by the quiet flag (F7) later. It counts labels retired for long and
    labels not seen for long, so it needs the "last seen" record from the first stage, and it points at
    `dnm cleanup --scan`, which is exact and asks first.
  - **Reuse of identical labeled images** is worthwhile and comes first (it can revive a retired image).
  - **No grace period** (not the same need as undo); **no kept record** of deleted images.
  - **`--scan` is an inspection**, so `--days` does not apply to it.
  - **"Last seen"** (a table of images and dates) is wanted; written by commands that already write, by the scan, and
    by the app.
  - **Leaning, not final:** remove `prune`; one name, `cleanup`; `--days N` per run with a default of 30, and a stored
    preference left to the app's Settings.
  - **Still open:** the non-scan cleanup (retired for N days) can also delete an image that another Desktop still
    uses, for the same reason as above. Options: make the scan the default whenever Accessibility is granted, so
    most deletions are proven; and have the non-scan description say plainly that a Desktop not currently on
    screen might still show one.
- **Batch labeling** (2026-10-06; roadmap F3, 0.2.2). Label several Desktops in one command (for example from a list of
  display, Desktop and label), so the walk to find each display's position happens once instead of once
  per command (see `docs/research/timings.md`). How people will mostly use the tool (the app, one-off CLI
  commands or scripts) is not known yet, and should set this item's priority.

  Several displays in one command (2026-10-09, raised while specifying F8): `dnm set "x" --display DP1 --display main`.
  `--display` repeated is an error until this exists (spec 008). Rules to decide: resolve every display first so a
  typo never half-applies, then apply in order and stop at the first failure, naming the displays already changed
  (each is undone with `undo`); the same display named twice is collapsed; a positional display plus `--display`
  is an error; `--desktop` means that Desktop of each display; `set`, `remove` and `undo` only, because
  `show --json` prints one document.

- **Display aliases** (2026-10-07; roadmap F2, 0.1.1, before shell completions F1 in 0.1.2). Short names for displays, for example `DP1` for a long monitor name, so
  `--display DP1` works. An alias is tied to the display's stable identity (never shown), not its name, so
  it also tells apart two monitors of the same model that report the same name, which no name or partial
  name can do today. (A name that is part of another, such as `LG Ultra` and `LG Ultra HD`, already works:
  an exact name wins over a partial match.) Spec 001 planned these for display roles (M4); they could come
  sooner as a small CLI feature (`dnm alias DP1 "LG Ultra HD"`, shown by `dnm displays`).
- **`remove` repairs a misreported Desktop** (2026-10-08; roadmap F6, no release yet). Known issue KI-3: a new Desktop that inherited
  the left-most Desktop's label can report the original wallpaper while still showing the label. When the
  reported image is the original of one of our labels, `remove` could set that original again (public
  `setDesktopImageURL`, with the recorded placement) so the screen catches up. Low priority: keeping the
  left-most Desktop unlabeled avoids the case. Confirm the cause first (KI-3).
- **Quiet flag** (2026-10-09; roadmap F7, no release yet). A global `-q` / `--quiet`, and perhaps `DNM_QUIET=1`,
  that suppresses warnings only, never results or errors, so a person who knows about a condition is not
  reminded on every run. The case that prompted it: alias `DP1` for one monitor while another monitor is
  named `DP1`. The display's name overrides the alias, so every `--display DP1` prints the warning, and
  `2>/dev/null` would hide real errors too. It covers every command, so it needs its own spec: it amends the
  streams rule in spec 001's CLI contract and spec 006 FR-012 (which says the warning MUST be emitted). The
  `(overridden by …)` marker in `dnm alias` and the `dnm check` row stay, as information that was asked for.
- **Display as a positional argument** (2026-10-09; roadmap F8, 0.2.0: a change of syntax, so a minor version). With several monitors the display
  is the main selector, and labeling `main` is the least frequent case, so `dnm set DP1 "label"` and
  `dnm set main "label"` read better than `--display`. Sketch: `dnm set [<display>] <label>` (one argument is a
  label for the main display; two are display and label), `dnm remove|undo|show [<display>]`, `--display` kept as
  an equivalent (an error when both are given), `--desktop` unchanged. Open points for the spec: a lone argument
  that is also a display name or alias (refuse, with the explicit form), the completion rules for the first
  position, and the amendments to spec 001 FR-023 and spec 006 FR-011 (the single resolver stays the only place
  that matches displays).

  Requirement (maintainer, 2026-10-09): displays have spaces, so `dnm set "LG Ultra" "My label is great"` must
  work: quoted arguments are single arguments, the display goes through the single resolver (a partial name is
  fine) and the label may contain spaces. Wrong argument counts get friendly errors, never a guess: three or more
  arguments ("set takes a label, or a display and a label; quote anything with spaces"); two arguments whose
  first is no display (no display matches it; to label the main display, quote the whole label); and a lone
  argument that is a display name or alias (refused, with the explicit `dnm set main "<label>"` form).
  Decision (maintainer, 2026-10-09): no leniency. A wrong argument count is always an error, never a guess; the
  way to avoid typing quotes around a display name with spaces is an alias (`dnm alias lg "LG Ultra"`, then
  `dnm set lg "My label"`), and the errors for a display that does not resolve say so.

