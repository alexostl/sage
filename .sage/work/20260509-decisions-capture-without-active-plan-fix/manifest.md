---
cycle_id: "20260509-decisions-capture-without-active-plan-fix"
title: "Fix: odblokować Sage Decisions dla capture bez aktywnego planu"
workflow: fix
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
priority: P1
needs-triage: false
folded_into: "20260509-runtime-workflow-enforcement-hardening"
source: "conversation"
suggested_workflow: fix
related:
  - ".sage/decisions.md"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/lib/active_init.sh"
---

# Fix: odblokować Sage Decisions dla capture bez aktywnego planu

## State

**Current phase:** completed - legalny `.sage/decisions.md` audit przy
capture-only został pokryty i zweryfikowany przez
`20260509-runtime-workflow-enforcement-hardening`.

**Resolution:** Hook resolver pozwala na cross-cycle capture do istniejącego
intake oraz new minimal intake bootstrap razem z `.sage/decisions.md`, bez
aktywnego planu implementacyjnego.

**Verification:** `.sage/work/20260509-runtime-workflow-enforcement-qa/qa-report.md`
ma zielone flow results dla `Cross-cycle capture to existing intake` oraz
`New minimal intake bootstrap while another cycle is active`.

## Finding

Podczas dopisywania nowego intake dla migracji flagi Codex hooks manifest
został zapisany poprawnie, ale próba dopisania audit wpisu do
`.sage/decisions.md` została zablokowana przez `PreToolUse`:

```text
Sage: no active implementation cycle.
Found parked paused/intake work...
Parked cycles are manifest-only/resumable context, not implementation-active.
Next legal move: run `sage status`, then explicitly use `sage:continue`...
```

To tworzy niespójność: Sage wymaga, żeby znaczące decyzje/capture miały ślad w
decision logu, ale hook blokuje ten ślad dokładnie w legalnym trybie
capture-only, gdzie nie ma jeszcze aktywnego planu.

## Desired Behavior

Hooki powinny rozróżniać:

- implementację bez aktywnego planu - nadal blokować;
- tworzenie intake manifestu - legalne jako capture-only;
- dopisanie krótkiego wpisu auditowego do `.sage/decisions.md` dla legalnego
  capture-only - legalne, nawet bez aktywnego planu;
- edycje `.sage/decisions.md`, które zmieniają decyzje merytoryczne aktywnego
  planu albo próbują zatwierdzić scope - nadal wymagają właściwego workflow.

## Candidate Scope

- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
- `runtime/platforms/codex/hooks/lib/active_init.sh`
- testy hooków dla scenariusza: intake manifest + decisions audit bez
  aktywnego planu
- dokumentacja recovery wording, jeśli komunikat blokujący trzeba doprecyzować

## Open Design Question

Trzeba ustalić, czy wyjątek ma być:

- path-based: `.sage/decisions.md` legalny tylko przy dopisywaniu nowej sekcji;
- context-based: legalny tylko tuż po utworzeniu intake manifestu;
- marker-based: wpis musi zawierać frazę capture-only/intake i nie może
  zmieniać istniejących sekcji;
- albo kombinacją powyższych.

## Boundary

Ten fix nie powinien otworzyć furtki do cichego zatwierdzania planów,
scope expansion ani zmian product behavior. Chodzi tylko o audit trail dla
legalnego capture/intake bez aktywnego planu.
