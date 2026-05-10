---
title: "Plan: Codex fix artifact order enforcement"
status: completed
phase: plan
priority: high
created: 2026-05-07
updated: 2026-05-07
---

# Plan: Codex fix artifact order enforcement

**Spec:** `.sage/work/20260507-codex-fix-artifact-order/spec.md`  
**Mode:** build  
**Status:** approved  
**Started:** implemented  
**Last updated:** 2026-05-07

## Non-Negotiable Gate

This plan exists to enforce the spec's Critical Invariant:

**For Moderate+ fixes, `plan.md` and `manifest.md` must be updated before
source/test/config/runtime edits. Code-first then plan-after is invalid
pseudo-Sage. Post-hoc artifacts do not cure the violation.**

Before any implementation edit in this cycle:

1. This plan must be approved.
2. `manifest.md` must be updated to `phase: implement`.
3. `manifest.scope` must include every planned source/test path.
4. Only then may code edits begin.

## Constitution Constraints

- Follow Sage build gates: this plan must be approved before implementation.
- Write tests before implementation changes where feasible.
- Preserve unrelated local changes; do not fold unrelated F-1 or generated backup changes into this cycle.
- Verification must paste actual command output.
- If shared `core/workflows/fix.workflow.md` changes, include Claude regression checks because Claude generators consume the same shared workflow.

## Technology Decisions

Use layered enforcement:

- **Shared workflow layer:** clarify `core/workflows/fix.workflow.md` only if needed for cross-platform Sage semantics. Any change here must be verified against Claude generation.
- **Codex instruction layer:** generated `AGENTS.md` should surface the Critical Invariant in Codex's always-on instructions.
- **Codex enforcement/audit layer:** use PreToolUse for block-time checks only where available inputs are sufficient. Use turn audit or harness checks for session-history-dependent violations.
- **Regression layer:** add tests for both missing Moderate artifacts and artifact-order violations. A post-hoc plan/manifest write must remain a failing violation.

## Milestone 1: Baseline And Enforcement Design

Delivers: updated understanding before code changes.

- [x] **Task 1: Record Claude baseline and intended divergence**
  - **Read first:** `runtime/platforms/claude-code/setup/generate-claude-code.sh`, `runtime/platforms/claude-code/hooks/sage-session-init.sh`, `core/workflows/fix.workflow.md`, spec section "Claude Baseline And Intended Divergence"
  - **Files:** none
  - **Action:** Confirm current Claude behavior: plan-first wording exists; manifest-first wording is less explicit; session init scans plan/spec/brief, not manifest. Decide whether implementation needs shared workflow edits or Codex-only enforcement.
  - **Test:** none
  - **Verify:** implementation notes must state "shared workflow change: yes/no" and, if yes, which Claude regression command will be run.
  - **Depends on:** none

- [x] **Task 2: Map Codex enforcement inputs**
  - **Read first:** `runtime/platforms/codex/hooks/pre-tool-validate.sh`, `runtime/platforms/codex/hooks/turn-audit.sh`, `runtime/platforms/codex/setup/lib/agents-md.sh`, `runtime/platforms/codex/harness/lib/aggregate-signals.sh`
  - **Files:** none
  - **Action:** Determine what can be blocked before `apply_patch` and what must be detected after the turn. Do not guess; base the implementation on actual hook payload capabilities.
  - **Test:** none
  - **Verify:** implementation notes classify each acceptance criterion as block-time or audit-time.
  - **Depends on:** Task 1

## Milestone 2: Failing Regressions First

Delivers: red tests for the exact failures before implementation.

- [x] **Task 3: Add a regression for 4-file Moderate fixes without artifacts**
  - **Read first:** Task 2 notes, `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`, `runtime/platforms/codex/harness/README.md`
  - **Files:** chosen after Task 2; likely `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` or a new audit/harness test file
  - **Action:** Add a failing test/check proving a fix equivalent to 3-5 non-cycle files cannot proceed without Moderate fix artifacts.
  - **Test:** run the focused test and capture its failing output before implementation.
  - **Verify:** red output names missing `plan.md`/`manifest.md` or equivalent artifact violation.
  - **Depends on:** Task 2

