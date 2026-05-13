---
cycle_id: "20260509-autonomous-approval-boundary-fix"
title: "Fix: twarda granica autonomii po zatwierdzeniu planu"
workflow: fix
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-13
owner: alexostl
priority: P1
semantic_reclassification: accepted
source_threads:
  - "current"
related:
  - ".sage/work/20260509-runtime-process-reliability-patch/manifest.md"
  - ".sage/work/20260509-runtime-workflow-enforcement-hardening/manifest.md"
  - ".sage/work/20260509-active-cycle-lease-lock/manifest.md"
scope:
  - ".sage/work/20260509-autonomous-approval-boundary-fix/*"
  - ".sage/decisions.md"
  - "core/workflows/build.workflow.md"
  - "core/workflows/fix.workflow.md"
  - "core/workflows/architect.workflow.md"
  - "core/workflows/sub-workflows/quality-gates.workflow.md"
  - "core/capabilities/orchestration/build-loop/SKILL.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
autonomy_grant:
  approved_at: 2026-05-13
  mode: "approved-plan"
  approval: "Alex replied `a`, interpreted as [A] Approve plan"
  bounded_to:
    - "plan.md snapshot updated 2026-05-09"
    - "manifest.scope as listed above"
  cancels_on:
    - "scope expansion"
    - "new files outside manifest.scope"
    - "semantic plan change"
    - "new product or architecture decision"
---

# Fix: twarda granica autonomii po zatwierdzeniu planu

## State

**Current phase:** completed - Alex zatwierdził closeout odpowiedzią `a`
2026-05-13 po implementacji i weryfikacji.

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

Historycznie plan został zachowany jako niezatwierdzony handoff po wyborze
`[N] New session`. Ten stan został superseded 2026-05-13, gdy Alex
zatwierdził plan odpowiedzią `a`.

Kolejny agent powinien traktować cykl jako `completion-gate`: implementacja i
weryfikacja są wykonane, ale closeout nadal wymaga finalnego zatwierdzenia
Alexa.
