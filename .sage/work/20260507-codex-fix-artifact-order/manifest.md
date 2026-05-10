---
cycle_id: "20260507-codex-fix-artifact-order"
workflow: build
phase: verify
status: completed
created: 2026-05-07
updated: 2026-05-07 01:15
title: "Codex fix artifact order enforcement"
scope:
  - ".sage/work/20260507-codex-fix-artifact-order/*"
  - ".sage/decisions.md"
  - "core/workflows/fix.workflow.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/turn-audit.sh"
  - "runtime/platforms/codex/hooks/lib/artifact_order.sh"
  - "runtime/platforms/codex/hooks/tests/*"
  - "runtime/platforms/codex/harness/lib/aggregate-signals.sh"
  - "runtime/platforms/codex/harness/README.md"
  - "runtime/platforms/claude-code/setup/generate-claude-code.sh"
---

# Cycle: Codex fix artifact order enforcement

## State

**Current phase:** verify — implementation complete and focused verification passed.
**Next step:** Present completion checkpoint to user.
**Artifacts:**
- brief.md: not-required
- spec.md: completed
- plan.md: completed
- implementation: completed
- quality-gates: passed
- qa-report.md: not run
- design-review.md: not run

## Context summary

This cycle exists because recent Codex threads showed two process failures that must become harder to repeat: a 4-file fix was allowed to proceed without Moderate fix artifacts, and another Moderate fix updated code before updating `manifest.md` / `plan.md`. The user marked the ordering requirement as critical. The spec now names it as the Critical Invariant: for every Moderate+ fix, `plan.md` and `manifest.md` must be updated before source/test/config/runtime edits outside the cycle metadata. The change should strengthen the Codex port's behavioral contract and tests without disturbing unrelated local changes.

## Decisions so far

- 2026-05-07: Treat this as Standard build scope because it changes Codex-port behavior across workflow instructions, enforcement surfaces, and tests.
- 2026-05-07: User requirement is critical: for Moderate+ fixes, update `manifest.md` and `plan.md` before code edits.
- 2026-05-07: Spec approved via `[A]`; planning may begin, but implementation still requires plan approval and manifest scope persistence first.
- 2026-05-07: Independent spec review found missing Claude baseline; user chose `[R]`, so cycle returned to spec revision before planning.
- 2026-05-07: User clarified that artifact-first ordering is critical and must be explicit, not scattered through normal requirements.
- 2026-05-07: Independent review approved the revised Critical Invariant spec; AC2 was tightened so post-hoc artifacts cannot cure code-first violations.
- 2026-05-07: Plan v2 drafted with Claude baseline first, red regressions before implementation, and a non-negotiable implementation gate.
- 2026-05-07: User approved plan via `[A]`; manifest scope was persisted before implementation edits.

## Open questions

- None at completion checkpoint.

## Provenance

| Key | Value |
|-----|-------|
| Repo | `https://github.com/alexostl/sage.git` |
| Branch | `selfhost` |
| Commit | `89cdb91` |
| Working tree | `dirty: .gitignore; AGENTS.md.user-backup-20260507T003519` |

## Handoff guidance

The user is not asking for a cosmetic wording change; they want the Codex port to prevent a real process failure. The artifact-first invariant is approved and the plan is approved. Continue with Task 1 first: establish Claude baseline and decide whether shared workflow edits are needed. Do not edit files outside the manifest scope; if Task 1 or Task 2 discovers extra files are needed, update plan and manifest before editing them.
