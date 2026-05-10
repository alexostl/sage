---
cycle_id: "20260506-codex-routing-ux-parity"
title: "Codex routing UX parity with Claude"
workflow: build
phase: complete
status: completed
scope_level: standard
created: "2026-05-06"
updated: "2026-05-07"
owner: alexostl
scope:
  - ".sage/work/20260506-codex-routing-ux-parity/*"
  - ".sage/decisions.md"
  - "core/constitution/sage-process.constitution.md"
  - ".agents/skills/sage-navigator/SKILL.md"
  - "core/workflows/sage.workflow.md"
  - "runtime/platforms/claude-code/setup/generate-claude-code.sh"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
artifacts:
  - manifest.md
  - spec.md (completed, revised + approved 2026-05-07)
  - plan.md (completed, revised + approved 2026-05-07)
context_summary: |
  User wants Codex Sage to feel closer to the Claude port at the routing
  boundary: conversational questions should remain conversational, explicit
  commands should start workflows, action-mandate requests should enter or
  confirm workflows, and ambiguous questions should get soft confirmation.
  The implementation must preserve Codex-native enforcement after workflow
  entry while reducing premature methodology on ordinary questions.
inputs:
  - runtime/platforms/claude-code/setup/generate-claude-code.sh
  - runtime/platforms/claude-code/hooks/sage-session-init.sh
  - .sage/work/20260429-claude-port-logic-map/map.md
  - runtime/platforms/codex/setup/lib/agents-md.sh
  - core/constitution/sage-process.constitution.md
  - .agents/skills/sage-navigator/SKILL.md
  - sage-memory self-learning entries on regex classifier and pseudo-Sage
---

# Cycle: Codex routing UX parity with Claude

**Current phase:** complete — implementation and verification finished.

**Artifacts:**
- manifest.md: exists
- spec.md: completed
- plan.md: completed

**Completed work:**
- Shared routing contract now preserves conversation by default.
- Codex generated `AGENTS.md` includes the four-category routing contract.
- Claude generator hard-coded routing text now matches the corrected contract.
- Stage 3 tests cover shared-source and generated-output routing assertions.

**Verification:** Stage 3, focused setup suites, doctor/status suites, and hook
tests passed. Full setup directory sweep was interrupted because
`bin-sage-wiring.bats` hung on `bin/sage init`; non-interactive suites were run
separately instead.
