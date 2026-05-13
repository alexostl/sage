---
cycle_id: "20260509-active-cycle-lease-lock"
title: "Intake: Cycle Resolver powinien blokować zapis do cyklu z aktywną sesją"
workflow: intake
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-13
owner: alexostl
priority: P1
folded_into: "20260509-cycle-workflow-entry-enforcement-fix"
tags:
  - cycle-resolver
  - concurrency
---

# Intake: active-cycle lease lock

## State

**Current phase:** completed - skonsumowane przez Batch 1 anchor cycle
`20260509-cycle-workflow-entry-enforcement-fix`.

**Next step:** Brak osobnej implementacji w tym cyklu. Dalsze zmiany wymagają
nowego intake albo osobnej decyzji o scope.

## Batch 1 Resolution

Ten intake został domknięty bookkeeping-only po zweryfikowanej implementacji
Batcha 1. Anchor cycle doprecyzował `active_session_id`/lease ownership,
różnicę między aktywnym `in-progress` a parked `intake`/`paused`, oraz wyjątek
dla capture-only `.sage/**` bez mieszania z implementation paths.

## Finding

Cycle Resolver powinien rozróżniać `status: in-progress` jako stan workflow od
aktywnej dzierżawy pracy przez konkretny wątek/agenta.

Jeżeli cykl jest w toku i agent aktualnie na nim pracuje w innym wątku/sesji,
to inny agent nie powinien móc zapisywać do tego cyklu, nawet jeśli zapis byłby
capture-only. Taki cykl jest aktywnie obsługiwany, a nie zaparkowany.

## Expected Behavior

- Cross-cycle capture do `paused` albo `intake` pozostaje legalny jako
  capture-only.
- Drugi agent w tym samym worktree może równolegle otworzyć nowy cykl,
  doprecyzować intake albo przygotować plan/spec dla parked cycle, jeżeli patch
  dotyka tylko koncepcyjnych artefaktów `.sage/**` i nie mutuje kodu,
  runtime, testów, configu ani innych implementation paths.
- Cross-cycle capture do `in-progress` z aktywną lease/sesją innego agenta
  powinien być blokowany.
- Ten sam agent/sesja może kontynuować własny aktywny cykl w ramach
  zatwierdzonego scope.
- Aktywny lease blokuje implementation paths oraz artefakty aktywnego cyklu
  należącego do innej sesji, ale nie powinien zamrażać całego backlogu
  koncepcyjnego w `.sage/work/*` dla intake/paused cycles.
- `.sage/decisions.md` jest shared artifact: może być dopisywany przy
  capture/planning-only pracy, ale nie powinien stawać się furtką do ukrytych
  zmian implementacyjnych w tym samym patchu.
- Recovery powinno mówić, że cykl jest aktualnie obsługiwany i trzeba poczekać,
  przejąć lease jawnie albo utworzyć osobny intake.

## Open Design Question

Trzeba zaprojektować źródło prawdy dla lease: plik lock w `.sage/`, wpis w
session logu, heartbeat, thread id, TTL, albo kombinację tych mechanizmów.

Trzeba też zaprojektować predicate dla wyjątków `.sage/**`:

- allow: bootstrap nowego cyklu, capture do `intake`/`paused`, plan/spec dla
  parked cycle, decyzje bez zmian implementacyjnych;
- block: edycja aktywnego `in-progress` cyklu innej sesji, kod/runtime/testy
  poza zatwierdzonym scope, mieszanie capture-only `.sage/**` z implementation
  paths w jednym patchu.
