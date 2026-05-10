---
cycle_id: "20260507-codex-upstream-pr-prep"
scope: standard
status: completed
created: 2026-05-07
updated: 2026-05-09 12:18
---

# Plan: Codex upstream PR preparation CI

## Status

Completed. The CI workflow exists at `.github/workflows/codex-port-ci.yml`,
the planned YAML and Bats verification passed on 2026-05-07, and the remaining
runtime/process findings are not part of this upstream-PR-prep scope.

## Goal

Prepare the selfhost branch to reject broken Codex-port changes before
merge by adding GitHub Actions CI for the Codex Bats suites.

## Scope

- Add a GitHub Actions workflow under `.github/workflows/`.
- Trigger the workflow on pull requests to `selfhost` and direct pushes
  to `selfhost`.
- Install the minimal runtime needed for the Codex Bats suites.
- Run:
  `bats runtime/platforms/codex/hooks/tests runtime/platforms/codex/setup/tests`.
- Leave the heavier real Codex harness as optional/manual follow-up, because it
  requires a working Codex CLI and model access.
- Do not remove or redesign the legacy git hook close-out model in this cycle.

## Verification

- `yamllint` or Ruby YAML parsing accepts the workflow syntax.
- Local Bats command passes:
  `bats runtime/platforms/codex/hooks/tests runtime/platforms/codex/setup/tests`.
- If local dependencies are missing, record the exact missing tool and the
  GitHub Actions install step that supplies it.
