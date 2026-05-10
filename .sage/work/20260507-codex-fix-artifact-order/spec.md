---
title: "Spec: Codex fix artifact order enforcement"
status: completed
phase: spec
priority: high
created: 2026-05-07
updated: 2026-05-07
handoff: |
  Key decisions: Moderate+ fix enforcement must be artifact-first, not
  code-first. A 4-file fix is explicitly Moderate and requires plan.md plus
  manifest.md. Claude baseline review found that Claude currently has
  plan-first instruction coverage, but not equally explicit manifest-first
  generated-surface coverage.
  Review: independent review found no Major issues; AC2 minor wording was
  tightened so code-first cannot be cured by post-hoc artifacts.
  Open questions: exact hard-enforcement layer is left to the plan; likely a
  combination of fix workflow wording, Codex hook/audit tests, and Claude
  regression checks if shared workflow text changes.
  Risks: PreToolUse may not have enough session history to count "third file"
  edits, so the plan must be honest about block-time vs audit-time enforcement.
  Next agent should: write the plan before any implementation edits and keep
  unrelated F-1 changes separate.
---

# Spec: Codex fix artifact order enforcement

Deliverable: code

## Intent

Change the Codex port so agents reliably follow Sage fix artifact discipline:

1. A fix that expands beyond Surgical scope, including the observed 4-file fix case, must produce/update `plan.md` and `manifest.md`.
2. For Moderate+ fixes, the agent must update `manifest.md` and `plan.md` before changing implementation code.
3. The ordering rule is critical and must be represented as an enforceable Codex-port behavior, not only as a best-effort reminder.

## Critical Invariant: Artifacts Before Code

This is the central non-negotiable requirement of the cycle:

**For every Moderate+ fix, the agent must update `plan.md` and `manifest.md`
before editing implementation code, tests, config, or generated runtime
surfaces outside `.sage/work/<cycle>/` and `.sage/decisions.md`.**

Forbidden sequence:

1. Root cause approved.
2. Agent edits source/test/config/runtime files.
3. Agent later updates `manifest.md` / `plan.md`.

Required sequence:

1. Root cause approved.
2. Fix classified as Moderate+ or discovered to have expanded beyond Surgical.
3. `plan.md` is created or updated with the intended source/test/config files.
4. `manifest.md` is created or updated with `phase`, `status`, and `scope:` covering those files.
5. Only then may implementation edits begin.

If the Codex port can block violations before the edit, it should block them.
If a violation cannot be blocked with available hook inputs, it must be detected
as a failing audit/harness signal. Silent acceptance is not allowed.

## Problem Evidence

- Thread `019dff53-0420-7e41-9ec4-2772f7ca53d0`: an extended 4-file fix in `alex-os-dev` proceeded without a `.sage/work/<initiative>/plan.md` / `manifest.md`, even though Sage fix workflow classifies 3-5 files as Moderate.
- Thread `019dff20-7d8f-7902-aa38-27b06dd93b67`: BUG-F1-7 eventually updated `manifest.md` and `plan.md`, but code/test edits happened first. For Moderate+ fixes, this order is wrong.

## Claude Baseline And Intended Divergence

Current Claude Code behavior is related but not identical:

- `runtime/platforms/claude-code/setup/generate-claude-code.sh` always-on fallback says Moderate fixes should "write fix plan first" before implementing.
- The generated Claude `/fix` preamble says "Moderate+ (3+ files): write fix plan BEFORE implementing" and rejects "I know what to change" as a substitute for a plan file.
- `core/workflows/fix.workflow.md` says Moderate fixes create `manifest.md` when the fix plan is written, but this manifest requirement is separate from the strongest Claude generated fix preamble wording.
- `runtime/platforms/claude-code/hooks/sage-session-init.sh` surfaces `plan.md`, `spec.md`, and `brief.md`; it does not scan `manifest.md` as an active-work artifact in the same way.

Therefore this cycle is **not pure Claude parity**. The desired Codex behavior is intentionally stricter at runtime:

- Keep the shared Sage methodology consistent: Moderate+ fixes require `plan.md` and `manifest.md`.
- Make Codex enforcement stronger where Codex has hook/audit surfaces that can catch artifact-order violations.
- If implementation changes shared `core/workflows/fix.workflow.md`, the plan must include Claude regression/parity checks so Claude behavior is changed deliberately, not accidentally.
- If Codex diverges from Claude, the divergence must be documented as platform-specific enforcement, not hidden inside shared workflow wording.

