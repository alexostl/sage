---
title: "Brief: Codex operating model v1.1"
workflow: architect
phase: understand
status: completed
created: 2026-05-07
updated: 2026-05-07
cycle_id: "20260507-codex-operating-model-v11"
handoff: |
  Elicitation approved by user on 2026-05-07. Design must reconcile
  official OpenAI/Codex docs, original Sage framework docs, current Codex v1,
  fieldwork findings, and generated agent instruction surfaces. Before ADRs
  or spec depend on details, re-check primary source files/docs directly.
---

# Brief: Codex operating model v1.1

## Problem

Codex Sage v1 works, but its operating model is spread across generated
instructions, workflow docs, skills, hooks, status output, harnesses, local
lessons, and human conventions. First-days fieldwork showed that the weak
points are not isolated bugs; they appear wherever the agent lacks a clear next
legal move.

The most important ambiguity classes are:

- when a workflow is truly active;
- which artifact must exist before mutation;
- where review findings, TODOs, and process observations belong;
- which repository owns scope and gates during cross-repo edits;
- when manifest-only intake is correct;
- what is durable guidance, what is a runtime guardrail, and what is only audit
  or verification evidence.

This architect cycle is not centered on upstream PR readiness. It is a
post-fieldwork rebuild of the Codex operating model.

## Users

Primary users:

- The Sage maintainer/operator using Codex on `sage-selfhost`.
- Codex agents working inside Sage-managed repositories.

Secondary users:

- Future agents or reviewers resuming work from `.sage/work/`,
  `.sage/docs/`, and `.sage/decisions.md`.
- Codex agents operating in a different Sage-managed repository, such as
  `alex-os-dev`, after a task begins in `sage-selfhost`.
- Future platform adapters that need to learn from Codex without copying
  Codex-specific assumptions.

## Success Criteria

The v1.1 design succeeds if it produces a coherent operating model that:

- aligns official OpenAI/Codex docs with original Sage framework docs;
- explains current Codex v1 behavior without hiding its limitations;
- incorporates first-days fieldwork findings as explicit failure modes;
- classifies each operating concern into the right surface: instruction,
  skill/workflow, status/recovery UX, blocking hook, audit hook, deterministic
  test, real Codex harness, config/MCP, or explicit limitation;
- gives agents a clear next legal move at recovery points;
- preserves conversation-first routing while enforcing Sage after workflow
  entry;
- keeps documentation artifacts in their correct Sage locations.

## Source Benchmarks

The design must reconcile five sources of truth:

1. Official OpenAI/Codex documentation: `AGENTS.md` discovery, config,
   hooks, sandbox/approvals, slash commands, cloud execution, and validation
   expectations.
2. Original Sage framework documentation: workflow lifecycle, adaptive weight,
   artifact-first state, documentation conventions, gates, status, continue,
   review, and decisions.
3. Current Codex v1 implementation: generated `AGENTS.md`, skill loader stubs,
   `.codex/config.toml`, lifecycle hooks, `sage status`, `sage doctor`,
   setup tests, hook tests, and real Codex harness.
4. First-days fieldwork findings: workflow activation, artifact ordering,
   review capture, cross-repo scope, paused/intake visibility, hook bootstrap,
   documentation routing, and harness gaps.
5. Agent instruction surfaces as product: generated `AGENTS.md`, workflow text,
   skill loaders, hook messages, status output, recovery guidance, and review
   guidance.

Subagent research gathered during elicitation is reconnaissance only. Before
architecture decisions depend on a detail, the design phase must re-check the
relevant primary file or official doc directly.

## Scope

### Must Have

- Define one manifest lifecycle shared by generated guidance, hooks, `status`,
  `doctor`, and continuation behavior.
- Define documentation artifact governance: when the agent writes
  `.sage/docs/`, `.sage/work/<cycle>/`, `.sage/work/<cycle>/research/`,
  `manifest.md`, `brief.md`, `spec.md`, `plan.md`, and `.sage/decisions.md`.
- Map each operating-model problem to the correct surface: instruction,
  workflow/skill, status/recovery UX, blocking hook, audit hook, deterministic
  test, real harness, config/MCP, or explicit limitation.
