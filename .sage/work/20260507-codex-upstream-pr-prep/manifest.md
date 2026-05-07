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
- Strengthen Codex/Sage generated guidance for artifact routing:
  actionable TODOs, PR prep, next steps, candidate work, and "fix later"
  checklists should go to `.sage/work/<cycle>/manifest.md`, not `.sage/docs/`.
- Strengthen Codex/Sage generated guidance for intake state:
  `manifest.md` is valid for paused/intake work, but `plan.md` should only be
  created after an explicit workflow resume and planning checkpoint.
- Evaluate whether guidance is enough for the TODO-routing issue; if not, add
  a soft Codex audit warning when new `.sage/docs/` files look like actionable
  work rather than durable knowledge.
- Update `sage status` so `intake/paused` cycles clearly show that
  "manifest only, no plan yet" is the correct state.
- Fix Codex hook bootstrap/recovery UX for workflow artifacts:
  saying "entering workflow" is not enough; the hook recognizes a workflow only
  after an in-progress `manifest.md` exists. Avoid the trap where a premature
  `mkdir .sage/work/<cycle>` prevents the bootstrap allowance from creating the
  first manifest, and make the recovery message/action explicit.
- Add Codex review-finding capture guidance and/or hook UX:
  when a thread review produces actionable process findings, route them into
  `.sage/work/<cycle>/manifest.md` as intake TODOs instead of attempting to
  append them directly to `.sage/decisions.md` without an active cycle.
  Technical context to preserve for the future fix:
  `core/workflows/review.workflow.md` Step 5 currently instructs agents to
  prepend review findings to `.sage/decisions.md`, while Codex
  `pre-tool-validate.sh` only permits mutations when
  `active_init.sh` finds a manifest with `status: in-progress`. Manifests in
  `status: paused` or `status: completed` are not active for the hook. The fix
  should resolve that contract explicitly, preferably by having review create
  or resume a lightweight manifest before durable writes, rather than by adding
  a broad exception for `.sage/decisions.md`.
- Add the reviewed thread compliance cases as Codex/Sage regression examples:
  `019dff35` and `019dff5b` show correct review-driven recovery, `019dff66`
  shows lightweight read-only investigation that should not force artifacts,
  and `019dfff8` is the failure case where a multi-file fix skipped root-cause
  approval, scope approval, and Moderate fix artifacts before code edits.
- Strengthen Codex guidance for cross-repo fix scope:
  if a task starts in `sage-selfhost` but the actual edits land in another
  Sage-managed repo such as `alex-os-dev`, the target repo's `.sage` state and
  fix scope gates still apply. Do not treat cross-repo edits as exempt from
  `manifest.md` / `plan.md` requirements.
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
