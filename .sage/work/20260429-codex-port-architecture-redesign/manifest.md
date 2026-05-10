---
cycle_id: "20260429-codex-port-architecture-redesign"
title: "Codex port architecture redesign"
workflow: architect
phase: design
status: rejected-superseded
superseded_by: .sage/work/20260429-codex-port-rewrite/
created: 2026-04-29
updated: 2026-04-29
owner: alexostl
artifacts:
  - brief.md
  - spec.md
  - .sage/docs/analysis-codex-sage-mcp-workflow-engine.md
  - .sage/docs/decision-codex-layered-runtime-model.md
  - .sage/docs/decision-codex-workflow-state-machine.md
  - .sage/docs/decision-codex-approval-proof.md
  - .sage/docs/decision-codex-instruction-surface-split.md
  - .sage/docs/decision-codex-public-workflows-internal-library.md
  - .sage/docs/decision-codex-enforcement-profiles.md
  - .sage/docs/decision-codex-mutation-guardrail-stack.md
  - .sage/docs/decision-codex-outcome-driven-verification.md
handoff: |
  Architecture design is in review. Key proposed decisions:
  layered runtime lifecycle, explicit workflow state machine/gate validator
  likely exposed through a Sage MCP workflow engine, disk-backed approval
  proof, compact AGENTS.md static contract, workflow-only public UI, internal
  lazy-loaded Sage library, SessionStart dynamic state, UserPromptSubmit
  micro-router under 200 tokens, mutation guardrail stack, and dual enforcement
  profiles fast-trusted vs strict. User works in Skip Permissions, so do not
  describe MCP or hook-based write gates as OS-level hard enforcement. Several
  v1 defaults are proposed but require user confirmation before design
  approval: Codex-first internal manifest, frontmatter+decisions approval
  proof, Stop warn/route behavior, diagnostic-write policy, and MCP-first
  workflow engine scope. Do not describe those as approved decisions yet.
---

# Manifest — Codex Port Architecture Redesign

## Context Summary

This architect cycle replaces the reverted Codex enforcement activation attempt.
The previous cycle failed empirically because regex prompt classification let a
Polish build request bypass Sage entirely. The new framing is outcome-driven:
Codex should be guided into Sage early by compact static and dynamic context,
while mutation attempts are guarded by tool hooks and backstops.

The core product choice is workflow clarity over exhaustive skill exposure:
show only the public workflow skills in UI, and keep the rest of Sage as an
internal lazy-loaded methodology library. The runtime model is layered by
lifecycle: session orientation, turn-level nudge, workflow gate validation,
mutation guard, recovery backstops. New research indicates the gate validator
should likely be implemented as a shared Sage workflow engine exposed to Codex
through MCP, while hooks/status call the same underlying library.

## Current Phase

DESIGN phase in review. Brief, spec, and ADRs saved.

## Next Step

Design is still in review. If user approves the design, run independent review
if requested/available, then proceed to milestone planning. If user revises,
ask focused trade-off questions, update ADRs/spec, and keep the initiative in
design.
