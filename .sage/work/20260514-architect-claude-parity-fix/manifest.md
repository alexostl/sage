---
cycle_id: "20260514-architect-claude-parity-fix"
title: "Fix: Architect ma uzyskać Claude Parity"
workflow: fix
phase: intake
status: intake
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
priority: P3
needs-triage: true
source: "conversation"
scope:
  - ".sage/work/20260514-architect-claude-parity-fix/*"
  - ".sage/decisions.md"
related:
  - "core/workflows/architect.workflow.md"
  - "core/capabilities/orchestration/sage-navigator/SKILL.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
---

# Fix: Architect ma uzyskać Claude Parity

## State

**Current phase:** intake - capture only. Implementacja nie została rozpoczęta.

**Next step:** Wejść w osobny `/sage:fix` po ważniejszych batchach i
zdiagnozować, czego dokładnie brakuje w zachowaniu Architecta względem Claude
Parity.

## Problem

Architect w porcie Codexa ma dostać aktualizację pod Claude Parity. Ten wątek
jest odrębny od aktualnego cyklu lifecycle/bookkeeping oraz od batcha
instruction surface minimization.

## Initial Boundary

- Nie mieszać z aktywnym `20260514-doc-lifecycle-bookkeeping-architecture`.
- Nie formalnie łączyć z batchami bez osobnej decyzji Alexa.
- Na tym etapie zapisać tylko intake i umieścić go na końcu kolejki.
