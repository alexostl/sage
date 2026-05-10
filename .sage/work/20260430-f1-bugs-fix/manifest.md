---
cycle_id: "20260430-f1-bugs-fix"
workflow: fix
phase: completed
status: completed
created: "2026-04-30"
updated: "2026-05-07"
title: "F-1 Phase 1 bugs fix (7 bugs — 6 Major + 1 Minor)"
scope:
  - ".sage/work/20260430-f1-bugs-fix/*"
  - ".sage/decisions.md"
  - "core/workflows/build.workflow.md"
  - "runtime/platforms/codex/setup/lib/skills-deploy.sh"
  - ".sage/work/20260429-codex-port-rewrite/qa-report.md"
  - "runtime/platforms/codex/hooks/lib/active_init.sh"
  - "runtime/platforms/codex/hooks/lib/bootstrap_check.sh"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/active_init.bats"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - "runtime/platforms/codex/setup/generate-codex.sh"
  - "runtime/platforms/codex/setup/lib/*.sh"
  - "runtime/platforms/codex/setup/tests/*.bats"
context_summary: |
  /qa identified 4 bugs; F-1 re-run #1 surfaced a 5th (BUG-F1-5: predicate
  has no implicit allow for cycle-self dir + decisions.md). BUG-F1-2 was
  retracted mid-pass on a simplified probe, then reconfirmed when re-run T2
  reproduced it on a realistic markdown body — yq v4.53.2 exits non-zero on
  multi-doc streams with malformed later docs, even after emitting correct
  stdout for earlier docs.

  All 7 bugs sit on the hot path of cycle lifecycle. Implementation order
  (as executed): Fix 2 (manifest_yaml helper) → Fix 3 (scope normalization)
  → Fix 1 (bootstrap exception, with bootstrap_check.sh extracted) → Fix 4
  (gitignore for hook-only writers) → Fix 5 (pre-seed scope_globs with
  cycle-self + decisions.md, surfaced by re-run #1) → Fix 6 (persist
  plan-approved implementation scope before Step 6) → Fix 7 (generated skill
  loaders point to `sage/core/workflows/*`, not missing `core/workflows/*`).

  Verification: full bats sweep is GREEN (238/238). Minimal targeted tests
  after Fix 7 are GREEN: Stage 7 loader suite (8/8), PreToolUse regression
  filter (7/7), and a generated-loader smoke check confirms
  `sage/core/workflows/build.workflow.md`. Final F-1 run
  `qa/run-20260506T234800/` completed T1-T5 with 0 PreToolUse blocks and
  doctor 8 ok / 0 warn / 0 fail on every turn. The cycle is closed with one
  accepted non-blocking residual: `signals.8_decisions_missing.count=1`.

  Lessons captured: (a) retracting from a simplified probe is itself a bug —
  reproduce under realistic conditions; (b) hook predicates layered on top
  of each other can mask downstream bugs — fix one and the next emerges;
  (c) yq v4.x partial-stdout-on-error is an under-documented edge.
---

# F-1 Phase 1 Bugs — Fix Manifest

**Source:** [QA report](.sage/work/20260429-codex-port-rewrite/qa-report.md) + F-1 re-runs (7 bugs)
**Verdict to clear:** v1 ship readiness — re-run F-1 Phase 1 with 0 PreToolUse
blocks across T1-T5 + doctor 8 ok / 0 warn.

## Bugs in scope

1. **BUG-F1-1** PreToolUse bootstrap chicken-egg (Major)
2. **BUG-F1-2** Manifest YAML parsing rejects `---` frontmatter on realistic
   markdown body (Major) — retracted then RECONFIRMED via F-1 re-run T2
3. **BUG-F1-3** Scope check trips on relative-vs-absolute path mismatch (Major)
4. **BUG-F1-4** Hook-only log files committed to git (Minor)
5. **BUG-F1-5** Predicate has no implicit allow for cycle-self dir +
   `.sage/decisions.md` (Major) — surfaced by F-1 re-run #1 after Fixes 1+2+3
6. **BUG-F1-6** Build workflow did not persist plan-approved implementation/test
   paths into `manifest.scope` before Step 6 (Major) — surfaced by F-1 re-run
   `qa/run-20260506T212108/`
7. **BUG-F1-7** Codex skill loader pointed at missing
   `core/workflows/<wf>.workflow.md` instead of deployed
   `sage/core/workflows/<wf>.workflow.md` (Major) — surfaced by F-1 re-run
   `qa/run-20260506T214503/`

## Verification

- Bats sweep GREEN: 227 baseline + 11 new = **238 cases** ✅
- Minimal post-Fix-7 tests GREEN:
  - `bats runtime/platforms/codex/setup/tests/stage7-skills.bats` → 8/8
  - `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats --filter 'BUG-F1-5|BUG-F1-3|bootstrap exception'` → 7/7
  - Generated skill smoke: `sage:build` loader points at
    `sage/core/workflows/build.workflow.md`
- Re-run [qa/runner.sh](.sage/work/20260429-codex-port-rewrite/qa/runner.sh):
  - FINAL: `qa/run-20260506T234800/` completed T1-T5 with 0 PreToolUse blocks.
    Doctor snapshots for T1-T5 were all 8 ok / 0 warn / 0 fail.
    Signals: workflow_entry 5/5, phase_jump 0, bypass_mutation 0,
    doctor_s1 0. Accepted residual: decisions_missing 1.
