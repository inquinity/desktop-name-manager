
- **`dnm cleanup` replaces `dnm prune`.** Deleting a Desktop leaves its label and image behind because `dnm` is never
  told. `dnm cleanup [--days N] [--yes] [--json]` finds labeled images that no Desktop is known to show and that were
  removed, replaced or last seen at least N days ago (default 30), describes them, says plainly that a Desktop not on
  screen might still show one, and deletes them when you agree. `dnm prune` now exits 2 and names `cleanup`.
- **Identical labels reuse their image.** Labeling a new Desktop the way an old one was labeled (same wallpaper, text,
  options and display) uses the existing image, so deleting and recreating Desktops no longer adds files.
- **A reminder, never a deletion.** After `set` or `remove`, on a terminal, one line on standard error (at most weekly)
  when `cleanup` could free 50 MB or more. Nothing is deleted by itself.
- **Changed:** the stored data is now format 3 (labels record when they were last seen); older releases refuse it. Labels
  made before this release are never reused.
