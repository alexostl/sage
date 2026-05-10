---
title: "Spec: Codex routing UX parity with Claude"
status: completed
phase: spec
priority: high
created: "2026-05-06"
updated: "2026-05-07"
cycle_id: "20260506-codex-routing-ux-parity"
deliverable: code
related:
  - .sage/work/20260506-codex-routing-ux-parity/manifest.md
  - .sage/work/20260429-claude-port-logic-map/map.md
  - runtime/platforms/claude-code/setup/generate-claude-code.sh
  - runtime/platforms/codex/setup/lib/agents-md.sh
  - core/constitution/sage-process.constitution.md
  - .agents/skills/sage-navigator/SKILL.md
approved_at: "2026-05-07"
approved_by: alexostl
handoff: |
  Key decisions: Codex should match Claude's routing feel at the workflow
  boundary, but improve the shared contract so ordinary conversational
  questions do not auto-enter research/analyze. Explicit workflow commands
  and clear action mandates still enter workflow; ambiguous prompts use
  soft confirmation. Codex-native enforcement remains intact after workflow
  entry.
  Open questions: None for the spec. Real-Codex harness coverage is explicitly
  out of scope for this cycle and can become a follow-up.
  Risks: Over-correction could make real build/fix requests feel optional;
  avoid this by preserving strong action-mandate routing and tests for the
  generated instruction text.
  Next agent should: Write a focused plan that updates shared routing language,
  Codex AGENTS.md generation, and generator tests before touching runtime
  enforcement code.
---

# Spec: Codex Routing UX Parity With Claude

## Intent

Codex Sage should offer the same conversational rhythm as the Claude port at
the workflow boundary: normal questions stay in conversation, explicit workflow
invocations enter workflow immediately, clear action requests enter the matching
workflow, and ambiguous requests receive confirmation before methodology starts.

The goal is user-experience parity, not implementation parity. Codex should keep
its stronger native enforcement once a workflow is active.

## Problem

The current Codex instructions make workflow routing too eager. They can treat
questions or loose discussion as immediate methodology, which interrupts
exploration and makes Codex feel stricter than Claude. Claude already has a
confirmation layer, but its "Question / why -> UNDERSTAND" fallback is also too
broad. Codex should converge on the shared UX contract while correcting that
over-trigger.

## Requirements

R1. Conversational questions must not start a workflow by default.

Examples:
- "How does this work?"
- "Does this direction make sense?"
- "What do you think about this?"
- "Let's talk about this before building."

Expected behavior: answer conversationally. The agent may mention that a formal
workflow is available, but should not announce `Sage -> analyze/design/build`
or create artifacts.

R2. Explicit workflow invocations must still start the requested workflow.

Examples:
- "$sage:build add usage analytics"
- "$sage:fix the failing hook"
- "Run analyze on this flow"

Expected behavior: enter the named workflow and follow its gates.

R3. Clear action-mandate prompts must route to workflow.

Examples:
- "Implement this change"
- "Fix this bug"
- "Check whether this works"
- "Run a smoke test"
- "Can you fix this?"
- "Could you implement this?"
- "Would you run a smoke test?"

Expected behavior: start the matching workflow or, where the request is
borderline, present a confirmation choice.

R4. Ambiguous prompts must use soft confirmation, not hard methodology.

Examples:
- "Can you look at this?"
- "Should we improve the onboarding?"
- "Could this be cleaner?"

Expected behavior: briefly state the likely workflow and ask whether to run it,
or answer conceptually while offering the workflow path. Do not write artifacts
until the user gives an action mandate.

R5. Codex and Claude should share the same routing UX contract.

The source text for always-on Sage instructions and navigator guidance should
define one common distinction:
- conversation/read-only question
- explicit workflow command
- action mandate
- ambiguous/borderline prompt

R6. Codex-native enforcement must remain intact after workflow entry.

This change must not weaken:
- spec/plan requirements for Standard+ build work
- root-cause approval for fix work
- manifest/scope protection for mutations
- verification-before-done expectations

R7. Active workflow context must not force methodology onto unrelated
conversational questions.

When `.sage/work/*/manifest.md` shows active work, the agent should acknowledge
the active initiative when relevant, but a read-only conversational question
inside that session should still be answered conversationally unless the user
asks to resume, mutate, verify, or produce an artifact. If the question touches
the active initiative, the agent may answer from the active context and offer to
resume the workflow afterward.

## Boundaries

This cycle will not add a semantic classifier service, MCP workflow engine, or
new hook protocol.

This cycle will not edit other repositories or downstream consumer projects.

This cycle will not remove keyword examples entirely; it will demote them from
"keyword means workflow" to "keyword plus action mandate may indicate workflow".

This cycle will not change post-entry gates, PreToolUse mutation validation, or
existing manifest scope rules.

This cycle will not run or expand the real-Codex outcome harness. Harness
coverage for conversational routing is a valid follow-up, but this cycle's
verification is limited to generated instruction text, workflow source text,
and existing local test suites.

## Acceptance Criteria

A1. Generated Codex `AGENTS.md` contains routing guidance that explicitly says
conversational/read-only questions do not start Sage workflows by default.
Verification: Stage 3 generator test asserts the generated file contains that
rule.

A2. Generated Codex `AGENTS.md` distinguishes explicit workflow commands,
action mandates, and ambiguous prompts.
Verification: Stage 3 generator test asserts all three categories appear with
distinct behavior.

A3. `sage-navigator` no longer states that every question/evaluation/"why"
fallback maps directly to `/sage:research` or `/sage:analyze`.
Verification: text test or grep check confirms the forbidden fallback string is
absent and the replacement distinguishes conversational questions from action
mandates.

A4. The shared process constitution does not instruct agents to announce a
workflow before answering ordinary conversational/read-only questions.
Verification: grep check confirms the forbidden pattern "Question / evaluation
/ \"why\" -> UNDERSTAND" is absent from the shared routing guidance, and the
replacement says conversational questions may be answered without workflow.

A5. Tests cover the required routing cases:
- conversational/read-only question -> no workflow by default
- explicit workflow command -> workflow
- direct action mandate -> workflow
- polite question-form mandate -> workflow or confirmation
- ambiguous prompt -> soft confirmation
- post-entry gate preservation -> no weakening language

A6. Claude parity is verified at the shared-source level in this cycle.
Verification: shared constitution and navigator text carry the common routing
contract. The Claude generator does not need separate implementation in this
cycle unless plan discovery shows it consumes an unshared hard-coded routing
block that would otherwise remain divergent.

A7. Existing Codex setup and hook tests still pass.

## Affected Areas

- `runtime/platforms/codex/setup/lib/agents-md.sh`
- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
- `.agents/skills/sage-navigator/SKILL.md`
- `core/constitution/sage-process.constitution.md`
- possibly `core/workflows/sage.workflow.md` if its entry guidance conflicts

## Risks

RISK-1: Over-correction could make agents skip workflow for real build/fix work.
Mitigation: keep explicit command and action-mandate routing strong.

RISK-2: Claude and Codex could drift if only Codex text changes.
Mitigation: update shared constitution/navigator language first, then render
Codex-specific instructions from that contract.

RISK-3: Tests might only assert text, not behavior.
Mitigation: add generator text tests now and plan a follow-up harness prompt
for conversational question behavior if the existing harness can support it
within scope.

## Done When

- Spec and plan are approved.
- Implementation updates routing guidance without weakening workflow gates.
- Tests pass with pasted output at completion.
- `manifest.md` is updated with implementation scope before code changes.
