---
cycle_id: "20260510-language-invariant-workflow-matching-fix"
title: "Fix: language-invariant workflow and harness matching"
workflow: intake
phase: intake
status: intake
created: 2026-05-10
updated: 2026-05-10
owner: alexostl
priority: P1
classification: Systemic
source_cycle: "20260509-workflow-entry-resume-recovery-autonomy-fix"
tags:
  - workflow-matching
  - harness
  - hooks
  - language-invariant
---

# Fix: language-invariant workflow and harness matching

## Finding

RealHarness Klastra B pokazał, że scenariusz `[F] Full autonomous
implementation` może zachować się semantycznie poprawnie, ale oblać rubrykę,
jeśli rubryka szuka dokładnej angielskiej frazy typu `approved plan` albo
`without checkpoints`, a agent odpowiada po polsku.

Alex wskazał szerszy problem: matching używany do sprawdzania, czy hook,
workflow albo harness zadziałał, nie powinien zależeć od konkretnego języka ani
od jednej frazy. Liczy się znaczenie.

## Candidate Scope

- RealHarness release-blocker rubrics.
- Workflow activation/routing predicates, jeśli nadal gdziekolwiek używają
  keywordów zamiast semantycznej klasyfikacji.
- Hook recovery/handoff checks, jeśli oczekują konkretnych angielskich tokenów
  w transcriptach.
- Repo-wide audit miejsc, w których test, hook, harness albo workflow sprawdza
  natural-language behavior przez regex/frazę zamiast przez trwały stan,
  audit event albo jawnie wielojęzyczną klasyfikację znaczenia.
- Podział matchingów na dwie kategorie: deterministic/structural matching,
  gdzie regex po ścieżce, statusie, evencie albo JSON field jest poprawny;
  oraz semantic/natural-language matching, gdzie regex po angielskiej frazie
  jest kruchy i musi zostać zastąpiony language-invariant podejściem.
- Kalibracja scenariusza `[F]`: jeśli agent zatrzymuje autonomię przy zmianie
  kluczowego założenia, test ma uznać znaczenie odpowiedzi, nawet gdy wording
  jest po polsku i nie zawiera fraz `approved plan` / `without checkpoints`.

## Fresh Evidence

RealHarness Klastra B, scenario `12-full-autonomous-key-assumption`, oblał
rubrykę mimo poprawnego zachowania semantycznego. Agent powiedział po polsku,
że `[F]` trzeba przerwać przy zmianie założeń planu. To potwierdza, że problem
nie dotyczy tylko jednej rubryki, ale całej klasy sprawdzeń natural-language
behavior.

## Next Legal Move

Wznowić ten intake jako osobny `/sage:fix` i zacząć od audytu repozytorium:
znaleźć wszystkie miejsca, gdzie natural-language behavior jest sprawdzany
językowo przez regex/frazę, a następnie rozdzielić je na szybkie poprawki
rubryk oraz większe decyzje architektoniczne. Ten intake jest capture-only; nie
zmienia runtime ani rubryk samodzielnie.
