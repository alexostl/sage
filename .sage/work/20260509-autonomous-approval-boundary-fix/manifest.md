---
cycle_id: "20260509-autonomous-approval-boundary-fix"
title: "Fix: twarda granica autonomii po zatwierdzeniu planu"
workflow: fix
phase: handoff
status: paused
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
priority: P1
source_threads:
  - "current"
related:
  - ".sage/work/20260509-runtime-process-reliability-patch/manifest.md"
  - ".sage/work/20260509-runtime-workflow-enforcement-hardening/manifest.md"
  - ".sage/work/20260509-active-cycle-lease-lock/manifest.md"
scope:
  - ".sage/work/20260509-autonomous-approval-boundary-fix/*"
  - ".sage/decisions.md"
proposed_implementation_scope:
  - "core/workflows/build.workflow.md"
  - "core/workflows/fix.workflow.md"
  - "core/workflows/architect.workflow.md"
  - "core/workflows/sub-workflows/quality-gates.workflow.md"
  - "core/capabilities/orchestration/build-loop/SKILL.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
---

# Fix: twarda granica autonomii po zatwierdzeniu planu

## State

**Current phase:** handoff - plan zapisany i zaparkowany dla kolejnej sesji.
Nie wdrażać zmian w workflow/runtime przed explicit approvalem.

## Problem

Opcja `[F] Full autonomous implementation` została dodana po to, żeby po
zatwierdzeniu planu agent mógł wykonać zatwierdzony scope bez pośrednich
checkpointów. W praktyce model potraktował późniejsze rozszerzenie scope jako
część autonomicznej jazdy, mimo że scope expansion miało zatrzymywać pracę.

## Root Cause

Autonomia była opisana jako tryb wykonania, ale nie była twardo powiązana z
konkretnym zatwierdzonym snapshotem planu i manifest scope. Brakowało
obserwowalnego warunku:

> Czy użytkownik wybrał `[F]` dla tego planu, tego scope i tych zmian, zanim
> zaczęła się implementacja?

## Boundary

Ten cykl ma naprawić kontrakt approval/autonomy. Nie zmienia logiki
cross-cycle capture, lease lock ani binary asset mutation contract poza tym,
co jest konieczne do opisania stop condition dla `[F]`.

## Handoff

Plan został zachowany jako niezatwierdzony handoff po wyborze `[N] New session`.
Kolejny agent powinien najpierw pokazać `plan.md`, krótko potwierdzić zakres i
dopiero wtedy czekać na decyzję:

- `[A] Approve plan` - wdrożyć dokładnie ten scope;
- `[R] Revise` - poprawić plan;
- `[N] New session` - zostawić ten manifest i plan jako handoff.
