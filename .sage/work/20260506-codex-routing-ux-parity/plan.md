---
title: "Plan: Codex routing UX parity with Claude"
status: completed
phase: completed
priority: high
created: "2026-05-07"
updated: "2026-05-07"
cycle_id: "20260506-codex-routing-ux-parity"
spec: .sage/work/20260506-codex-routing-ux-parity/spec.md
review_verdict: "PASS (second spec auto-review; one Minor folded into plan)"
approved_at: "2026-05-07"
approved_by: alexostl
completed_at: "2026-05-07"
completed_by: codex
---

# Plan: Codex Routing UX Parity With Claude

**Spec:** `.sage/work/20260506-codex-routing-ux-parity/spec.md`
**Mode:** build
**Status:** completed
**Started:** 2026-05-07
**Last updated:** 2026-05-07

## Constitution Constraints

- Standard scope: spec and plan must be approved before implementation.
- Do not weaken post-entry gates: build spec/plan, fix root-cause approval,
  manifest scope enforcement, and verification-before-done remain intact.
- Do not edit downstream consumer repositories or run real-Codex harness in
  this cycle.
- Preserve user-owned AGENTS.md territory below `SAGE-MANAGED-END`.

## Technology Decisions

Using the existing shell-based Codex generator and markdown workflow sources.
No new classifier, hook protocol, MCP server, or runtime service.

## Task 1: Discover Entry-Surface Parity Risks

**Read first:** `core/workflows/sage.workflow.md`, `runtime/platforms/claude-code/setup/generate-claude-code.sh`, `.sage/work/20260429-claude-port-logic-map/map.md`, spec A6.

**Files:**
- no edits unless a direct conflict must be resolved later by Task 2

**Action:** Inspect shared and Claude-facing routing surfaces before editing Codex generator output. Identify whether Claude has hard-coded routing text that conflicts with the approved four-category contract. If there is hard-coded divergence, record the exact path/line in the implementation notes and decide whether Task 2 must update shared source only or also the Claude generator text.

**Test:** Discovery-only task; no code test.

**Verify:** `rg -n 'Question / evaluation|why.*UNDERSTAND|Route Every Request|Confirmation|conversational|action mandate' core/workflows/sage.workflow.md runtime/platforms/claude-code/setup/generate-claude-code.sh .agents/skills/sage-navigator/SKILL.md core/constitution/sage-process.constitution.md`

**Depends on:** none.

**Result:** completed. Discovery found hard-coded eager fallback in
`sage-navigator` and Claude generator; both were handled in implementation.

## Task 2: Update Shared Routing Contract

**Read first:** `core/constitution/sage-process.constitution.md`, `.agents/skills/sage-navigator/SKILL.md`, spec R1-R7 and A3-A6.

**Files:**
- `core/constitution/sage-process.constitution.md`
- `.agents/skills/sage-navigator/SKILL.md`
- `core/workflows/sage.workflow.md` only if Task 1 found a direct conflict

**Action:** Replace the eager "question/why -> understand/analyze" routing language with the shared four-category contract:
- conversational/read-only question -> answer conversationally by default
- explicit workflow command -> enter workflow
- action mandate, including polite question-form mandates -> workflow or confirmation
- ambiguous/borderline prompt -> soft confirmation

Keep workflow gates explicit after workflow entry. In active-workflow language, say read-only questions can be answered from context without resuming implementation.

**Test:** Task 3 adds shared-source assertions that the old eager fallback is absent and the required replacement language is present.

**Verify:** `rg -n 'Question / evaluation|why.*UNDERSTAND|conversational/read-only|action mandate|polite question-form' core/constitution/sage-process.constitution.md .agents/skills/sage-navigator/SKILL.md`

**Depends on:** Task 1.

**Result:** completed. Shared contract updated in constitution and navigator.

## Task 3: Add Shared-Source Routing Assertions

**Read first:** spec A3-A4, R7, second spec auto-review Minor, plan-review findings.

