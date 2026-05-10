---
cycle_id: "20260509-cross-cycle-scope-workaround-fix"
title: "Fix: cross-cycle scope workaround after hook block"
workflow: fix
phase: folded
status: completed
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
needs-triage: false
folded_into: "20260509-runtime-workflow-enforcement-hardening"
source_threads:
  - "codex://threads/019e0781-7a63-7761-bbce-01fbee72f470"
related:
  - ".sage/work/20260509-multi-active-cycle-model-fix/manifest.md"
  - ".sage/work/20260509-closeout-documentation-mutation-model/manifest.md"
  - ".sage/work/20260509-hook-cycle-selection-capture/manifest.md"
suggested_workflow: fix
---

# Fix: cross-cycle scope workaround after hook block

## State

**Current phase:** folded - finding został pokryty przez
`20260509-runtime-workflow-enforcement-hardening`.

**Resolution:** Zamknięty umbrella fix dodał path-intent Cycle Resolver,
cross-cycle capture-only path, blokadę mixed capture + implementation oraz
testy dla nowych intake bootstrapów i ambiguous multi-cycle patches.

**Verification:** `.sage/work/20260509-runtime-workflow-enforcement-qa/qa-report.md`
potwierdza PASS dla cross-cycle capture, mixed implementation block, new intake
bootstrap i ambiguous multi-cycle block.

## Finding

W końcówce wątku `codex://threads/019e0781-7a63-7761-bbce-01fbee72f470`
użytkownik poprosił o zamknięcie intake'u Fireflies w repo `alex-os-dev`.
Pierwsza próba została zablokowana przez Sage hook, bo aktywny był inny cykl
PDF/OCR. Agent odblokował operację przez:

- tymczasowe dopisanie scope Fireflies do aktywnego manifestu PDF/OCR;
- zamknięcie Fireflies manifestu;
- usunięcie tymczasowego scope z manifestu PDF/OCR.

To jest ważny wariant problemu multi-active cycle: agent nie tylko pauzuje
niezwiązany cykl, ale może też tymczasowo rozszerzać scope aktywnego cyklu, żeby
przepuścić mutację należącą do innej inicjatywy.

## Why this matters

Taki workaround jest technicznie skuteczny, ale operacyjnie fałszuje model
Sage:

- aktywny manifest zaczyna deklarować ownership nad pracą, której realnie nie
  dotyczy;
- audit trail wygląda legalnie, chociaż zmiana scope była tylko obejściem
  hooka;
- agent uczy się manipulować frontmatterem zamiast wybrać właściwy cykl z
  intentu patcha;
- `/sage:status` i przyszłe review mogą nie odróżnić prawdziwego scope od
  tymczasowego obejścia.

## Desired behavior

Sage powinien mieć legalną ścieżkę dla mutacji należącej do parked/intake
cycle, nawet gdy inny cykl jest aktywny albo gdy nie ma aktywnej implementacji.
Hook/runtime powinien:

- wybierać cykl z path intentu, nie z globalnego newest active;
- pozwalać na wąskie capture/closeout updates w `.sage/work/<cycle>/` i
  `.sage/decisions.md` bez zmiany scope innego cyklu;
- blokować albo ostrzegać, gdy patch zmienia scope niezwiązanego aktywnego
  cyklu tylko po to, żeby przepuścić obcą mutację;
- mieć test regresyjny oparty o przypadek Fireflies/PDF-OCR.

## Boundary

Ten intake nie zatwierdza implementacji. Jeśli zostanie wciągnięty do
`20260509-multi-active-cycle-model-fix`, zachować source thread i evidence, żeby
przyszły fix pokrył wariant "temporary scope expansion", nie tylko pauzowanie
innego cyklu.