- [x] **Task 4: Add a regression for code-first then plan-after**
  - **Read first:** Task 2 notes, `runtime/platforms/codex/hooks/turn-audit.sh`, any chosen audit/harness test patterns
  - **Files:** chosen after Task 2
  - **Action:** Add a failing test/check for the forbidden sequence: implementation edit happens first, then `plan.md`/`manifest.md` are written afterward.
  - **Test:** run the focused test and capture its failing output before implementation.
  - **Verify:** red output proves the violation cannot be cured by post-hoc artifact writes.
  - **Depends on:** Task 2

## Milestone 3: Implement Layered Enforcement

Delivers: AC1-AC6.

- [x] **Task 5: Strengthen fix workflow wording where appropriate**
  - **Read first:** `core/workflows/fix.workflow.md`, Task 1 notes
  - **Files:** `core/workflows/fix.workflow.md` only if Task 1 decides shared wording must change
  - **Action:** If needed, make Moderate+ flow explicitly artifact-first without requiring `spec.md` for normal fixes. If not needed, record the no-change decision in implementation notes.
  - **Test:** if changed, run Claude generation/regression check identified in Task 1.
  - **Verify:** inspect `/fix` wording and confirm Surgical 1-2 file fixes remain valid.
  - **Depends on:** Tasks 3-4

- [x] **Task 6: Implement Codex block/audit behavior**
  - **Read first:** Task 2 notes and failing tests from Tasks 3-4
  - **Files:** likely `runtime/platforms/codex/hooks/pre-tool-validate.sh`, `runtime/platforms/codex/hooks/turn-audit.sh`, `runtime/platforms/codex/harness/lib/aggregate-signals.sh`, and matching tests
  - **Action:** Implement the minimum enforcement needed so missing Moderate artifacts and code-first-then-plan-after are blocked or fail audit. Do not weaken existing cycle-scope behavior.
  - **Test:** regressions from Tasks 3-4 plus existing relevant hook/audit tests.
  - **Verify:** focused tests pass.
  - **Depends on:** Task 5

- [x] **Task 7: Surface the Critical Invariant in generated Codex instructions**
  - **Read first:** `runtime/platforms/codex/setup/lib/agents-md.sh`, `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`, spec Critical Invariant
  - **Files:** `runtime/platforms/codex/setup/lib/agents-md.sh`, `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - **Action:** Add concise always-on Codex wording: Moderate+ fixes must update `plan.md` and `manifest.md` before source/test/config edits; post-hoc artifacts do not cure the violation.
  - **Test:** Stage 3 test asserts generated AGENTS contains the rule.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - **Depends on:** Task 5

## Milestone 4: Verification And Close

Delivers: AC7 and completion evidence.

- [x] **Task 8: Run focused verification**
  - **Read first:** changed test files
  - **Files:** none
  - **Action:** Run focused hook/audit/setup tests touched by Tasks 3-7.
  - **Test:** all focused tests pass.
  - **Verify:** paste command output.
  - **Depends on:** Tasks 6-7

- [x] **Task 9: Run broader safe regression sweep**
  - **Read first:** `.sage/decisions.md` entry about repeated `bin-sage-wiring` hang
  - **Files:** none
  - **Action:** Run relevant broader Codex tests while avoiding or clearly disclosing known hanging full-suite paths unless separately fixed.
  - **Test:** Codex hooks tests plus focused setup tests pass.
  - **Verify:** paste command output and disclose skipped known-hang case if applicable.
  - **Depends on:** Task 8

## Implementation Scope To Persist After Approval

Before any implementation edit, update `manifest.md` with the final decided scope.
Initial candidate scope:

- `.sage/work/20260507-codex-fix-artifact-order/*`
- `.sage/decisions.md`
- `core/workflows/fix.workflow.md`
- `runtime/platforms/codex/setup/lib/agents-md.sh`
- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
- `runtime/platforms/codex/hooks/turn-audit.sh`
- `runtime/platforms/codex/hooks/lib/artifact_order.sh`
- `runtime/platforms/codex/hooks/tests/*`
- `runtime/platforms/codex/harness/lib/aggregate-signals.sh`
- `runtime/platforms/codex/harness/README.md`
- `runtime/platforms/claude-code/setup/generate-claude-code.sh` only if Task 1 finds a required Claude regression/generator fixture change

If Tasks 1-2 choose a narrower surface, reduce scope before implementation. If they choose additional files, update this plan and manifest before editing them.
