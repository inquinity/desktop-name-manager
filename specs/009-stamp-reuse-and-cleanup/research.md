# Research: Reuse and Cleanup (Feature F4)

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## R1. Why this feature exists

The common workflow is deleting a Desktop. `dnm` is never told (public interfaces only show each display's
current Desktop; macOS itself keeps entries for deleted Desktops, research finding 12 in
`docs/research/desktop-association.md`), so the label stays active: a ghost in `list` and `check`, and an image of
about 1.9 MB on the maintainer's built-in display (JPEG quality 0.92 at the display's size, not the source size;
larger displays give larger stamps). The measure of success is not "no ghosts" but "ghosts can be found and
removed, and stop being created needlessly".

## R2. Risk against consequence

A wrong deletion turns one Desktop to a default wallpaper; originals are never touched (constitution V), so no
data is lost, and relabeling rebuilds from the recorded original. The failure that matters is a change without a
visible cause, so nothing deletes by itself. After an explicit `cleanup`, a blanked Desktop can be traced to it
("cleanup is too aggressive"), which the maintainer judged acceptable, and the description says so plainly.

## R3. Options considered

| Option | Verdict |
|---|---|
| Reuse identical images | Adopted: prevention with no permission and no risk. |
| `cleanup` by age (retired and not seen) | Adopted: the everyday path; described and confirmed. |
| Exact scan by walking Desktops | Adopted as stage 2: opt-in (Accessibility), exact for connected displays. |
| Automatic deletion when commands run | Rejected (R2); only a nudge. |
| A grace period before deleting | Rejected: not the need that undo covers. |
| A kept record of deleted images so `dnm remove` could still restore the original | Rejected: wrong deletions are fixed by relabeling or choosing a wallpaper. |
| Periodic job / daemon | Rejected: no background process (spec 001 FR-018). |
| Passive last-seen in the menu-bar app | Adopted for later (spec 002); the CLI records what it sees when it writes. |
| A stored `--days` preference | Deferred to the app's Settings. |

Prior art: `brew cleanup` (same word, and `--prune=DAYS`); Homebrew also cleans automatically after installs,
which is what we decline to copy.

## R4. The reuse key

See `data-model.md` §2. Notes: automatic choices (look, color) depend on the original's content, so the key uses
the request (`nil` = automatic) instead of the result, which avoids loading and composing the backdrop before
deciding; the display's identity is part of the key because `list` attributes a label to one display; the
original's size and modification time make an edited file a new key; the renderer version covers our own changes.
The key is stored hashed. Existing labels have none and are never reused (no guess about how they were made).

## R5. Reuse and sharing

Reuse makes two Desktops showing one image a little more common (the old label is active and a new Desktop gets the
same one). That already happens when macOS copies the left-most Desktop to a new Desktop, and the existing rules
cover it: every command acts on the current Desktop only, `stamp(for:)` finds a label by file name whatever its
state, and `cleanup` never deletes an image on a current Desktop. The residual case (a retired label whose image
another Desktop off screen shows) is the one the plain warning and the scan address.

## R6. Last seen

Written by commands that already write, which have the lock and the display list: for every display, the image its
current Desktop shows is looked up among the labels. Cost: one `currentWallpaper` read per display. Read-only
commands stay read-only. Sparse for people who run `dnm` rarely; the scan and the app fill it in. A label in
use on a Desktop that is never visited while `dnm` runs may therefore look unseen; the description lists the
last-seen age of each candidate, and the user decides.

## R7. The scan (stage 2)

- Enumerating Desktops uses only what `--desktop` uses: step left until nothing moves (Desktop 1), then right
  until nothing moves, reading the display's wallpaper at each (`docs/research/timings.md`: about 1 s per step,
  slowest display; at most 16 Desktops per display). Cost: roughly 2 steps per Desktop per display.
- Each read must come after macOS has updated the wallpaper (the same effect `set` waits for, `waitUntilShowing`):
  read twice, about 100 ms apart, until stable, bounded by the confirmation timeout. A missed read would report a
  label in use as unseen, so this is the main thing to test live.
- Full-screen app Spaces are counted as Desktops and harmless: only the set of labeled images seen matters.
- Preconditions are the same as `--desktop` (Accessibility, the two shortcuts). Behavior with "Displays have
  separate Spaces" off is to be checked live.
- Labels whose display is not connected cannot be judged (known issue KI-2) and are named, not touched.

## R8. Naming

`cleanup`, one word, no `clean`: one spelling in Tab (it sits next to `check`), and the same word as `brew cleanup`.
The existing per-command tidying becomes "housekeeping" in code and documents so the two never share a name.

## R9. The nudge threshold

Stamps are 2 to 6 MB each, so 50 MB is about 8 to 25 labels. Throttled weekly, doubled amounts break the
throttle, standard error must be a terminal, and it never appears for read-only commands, `--json` or scripts.
