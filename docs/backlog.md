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
- **Multi-line labels.** Labels are one line of 30 characters for now (spec 001).
- **Clean up all labeled images after a manual reset** (2026-10-06). After a person resets wallpapers by
  hand (for example System Settings > Wallpaper, "Show on all Spaces" on, pick a picture, then off), the
  store still holds images and records for labels no Desktop shows. `prune` deletes only retired labels,
  so these stay (seen live: a label still marked active after every Desktop was reset). The CLI (for
  example `dnm prune --all`) and the app (spec 002) need a way to delete every labeled image and record.
  Public interfaces only see each display's current Desktop, so it must: keep any image a current Desktop
  shows, warn that a Desktop still showing one would lose its wallpaper, and require confirmation (`--yes`
  in the CLI). The README should describe the manual reset it follows.