## Required Behavior

### R1: Moderate Fix Artifact Requirement

When a fix is or becomes Moderate, Codex must require a fix cycle with:

- `.sage/work/<cycle>/manifest.md`
- `.sage/work/<cycle>/plan.md`
- `plan.md` describing files to change, tests to add/modify, and rollback approach
- `manifest.md` containing scope entries for all planned implementation and test files

A 3-5 file fix, any test infrastructure change, or any error-handling pattern change is Moderate by definition.

### R2: Artifact-First Ordering

For Moderate+ fixes, Codex must update Sage state before implementation:

1. Confirm root cause.
2. Classify scope.
3. Write or update `plan.md`.
4. Write or update `manifest.md`, including `scope`.
5. Only then edit source/test/config files outside the active cycle directory.

The system must treat code-first Moderate+ edits as a process violation.

R2 implements the Critical Invariant above. If any later plan or implementation
choice conflicts with this invariant, the invariant wins.

### R3: Scope Expansion Guard

If an initially Surgical fix grows beyond 2 files, Codex must stop before the third file edit and move to Moderate flow:

- update/create `plan.md`
- update/create `manifest.md`
- ask for approval if required by workflow gate
- proceed only after artifacts are current

### R4: Codex-Port Surfaces

The implementation must decide and update the appropriate Codex surfaces. Candidate surfaces include:

- `core/workflows/fix.workflow.md`
- Codex generated instruction surfaces under `runtime/platforms/codex/setup/lib/`
- PreToolUse hook logic under `runtime/platforms/codex/hooks/`
- tests under `runtime/platforms/codex/**/tests/`
- harness/transcript checks if needed to prove agent behavior

Any change to shared `core/workflows/fix.workflow.md` must be paired with a Claude impact check because Claude generators consume the same shared workflow.

## Boundaries

This cycle must not:

- redefine the whole Sage methodology
- loosen the existing PreToolUse cycle-scope guard
- silently complete or commit the unrelated in-progress F-1 changes
- require `spec.md` for normal fix workflow; `spec.md` remains a build/architect requirement, not a fix requirement
- block Surgical 1-2 file fixes that correctly complete in one session
- assume Codex/Claude parity without first recording the current Claude behavior and intended divergence

## Acceptance Criteria

AC1. A test or harness check fails before the change and passes after, proving a 4-file fix cannot proceed without Moderate fix artifacts.

AC2. A test or harness check fails before the change and passes after, proving
the Critical Invariant: code/test/config edits for a Moderate+ fix are either
blocked before the edit or recorded as a failing violation that cannot be cured
by writing `plan.md` / `manifest.md` afterward.

AC3. Existing Surgical fix behavior remains allowed for 1-2 file fixes when root cause and scope gates are satisfied.

AC4. Existing cycle-self and `.sage/decisions.md` implicit scope behavior remains intact.

AC5. Documentation/instructions in generated Codex surfaces clearly state the artifact-first ordering rule.

AC6. If shared `core/workflows/fix.workflow.md` changes, verification includes a Claude generator/regression check proving the generated Claude `/fix` behavior remains intentional and non-regressive.

AC7. Verification output is pasted at completion and includes relevant Codex hook/setup tests plus any new harness checks.

## Risks

- Over-enforcement could block legitimate Surgical fixes or bootstrap creation of the first manifest.
- Hook-only enforcement may not understand "third file edit" without session-level state.
- Instruction-only enforcement may reduce but not prevent failures; the plan must be honest about which layer provides hard enforcement.
- Shared-workflow edits could accidentally change Claude behavior without corresponding Claude tests.
- A future agent may treat artifact-first as ordinary guidance instead of the
  critical invariant; plan and manifest must preserve this priority.

## Open Questions For Plan

1. Can current PreToolUse inputs reliably count non-cycle implementation files in a fix, or do we need a transcript/turn-audit enforcement layer?
2. Should hard enforcement be "block" at PreToolUse time or "detect and fail" in PostToolUse/Stop audit?
3. Which generated Codex instruction surface is strongest for this rule: workflow loader, AGENTS.md prefix, or config-level instructions?
4. Should the implementation update shared fix workflow text, Codex-only generated instructions, or both?