**Files:**
- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats` if using shell assertions inside existing Bats suite
- no new test file unless Bats structure makes a separate shared-text suite cleaner

**Action:** Add explicit checks for shared-source routing text:
- old eager fallback absent: no automatic `Question / evaluation / "why" -> UNDERSTAND` style rule
- replacement present: conversational/read-only questions may be answered without workflow
- active workflow present: active work may be acknowledged, but unrelated read-only questions do not resume implementation or force workflow
- polite question-form mandates are treated as action mandates or confirmation

**Test:** Bats or grep-backed assertions that fail if either the forbidden fallback returns or the replacement language is missing.

**Verify:** `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats` or the new shared-text test if created.

**Depends on:** Task 2.

**Result:** completed. Shared-source assertions added in a separate test block.

## Task 4: Update Generated Codex AGENTS.md Contract

**Read first:** `runtime/platforms/codex/setup/lib/agents-md.sh`, spec A1-A2 and A5.

**Files:**
- `runtime/platforms/codex/setup/lib/agents-md.sh`

**Action:** Add a Codex-facing routing section to the generated managed prefix. It must mirror the shared four-category contract, explicitly say conversational/read-only questions do not start workflows by default, and keep Codex-native enforcement after workflow entry. Preserve the existing Rule 1A variants, project state, and managed-marker behavior.

**Test:** Task 5 adds Stage 3 tests for generated output.

**Verify:** Generate Stage 3 into a temp target and inspect `AGENTS.md` for the new routing section.

**Depends on:** Tasks 2-3.

**Result:** completed. Codex managed AGENTS.md prefix now includes Rule 0 routing contract.

## Task 5: Add Generated AGENTS.md Routing Tests

**Read first:** `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`, spec A1-A6, second auto-review Minor note.

**Files:**
- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`

**Action:** Add tests that generated `AGENTS.md` covers:
- conversational/read-only question -> no workflow by default
- explicit workflow command -> workflow
- direct action mandate -> workflow
- polite question-form mandate -> workflow or confirmation
- ambiguous prompt -> soft confirmation
- post-entry gate preservation language
- active workflow read-only question -> answer from context without resuming implementation

Keep generated-output tests separate from shared-source assertions added in Task 3.

**Test:** New Bats assertions in this file.

**Verify:** `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`

**Depends on:** Task 4.

**Result:** completed. Generated AGENTS.md assertions added in a separate block.

## Task 6: Resolve Any Remaining Entry-Surface Conflicts

**Read first:** `core/workflows/sage.workflow.md`, `runtime/platforms/claude-code/setup/generate-claude-code.sh`, spec A6.

**Files:**
- `core/workflows/sage.workflow.md` if conflicting guidance exists
- no Claude generator edit unless hard-coded divergence is found

**Action:** Apply the minimal conflict resolution discovered in Task 1. If the conflict is only in shared source, ensure Task 2 resolved it. If Claude generator hard-coded text still contradicts the shared contract, make the minimal text-only update needed for parity and note it in decisions. Do not redesign Claude generation.

**Test:** Use grep checks from Task 5 to confirm forbidden eager fallback is absent from edited shared surfaces. Do not broaden scope into a Claude generator redesign.

**Verify:** `rg -n 'Question / evaluation|why.*UNDERSTAND|Route Every Request|four-category|conversational' core/workflows/sage.workflow.md runtime/platforms/claude-code/setup/generate-claude-code.sh`

**Depends on:** Tasks 1-5.

**Result:** completed. Claude generator conflict resolved with minimal text update; no Claude redesign.

## Task 7: Local Verification Sweep

**Read first:** Spec acceptance criteria A1-A7.

**Files:** no source edits unless verification exposes a missed test fixture.

**Action:** Run focused and regression tests.

**Test / Verify:**
- `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
- `bats runtime/platforms/codex/setup/tests/preamble-extraction.bats`
- `bats runtime/platforms/codex/setup/tests/stage7-skills.bats`
- `bats runtime/platforms/codex/setup/tests`
- `bats runtime/platforms/codex/hooks/tests`
- `rg -n 'Question / evaluation|why.*UNDERSTAND' core/constitution/sage-process.constitution.md .agents/skills/sage-navigator/SKILL.md runtime/platforms/codex/setup/lib/agents-md.sh` should return no eager automatic fallback.
- `rg -n 'conversational/read-only|without workflow|active work|polite question-form|action mandate' core/constitution/sage-process.constitution.md .agents/skills/sage-navigator/SKILL.md runtime/platforms/codex/setup/lib/agents-md.sh` should show replacement language.

**Depends on:** Tasks 1-6.

**Result:** completed. Focused and regression suites passed; full setup directory
sweep was stopped because `bin-sage-wiring.bats` hung on `bin/sage init`.
Non-interactive setup suites, doctor/status suites, Stage 3, and hook suites
passed.

## Gate Log

| Task | Spec compliance | Constitution | Tests | Verification |
|------|:---:|:---:|:---:|:---:|
| Task 1 | pass | pass | n/a | pass |
| Task 2 | pass | pass | covered by Task 3 | pass |
| Task 3 | pass | pass | pass | pass |
| Task 4 | pass | pass | covered by Task 5 | pass |
| Task 5 | pass | pass | pass | pass |
| Task 6 | pass | pass | grep checks | pass |
| Task 7 | pass | pass | pass | pass |
