# Specification Quality Checklist: Display as a Positional Argument (Feature F8)

**Created**: 2026-10-09 | **Revised**: 2026-10-09 | **Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details beyond the grammar and error messages that are the feature
- [x] Focused on user value (a short, display-first syntax for several monitors)
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No open decisions remain (the lone-word refusal and no short flag were decided 2026-10-09)
- [x] Requirements are testable and unambiguous (the tables and the error list in the contract)
- [x] Success criteria are measurable (a table-driven test, a mechanical check of the commands)
- [x] Acceptance scenarios and edge cases are defined (quoting, lone word, digits, `--`, `main`, `--label`, repeats)
- [x] Scope is bounded (`set`, `remove`, `undo`, `show`; `--display` kept; several displays left to F3)
- [x] Dependencies and assumptions identified (specs 006 and 007; quoting is the shell's job)

## Feature Readiness

- [x] Every functional requirement has an acceptance scenario
- [x] The two changes of behavior are called out and justified (version 0.2.0)
- [x] Error messages are named by what they say, and suggested commands quote names with spaces

## Notes

- Revised after a critical review: hints re-quote; the display is resolved once; positions come from separate
  parser arguments; `--label` added; repeated `--display` refused; the lone-word refusal marked open; a spike first.