- Make hook and status recovery messages teach the next legal move, not only
  reject or warn.
- Treat review/capture as a first-class flow with a safe route into manifest
  and decisions state.
- Define cross-repo ownership: the edited repository owns workflow state,
  scope, and gates.
- Require deterministic tests and real Codex harness evidence where behavior
  depends on actual Codex runtime behavior.

### Won't Have

- Do not center upstream PR readiness.
- Do not promise absolute enforcement through hooks.
- Do not commit to a full MCP workflow engine unless deeper design research
  proves it is necessary.
- Do not rewrite the whole Codex port from scratch.
- Do not turn ordinary conversation into mandatory workflow ceremony.

## Key Flows

### Workflow Entry and Mutation

1. Agent receives a prompt.
2. Agent classifies it as conversation, explicit workflow, action mandate, or
   ambiguity.
3. If workflow is required, agent creates or resumes the correct `manifest.md`.
4. `status`, hooks, and generated guidance agree on the cycle state.
5. Agent writes required artifacts before mutation.
6. Hooks either permit the mutation or explain the exact next legal move.
7. Implementation stays inside the target repository and manifest scope.
8. Verification is backed by deterministic tests and, when relevant, a real
   Codex harness run.
9. Review findings, TODOs, and learnings are routed to the correct artifact.
10. `/continue` can resume from disk without relying on conversation memory.

### Documentation Artifact Routing

1. Agent wants to write a document, finding, TODO, decision, or research note.
2. Agent classifies the artifact by purpose:
   durable project knowledge, initiative deliverable, initiative-specific
   research, actionable work/TODO, or checkpoint decision.
3. Agent writes to the correct location:
   `.sage/docs/`, `.sage/work/<cycle>/`, `.sage/work/<cycle>/research/`,
   `manifest.md`, or `.sage/decisions.md`.
4. If no active cycle exists and the write is actionable work, recovery UX
   instructs the agent to create or resume a manifest-backed cycle first.
5. `status` and `/continue` make the resulting state visible.

## Constraints

- Official OpenAI/Codex docs and original Sage framework docs are both
  benchmark sources.
- `AGENTS.md` is a primary Codex-native instruction layer, but it must stay
  concise and cannot carry the whole operating model alone.
- Hooks are guardrails, audit surfaces, and recovery surfaces; they are not a
  complete security boundary.
- Sage remains artifact-first: `.sage/work/` and frontmatter are state;
  `.sage/decisions.md` is reasoning context; `.sage/docs/` is durable
  project-level knowledge.
- Original Sage documentation defines a two-folder convention:
  `.sage/docs/` is durable project knowledge, while `.sage/work/` is
  per-initiative work. Codex v1.1 must preserve this distinction.
- Conversation-first routing remains part of the product. Enforcement begins
  after workflow entry, not during every read-only question.

## High-Risk Areas

- Treating conversational workflow entry as equivalent to on-disk activation.
- Letting `AGENTS.md`, hooks, status, and workflow docs use different state
  language.
- Letting hooks imply stronger enforcement than Codex actually provides.
- Hiding valid `paused` or `intake` cycles from `status`.
- Routing actionable work into `.sage/docs/` instead of `.sage/work/`.
- Writing review findings directly to `.sage/decisions.md` without a safe
  manifest-backed flow.
- Applying `sage-selfhost` scope to edits in another Sage-managed repo.
- Depending on shallow research summaries instead of primary sources.
- Trusting fixture tests without a real Codex harness pass for agent behavior.

## Open Questions for Design

- Which states should hooks consider active, resumable, blocked, or advisory?
- Should bash-file mutations remain audit-only, or should v1.1 expand
  prevention beyond `apply_patch`?
- How much documentation routing belongs in generated `AGENTS.md` versus
  workflow docs, status output, hooks, or tests?
- Should review create a lightweight capture cycle automatically, or should it
  instruct the agent to do so explicitly?
- What is the minimum viable real Codex harness suite for operating-model
  confidence?
- Does v1.1 need any MCP/workflow-engine work, or can it remain hook/config/
  instruction based with honest limitations?
