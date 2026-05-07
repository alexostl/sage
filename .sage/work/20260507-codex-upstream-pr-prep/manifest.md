---
cycle_id: "20260507-codex-upstream-pr-prep"
title: "Codex upstream PR preparation"
workflow: build
phase: intake
status: paused
created: 2026-05-07
updated: 2026-05-07
owner: alexostl
scope:
  - ".sage/work/20260507-codex-upstream-pr-prep/*"
  - ".sage/decisions.md"
  - ".github/workflows/*"
  - ".githooks/pre-commit"
  - "README.md"
  - "bin/sage"
  - "bin/sage-close"
  - "bin/sage-install-hooks"
  - "runtime/platforms/codex/**"
---

# Cycle: Codex upstream PR preparation

## State

**Current phase:** intake — candidate work captured, but no Sage plan has been
authored or approved yet.
**Next step:** Resume with `/sage:build` or `/continue`, classify scope, and
write the proper next artifact before implementation.

## Context summary

`codex-port` now contains the selective Codex rewrite update and passed the
local Codex Bats suites. Before opening an upstream PR, self-host needs cleanup
so the public-facing branch story is clear and reviewers can verify behavior.
The old git pre-commit / `sage-close` model is still present on
`self-host/main`, but it depends on the removed `verification_check.py` module
and does not match the new Codex hook architecture. Treat that old model as a
candidate cleanup target, not as an active feature.

## Decisions so far

- Do not include private/self-host research docs in GitHub branch tips.
- Treat `.sage/work/` as the source of truth for open actionable work.
- Keep the current Codex port based on Codex hooks: `SessionStart`,
  `PreToolUse`, `PostToolUse`, and `Stop`.
- Defer any future git pre-commit ergonomics to a new design that does not
  depend on `sage-close` or `verification_check.py`.
- Do not create `plan.md` for this cycle until the work is explicitly resumed
  and reaches the Sage planning checkpoint.

## Candidate work to evaluate when resumed

- Remove the old git-hook close-out model from `self-host/main`:
  `.githooks/pre-commit`, `bin/sage-close`, `bin/sage-install-hooks`,
  `sage install-hooks`, and README references.
- Add CI for the Codex port Bats suites:
  `bats runtime/platforms/codex/hooks/tests runtime/platforms/codex/setup/tests`.
- Run one real Codex smoke/harness pass before marking the upstream PR ready:
  `runtime/platforms/codex/harness/run-harness.sh`.

## Open questions

- Whether to open the upstream PR as draft first or wait until CI + harness are
  both green. Current recommendation: draft after CI exists, ready after harness.

## Handoff guidance

Do not put this checklist back into `.sage/docs/`; this is actionable work, not
project knowledge. Do not implement directly from this manifest. Resume the
cycle, classify scope, and create the required Sage artifact before code edits.
