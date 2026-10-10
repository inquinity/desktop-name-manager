# Specification Quality Checklist: Reuse and Cleanup (Feature F4)

**Created**: 2026-10-10 | **Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Focused on user value (the store stops growing needlessly; old images can be found and removed)
- [x] Decisions made before the specification are listed with their reasons
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements testable (candidate rules in `data-model.md`, messages in the contract)
- [x] Success criteria measurable (store file count, 50 ms, nudge table, scan comparison)
- [x] Acceptance scenarios and edge cases defined (undo window, current Desktop, absent displays, no terminal, interruption)
- [x] Scope bounded and staged (stage 1, stage 2, the app later)
- [x] Dependencies and assumptions identified (JPEG stamps; deterministic rendering; `--desktop` machinery for the scan)

## Feature Readiness

- [x] Each functional requirement has an acceptance scenario
- [x] The one accepted risk (a Desktop off screen losing its wallpaper) is stated plainly in the spec and in the command's output
- [ ] Items to confirm with the maintainer: the exact wording of the warning and the nudge; whether `--days 0` should be allowed (it is, as the "everything no Desktop shows" mode); where stage 2 lands on the roadmap

## Notes

- Names things by what they say; no numbered cases.
