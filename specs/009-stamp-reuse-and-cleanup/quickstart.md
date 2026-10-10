# Quickstart & Verification: Reuse and Cleanup (Feature F4)

Use a private store: `export DNM_STORE_DIR="$(mktemp -d)/s"`. Commands that change a wallpaper follow the project's
live-test rules (back up `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`, restore after).

## Stage 1

1. **Reuse.** Label the current Desktop "Mail"; note the number of `*.dnm.jpg` files in the store. `dnm remove`, then
   `dnm set "Mail"` with the same options: still one file (the second `set` was faster). Change the text or an
   option, or the original wallpaper: a new file.
2. **Deleted-Desktop workflow.** Label a spare Desktop "Mail"; delete that Desktop in Mission Control; make a new
   Desktop and label it "Mail" the same way: no new file; `dnm list` shows one "Mail", not two.
3. **Cleanup by age.** With a hand-made store (or `--days 0` on a store with a removed label): `dnm cleanup --days 0`
   lists labels no current Desktop shows, with the plain warning and a question; `n` deletes nothing; `--yes` deletes;
   `--json` prints the document and asks nothing; with stdin not a terminal (`< /dev/null`) it describes and says to
   add `--yes`.
4. **Never the current or the undoable.** A label showing on a current Desktop, or changed less than 30 minutes ago,
   is never listed, even with `--days 0`.
5. **Last seen.** After `dnm set` on one display, `dnm cleanup --days 0 --json` shows a label showing on another
   display's current Desktop as not a candidate; `dnm list`, `show` and `check` leave the manifest byte-identical.
6. **Nudge.** With a store holding more than 50 MB of candidates (copy images), `dnm set` in a terminal prints the note
   once; again immediately: nothing; `dnm cleanup --yes` then another large set: the note can appear again.
7. **`prune` is gone.** `dnm prune` exits 2 and names `cleanup`.

## Stage 2

8. **Scan.** Without Accessibility: `dnm cleanup --scan` exits 1 with the explanation before any other output. With it:
   the description and the question; `n` stops; `y` walks every Desktop (the displays end where they started) and reports
   labels no Desktop shows, and displays it could not look at. Compare by hand with Mission Control, in each display
   configuration you have (one, two, three displays).
9. **`--scan --days 7`** exits 2.
