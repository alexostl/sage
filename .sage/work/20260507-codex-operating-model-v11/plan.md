---
title: "Plan: Codex operating model v1.1"
workflow: architect
phase: plan
status: completed
created: 2026-05-07
updated: 2026-05-07
cycle_id: "20260507-codex-operating-model-v11"
spec: ".sage/work/20260507-codex-operating-model-v11/spec.md"
handoff: |
  Plan approved by user after 120-second auto-review rerun and revisions.
  Start Milestone 1 with failing hook tests for architect ADR/design-doc
  overblocking and empty-cycle bootstrap recovery.
---

# Plan: Codex operating model v1.1

## Planning Constraints

- Do not center upstream PR readiness.
- Preserve Sage's two-folder convention: `.sage/docs` for durable project
  knowledge, `.sage/work` for initiative work.
- Preserve conversation-first routing: broad ambiguous prompts propose
  workflow and wait; direct action mandates enter workflow.
- Prefer deterministic artifact routing without asking the user about storage.
- Prefer safe auto-fix for reversible metadata/state hygiene during long
  unattended tasks.
- Treat hooks as honest guardrails, not a complete security boundary.
- Use deterministic tests by default and real Codex harness only for
  agent/runtime behavior claims.
- Carry forward the unresolved ADR minor: add rejected alternatives to the
  governing ADR after hook predicate repair allows legal ADR revisions.

## Milestone 1: Repair Hook Predicates And Bootstrap

**Outcome:** Legitimate architect/design documentation work can proceed without
being misclassified as Moderate+ fix implementation, and bootstrap recovery is
clear.

**Dependency override:** The spec migration path prefers contract/wording
baseline before hook behavior changes. This plan intentionally front-loads hook
repair because the current hook blocks legal architect ADR revision and would
interfere with the plan itself. Milestone 1 must stay narrow: repair the
overblocking/bootstrap predicate and update the blocked ADR; broader recovery
wording still belongs to later milestones.

**Scope:**

- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
- `runtime/platforms/codex/hooks/lib/artifact_order.sh`
- `runtime/platforms/codex/hooks/lib/bootstrap_check.sh`
- Codex hook/setup tests under `runtime/platforms/codex/**`
- Generated recovery wording if hook messages are produced from setup code

**Tasks:**

1. Add failing tests for the current regression: multiple architect
   same-cycle spec/ADR/doc revisions must not trigger Moderate+ fix
   implementation blocking.
2. Add failing tests for empty-cycle bootstrap recovery: an empty target cycle
   directory should either be recoverable or produce the exact next legal move.
3. Refactor artifact-order enforcement so Moderate+ fix implementation
   counting excludes architect/design artifacts and same-cycle documentation
   writes.
4. Improve blocked-hook recovery messages to include detected state, why it
   matters, and the next legal move.
5. Run focused hook/setup tests.
6. After the hook fix is verified, update
   `.sage/docs/decision-codex-v11-layered-operating-model.md` with the
   reviewer-requested rejected alternatives.

**Done when:**

- The regression that blocked this cycle's ADR revision has a failing-then-
  passing deterministic test.
- Architect design docs can be revised through `apply_patch` without requiring
  a premature `plan.md`.
- Bootstrap trap behavior is tested.
- The governing ADR contains options considered.

## Milestone 2: State, Status, Continue, And Manifest Lifecycle

**Outcome:** `status` and `/continue` show active work and parked work without
confusing resumable intake with implementation-active cycles.

**Scope:**

- `core/workflows/status.workflow.md`
- `core/workflows/continue.workflow.md`
- Codex generated `AGENTS.md` state wording
- Any status/doctor implementation or tests in `runtime/platforms/codex/**`

**Tasks:**

1. Define the state contract for `in-progress`, `paused`, `intake`,
   `completed`/`complete`, and invalid frontmatter.
2. Update status guidance/output expectations to show active cycles first and
   paused/intake cycles in separate sections with next actions.
3. Decide and document which documentation-routing warnings belong in
   `status` versus `doctor`:
   - `status` should surface current actionable/resumable state and brief next
     actions;
   - `doctor` should diagnose structural inconsistencies, stale/misrouted docs,
     and repair suggestions.
4. Update continue guidance so a single clear resumable candidate can be
   offered deterministically, while multiple candidates require user choice.
5. Align generated `AGENTS.md`, SessionStart context, and hook wording with the
   same lifecycle language.
6. Add deterministic tests/fixtures for active, paused, intake, completed,
   missing, and malformed states.
7. Add deterministic tests for the status-vs-doctor warning split.

**Done when:**

- Paused/intake cycles no longer disappear from status.
- `in-progress` remains the only implementation-active state for hooks.
- Status/continue recovery text teaches the next legal move.
- Documentation-routing warnings have a documented status/doctor split and
  tests for both surfaces.

## Milestone 3: Artifact Governance And Capture Router

**Outcome:** Findings, TODOs, ADRs, research, checkpoint decisions, and
corrections route deterministically without asking the user about storage.

**Scope:**

- `runtime/platforms/codex/setup/lib/agents-md.sh`
- `core/workflows/review.workflow.md`
- `core/capabilities/orchestration/sage-navigator/SKILL.md`
- `.sage-memory` learning/capture guidance if applicable
- Documentation convention references under `docs/**`
- Tests for generated guidance and workflow text

**Tasks:**

1. Encode the artifact router in generated `AGENTS.md` and workflow guidance:
   docs, work, work/research, decisions, memory, and intake.
