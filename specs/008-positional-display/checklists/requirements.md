# Specification Quality Checklist: Display as a Positional Argument (Feature F8)

**Created**: 2026-10-09 | **Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details beyond the grammar and error messages that are the feature
- [x] Focused on user value (a short, display-first syntax for several monitors)
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous (interpretation table and error table in the contract)
- [x] Success criteria are measurable
- [x] All acceptance scenarios and edge cases are defined (quoting, lone argument, digits, `--`, `main`)
- [x] Scope is bounded (`set`, `remove`, `undo`, `show`; `--display` kept)
- [x] Dependencies and assumptions identified (specs 006 and 007; quoting is the shell's job)

## Feature Readiness

- [x] Every functional requirement has an acceptance scenario
- [x] The one behavior change (E3) is called out and justified (version 0.2.0)

## Notes

- Decisions are the maintainer's of 2026-10-09: display first; quoted names with spaces; wrong counts are errors;
  aliases avoid quotes. The lone-argument refusal (FR-008) is the recommended safeguard and not yet confirmed by
  the maintainer.
