# Prototype review: the menu-bar app (spec 014)

The record of the prototype reviews FR-002 asks for. No app code is written before stage 1 is approved (Gate A, task
T011), and the app is not built past the editor before stage 2 is approved (Gate B, task T028). Each approval
records its date here, and contracts/app-ui.md is updated to match it.

- **Stage 1** is the clickable web mockups in `index.html` in this folder, published as a private claude.ai artifact.
- **Stage 2** is the runnable editor (`EditorPrototype`) over a fake wallpaper system and a temporary store.

Mockups and the prototype use only synthetic images and synthetic display names (FR-003).

## Rounds

Add one entry per review round, newest last:

- **Date**
- **Stage**: 1 or 2
- **What was shown**
- **Decisions**
- **Changes made**

### Round 1: 2026-11-15, stage 1

- **What was shown**: `index.html`, published as a private artifact at
  <https://claude.ai/artifact/KRA1BURSSodgeypy4wjQri> (version 1). It has 28 states:
  - the editor: 10 states, in two variants, with position, size and color behind "More options" or always shown;
  - the menu-bar item and menu: 6 states;
  - the hotkey panel and the welcome window;
  - Settings: 7 states (General, the hotkey already in use, New labels, and four Clean Up states);
  - About, Help > Configuration, and an app icon draft.

  The mockups can be switched between light, dark and busy synthetic wallpapers, and between Mac light and dark
  appearance.
- **Questions put to the maintainer**:
  1. Editor options: behind "More options", or always shown?
  2. Should an empty field show its sentence before anything is typed?
  3. Is "Automatic picks Frosted for this spot" the right way to show the automatic choice?
  4. A pasted line break: refuse it, as `dnm` does, or join the lines?
  5. Should the newer-store error also say "this app" instead of "this tool"?
  6. Is 24 characters the right width for the menu bar?
  7. Keep ⌃⌥⌘L as the suggested shortcut?
  8. Which welcome button is the default?
  9. Should the Clean Up age be a number field or a menu?
  10. Is the Accessibility row's wording in Configuration clear?
  11. Is the icon's direction right?
- **Decisions**: pending.
- **Changes made**: pending.

## Approvals

- **Stage 1 (Gate A)**: not yet approved.
- **Stage 2 (Gate B)**: not yet approved.
