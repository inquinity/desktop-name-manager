# CI drafts (inactive)

`ci.yml` (a GitHub Actions workflow) and `dependabot.yml` are unreviewed drafts kept here so GitHub does
not run them: Actions reads workflows only from `.github/workflows/`, and Dependabot only reads
`.github/dependabot.yml`. The project uses no hosted CI before milestone M5 (security plan decision 4,
`specs/001-labels-and-cli/security-plan-2026-10-07.md`).

Before moving them back, review them (spec 001 task T006): the runner label (still marked TODO), pinned
dependency resolution (`--force-resolved-versions`), and requiring approval for first-time contributors'
pull requests in the repository settings.
