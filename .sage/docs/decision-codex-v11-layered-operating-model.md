---
title: "Decision: Codex v1.1 layered operating model"
status: proposed
date: 2026-05-07
cycle_id: "20260507-codex-operating-model-v11"
related:
  - ".sage/work/20260507-codex-operating-model-v11/brief.md"
  - ".sage/docs/decision-codex-instruction-surfaces.md"
  - ".sage/docs/decision-codex-validate-mutation-predicate.md"
  - ".sage/docs/decision-codex-stop-hook-scope.md"
  - ".sage/docs/decision-codex-mcp-stack.md"
---

# Decision: Codex v1.1 layered operating model

## Context

The Codex v1 port currently uses generated `AGENTS.md`, skill loader stubs,
`.codex/config.toml`, lifecycle hooks, `sage status`, `sage doctor`, and a real
Codex harness. First-days fieldwork showed that the hard part is not adding one
more rule. The hard part is deciding which surface owns which behavior.

Official Codex docs make the same split visible:

- `AGENTS.md` is durable, layered instruction context loaded at session start,
  with a default 32 KiB project-doc cap.
- `config.toml` controls durable runtime behavior such as sandbox, approvals,
  hooks, project trust, MCP, and instruction discovery knobs.
- Hooks are lifecycle guardrails, but OpenAI docs state `PreToolUse` is not a
  complete enforcement boundary because equivalent work can often move through
  another tool path.
- Codex best practices recommend reusable guidance, planning for difficult
  tasks, tests/checks/review, MCP for external context, and skills for repeated
  work.

Original Sage docs define a platform-agnostic process framework: `.sage/work`
and artifact frontmatter are state, `.sage/decisions.md` is reasoning context,
`.sage/docs` is durable project knowledge, and workflows calibrate process
weight to task risk.

## Options Considered

### Option A: Instruction-heavy model

Put most v1.1 behavior into generated `AGENTS.md`.

Rejected because `AGENTS.md` is excellent for durable orientation, but it is not
a state machine, recovery surface, or verification mechanism. It also has a
practical instruction budget; stuffing the whole operating model into it would
make the agent worse at the common path.

### Option B: Hook-heavy model

Encode most behavior as blocking Codex hooks.

Rejected because official Codex docs describe hooks as lifecycle automation,
not a complete enforcement boundary. `PreToolUse` cannot honestly intercept
every equivalent shell/config/tool path. Hook-heavy design would overpromise
security and recreate the overblocking failure seen during this architect cycle.

### Option C: MCP/workflow-engine-first model

Build or require a workflow engine/MCP as the primary authority for state,
routing, and capture.

Deferred because v1.1 can solve the observed failures with existing Sage
artifacts, generated guidance, status/recovery UX, hooks, audit, and tests.
MCP remains a valid future integration if a concrete layer gap appears, but
making it first-order now would add platform complexity before the current
contract is coherent.

### Option D: Status/doctor-only model

Keep hooks and instructions mostly as-is, and rely on `status`/`doctor` to
explain state after failures.

Rejected because many failures happen during mutation or long unattended work.
Read-only diagnosis alone would still let agents drift, misroute findings, or
stall on repairable state issues.

### Option E: Layered operating model

Assign each responsibility to the lightest surface that can honestly own it:
instructions for orientation, workflows for process, artifacts for state,
status/doctor/hooks for recovery, hooks for narrow guardrails, audit for
non-interceptable paths, and harnesses for agent behavior.

Chosen because it preserves Sage's adaptive-weight philosophy while matching
Codex's actual runtime affordances and limits.

## Decision

Codex v1.1 uses a layered operating model:

1. **Instruction layer:** generated `AGENTS.md` and compact project
   `developer_instructions` steer behavior and vocabulary. This layer must be
   concise, imperative, and aligned with official Codex instruction discovery.
2. **Workflow layer:** Sage workflow skill stubs load full workflow definitions.
   This layer owns methodology, checkpoints, and human interaction shapes.
3. **State layer:** `.sage/work/*/manifest.md`, core artifacts, and
   `.sage/decisions.md` are the source of truth. Conversation is never the
   source of workflow state.
4. **Recovery UX layer:** `sage status`, `sage doctor`, SessionStart context,
   and hook messages explain the next legal move when the state is invalid or
   ambiguous.
5. **Guardrail layer:** hooks block only where the Codex runtime can actually
   intercept safely. Blocking hooks must be pure functions of disk state and
   must not claim stronger guarantees than Codex provides.
6. **Audit layer:** Stop/PostTool-style checks record bypasses, post-hoc
   artifact ordering, and suspicious state transitions that blocking hooks
   cannot prevent.
7. **Verification layer:** Bats covers deterministic generator/hook behavior;
   the real Codex harness covers agent/runtime behavior.
8. **Deferred integration layer:** MCP/workflow-engine work remains optional
   until a v1.1 design point proves that bash/config/instruction surfaces are
   insufficient.

## Rationale

This model keeps Sage honest about Codex. `AGENTS.md` is important, but it is
not a runtime state machine. Hooks are powerful, but not a full security
boundary. `status` and recovery text matter because many real failures happen
at the point where the agent needs to know what it can legally do next.

The model also preserves Sage's adaptive weight: ordinary conversation stays
light; Standard+ work gets artifacts; Moderate+ fixes are artifact-first; and
architect-level changes get brief/spec/plan checkpoints.

## Consequences

- The spec must map every failure mode to one or more explicit layers.
- Generated guidance must not duplicate the entire workflow library.
- Hooks must be worded as process guardrails, not absolute enforcement.
- Any future MCP work must be justified by a layer gap, not by architectural
  neatness alone.
- Verification must include both deterministic tests and at least one real
  Codex behavior check when the feature depends on agent compliance.
- Reversal is layer-by-layer: instruction wording, hook predicates,
  status/continue visibility, Capture Router, safe auto-fix, and harness
  requirements can be rolled back independently without deleting user artifacts.
