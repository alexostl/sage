---
cycle_id: "20260509-active-cycle-lease-lock"
title: "Intake: Cycle Resolver powinien blokować zapis do cyklu z aktywną sesją"
workflow: intake
phase: intake
status: intake
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
priority: P1
tags:
  - needs-triage
  - cycle-resolver
  - concurrency
---

# Intake: active-cycle lease lock

## Finding

Cycle Resolver powinien rozróżniać `status: in-progress` jako stan workflow od
aktywnej dzierżawy pracy przez konkretny wątek/agenta.

Jeżeli cykl jest w toku i agent aktualnie na nim pracuje w innym wątku/sesji,
to inny agent nie powinien móc zapisywać do tego cyklu, nawet jeśli zapis byłby
capture-only. Taki cykl jest aktywnie obsługiwany, a nie zaparkowany.

## Expected Behavior

- Cross-cycle capture do `paused` albo `intake` pozostaje legalny jako
  capture-only.
- Cross-cycle capture do `in-progress` z aktywną lease/sesją innego agenta
  powinien być blokowany.
- Ten sam agent/sesja może kontynuować własny aktywny cykl w ramach
  zatwierdzonego scope.
- Recovery powinno mówić, że cykl jest aktualnie obsługiwany i trzeba poczekać,
  przejąć lease jawnie albo utworzyć osobny intake.

## Open Design Question

Trzeba zaprojektować źródło prawdy dla lease: plik lock w `.sage/`, wpis w
session logu, heartbeat, thread id, TTL, albo kombinację tych mechanizmów.