2. Define the Capture Router threshold between same-cycle follow-up and new
   minimal intake cycle.
3. Update review/capture guidance so actionable findings do not go directly to
   `.sage/decisions.md` or loose `.sage/docs`.
4. Add a minimal intake manifest shape for unrelated actionable findings with
   `needs-triage`, source cycle, suggested workflow, and no implementation
   started.
5. Add deterministic tests for the most common wrong route: actionable TODO in
   `.sage/docs`.

**Done when:**

- Agent-facing guidance has a deterministic destination for each artifact
  class.
- Uncertain actionable findings fall back to minimal intake, not user storage
  questions or `.sage/docs`.
- Review/capture no longer treats `.sage/decisions.md` as a backlog.

## Milestone 4: Recovery-First Safe Auto-Fix

**Outcome:** Sage keeps long unattended tasks moving through safe, reversible
state/metadata repairs and stops only for scope, product, risk, destructive
changes, or ambiguous ownership.

**Scope:**

- Hook recovery messages and predicates
- `status`, `continue`, `doctor` recovery wording
- Generated `AGENTS.md` recovery principles
- Tests for allowed and denied auto-fix classes

**Tasks:**

1. Define safe auto-fix classes: minimal intake manifest creation,
   inferable frontmatter/handoff repair, deterministic finding routing,
   single-candidate continue, and same-cycle documentation scope updates.
2. Define hard-stop classes: implementation without approved artifacts,
   scope expansion, destructive actions, conflicting instructions, ambiguous
   repo ownership, and multiple equivalent active cycles.
3. Add tests for allowed auto-fix and hard-stop cases.
4. Update recovery wording to report detected state, action taken, next legal
   move, and severity.
5. Add durable logging/audit evidence for every safe auto-fix: what changed,
   why it was safe, source state, and resulting state.
6. Keep unsupported Bash/config mutation paths audit-first unless a concrete
   safe blocking predicate exists.

**Done when:**

- Safe auto-fix behavior is explicit, reversible, and tested.
- Safe auto-fix logging/audit evidence is durable and test-covered.
- Recovery messages teach instead of merely rejecting.
- Audit-only limitations are documented honestly.

## Milestone 5: Risk-Based Verification Harness

**Outcome:** Deterministic tests cover framework outputs; real Codex harness
checks cover agent/runtime behavior.

**Unique scope:** Earlier milestones own focused deterministic tests for their
surfaces. This milestone does not duplicate those tests; it assembles the
cross-surface verification policy and adds the small real Codex harness suite
for behaviors that deterministic tests cannot prove.

**Scope:**

- Codex Bats tests and fixtures
- Existing real Codex harness scripts/fixtures
- Documentation of what requires harness evidence

**Tasks:**

1. Audit the deterministic test map from Milestones 1-4 and identify any
   uncovered spec claim before adding new tests.
2. Add any missing cross-surface deterministic tests that cannot belong cleanly
   to Milestones 1-4.
3. Add real Codex harness scenarios for:
   - conversational read-only prompt does not create workflow state;
   - explicit workflow/action prompt creates or resumes the correct manifest;
   - blocked mutation returns next legal move;
   - Capture Router creates minimal intake for unrelated actionable finding;
   - safe auto-fix keeps a reversible metadata/state issue moving;
   - documentation-routing correction is captured in `.sage-memory` and used
     on the next relevant task;
   - cross-repo task uses the target repo's state.
4. Define when harness failures block release claims and when they are
   advisory for unrelated text-only changes.
5. Update any docs/status output that claim behavior to reference the
   appropriate verification class.

**Done when:**

- Fixture tests cover deterministic framework behavior.
- Real harness covers the UX behaviors that depend on Codex following the
  operating model.
- v1.1 cannot be marked complete without evidence for both classes.

## Milestone 6: Cross-Repo Ownership And Final Coherence

**Outcome:** The edited repository owns state, memory, scope, gates, and
recovery; `sage-selfhost` does not impersonate target repo workflow state.

**Scope:**

- Generated `AGENTS.md` cross-repo wording
- Hook scope checks and recovery text
- Status/doctor guidance
- Real harness cross-repo scenario
- Final docs/decision cleanup

**Tasks:**

1. Align instructions and hooks around target-repo ownership.
2. Add or update tests for editing outside the active repo/cycle scope.
3. Run full focused verification across changed surfaces.
4. Review the final artifact map: spec, plan, ADR, decisions, memory, docs.
5. Close or carry forward any intake items created during v1.1.

**Done when:**

- Cross-repo behavior has explicit wording and at least one behavior-level
  harness check.
- All v1.1 claims map to instruction, workflow, state, recovery, guardrail,
  audit, deterministic test, real harness, config/MCP, or explicit limitation.
- Final completion checkpoint can honestly state what is enforced, audited,
  tested, and intentionally out of scope.

## Verification Plan

At each milestone:

- Start with failing deterministic tests for behavior changes when practical.
- Run focused tests for the touched surface before claiming the milestone.
- Add real Codex harness evidence only for behavior that depends on the agent
  following instructions or runtime hook/recovery behavior.
- Paste actual command output at completion checkpoints.

## Open Items Carried Forward

- ADR options/trade-offs update is blocked until Milestone 1 fixes hook
  overreach.
- Final Bash interception decision remains open: v1.1 may stay audit-only if
  no safe low-false-positive blocking predicate is found.
- Capture Router threshold between same-cycle follow-up and separate intake
  must be specified before implementation.
