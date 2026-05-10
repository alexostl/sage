---
cycle_id: "20260510-post-closeout-handoff-doc-mutation-fix"
title: "Fix: local handoff nie mutuje dokumentacji po zamknieciu cyklu"
workflow: fix
phase: intake
status: intake
created: 2026-05-10
updated: 2026-05-10
owner: alexostl
priority: high
classification: Moderate
source_thread: "codex://threads/019e10d0-a5a2-7a33-9c9d-5d7b1514b6f6"
related:
  - "20260510-codex-worktree-support-build"
  - "20260509-closeout-documentation-mutation-model"
  - "20260510-closeout-ordering-workflow-hook-fix"
  - "20260510-sage-git-tracking-policy"
scope:
  - ".sage/work/20260510-post-closeout-handoff-doc-mutation-fix/*"
  - ".sage/decisions.md"
  - "core/workflows/**"
  - "core/capabilities/**"
  - "runtime/platforms/codex/**"
---

# Fix: local handoff nie mutuje dokumentacji po zamknieciu cyklu

## State

**Current phase:** intake - findingi zostaly zapisane jako TODO dla przyszlego
focused fixa. Nie implementujemy jeszcze zmian runtime/workflow.

**Next step:** Przy wejsciu w `/sage:fix` zdiagnozowac, gdzie najlepiej
zakodowac regule: workflow closeout guidance, worktree handoff workflow,
generated Codex instructions, hook recovery message albo ich kombinacja.

## Problem

Po zamknieciu cyklu agent dostal polecenie przygotowania lokalnego handoffu
worktree do merge. Zamiast ograniczyc sie do sprawdzenia statusu, testow,
stagingu, commita i raportu handoff, probowal jeszcze dopisywac tresc do
artefaktow Sage: `manifest`, `qa-report` i `decisions.md`.

To jest zly odruch dla local handoffu. Gdy cykl jest juz zamkniety, a user
prosi tylko o przygotowanie worktree do lokalnej integracji, dokumentacja Sage
powinna byc traktowana jako material do commita, nie jako powierzchnia do
dalszego dopisywania epilogu.

## Findings

1. **Post-closeout handoff to nie nowa faza dokumentacyjna.** Jesli manifest
   ma `status: completed`/`phase: closed` albo analogicznie zamkniety stan, to
   agent nie powinien dopisywac nowych notatek tylko po to, zeby "ladniej"
   opisac handoff.

2. **Guardrail block po closeoucie powinien zatrzymac dopisek.** Jesli
   PreToolUse blokuje probe edycji `.sage/**` po zamknieciu cyklu albo przez
   konflikt aktywnego cyklu, poprawna reakcja to raport w odpowiedzi handoff,
   nie obchodzenie blokady przez domykanie albo mutowanie innego manifestu.

3. **Local handoff ma wystarczajacy output w finalnej odpowiedzi i commicie.**
   Dane typu branch, SHA, testy, ryzyka, clean working tree i konflikty merge
   nie musza byc ponownie dopisywane do zamknietego `manifest.md`, jesli nie
   byly wymaganym artefaktem przed closeoutem.

4. **Wyjatek musi byc jawny.** Edycja `.sage/work/**` po zamknieciu cyklu jest
   sensowna tylko wtedy, gdy user explicitnie prosi o korekte artefaktu albo
   agent odkrywa realny brak blokujacy commit/merge. W takim wypadku powinien
   wyjasnic intent i nie dotykac innych cykli.

## TODOs For Future Fix

- Dodac regule do closeout/worktree handoff guidance: po zamknietym cyklu
  local handoff nie dopisuje nowych epilogow do `.sage` tylko po to, zeby
  przygotowac merge.
- Dodac recovery wording: gdy dokumentacyjna mutacja po closeoucie jest
  zablokowana, agent ma kontynuowac handoff bez tej mutacji albo poprosic o
  jawna zgode, zamiast zmieniac inny aktywny/stary manifest.
- Sprawdzic, czy obecne intake
  `20260509-closeout-documentation-mutation-model` i
  `20260510-closeout-ordering-workflow-hook-fix` pokrywaja ten przypadek; jesli
  tak, zintegrowac finding zamiast tworzyc trzeci konkurencyjny mechanizm.
- Dodac test/harness transcript assertion dla scenariusza: cykl completed,
  user prosi o local handoff, agent nie mutuje `.sage/work/<closed-cycle>/`
  ani `.sage/decisions.md` po finalnym closeout.
- Doprecyzowac granice: oficjalny `qa-report.md` albo `verification.md` wolno
  dopisac przed closeoutem; po closeoucie domyslnie tylko commit/handoff
  response, bez nowych dokumentacyjnych zmian.

## Boundary

Nie zmieniac teraz kodu ani workflow. To jest TODO/intake dla przyszlego fixa.
Nie ruszac `.sage-memory`. Nie naprawiac retrospektywnie commita
`b1449fccfd615fe96b21014942ecab5251b46df6`; ten intake opisuje przyszle
zachowanie agentow.
