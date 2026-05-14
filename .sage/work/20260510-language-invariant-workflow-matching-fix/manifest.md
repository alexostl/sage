---
cycle_id: "20260510-language-invariant-workflow-matching-fix"
title: "Fix: language-invariant workflow and harness matching"
workflow: fix
phase: completed
status: completed
created: 2026-05-10
updated: 2026-05-14
owner: alexostl
priority: P1
classification: Moderate
semantic_reclassification: accepted
source_cycle: "20260509-workflow-entry-resume-recovery-autonomy-fix"
source_intakes:
  - "20260509-mcp-incident-followup-fixes"
  - "20260509-target-repo-ownership-harness-fix"
tags:
  - workflow-matching
  - harness
  - hooks
  - language-invariant
scope:
  - ".sage/work/20260510-language-invariant-workflow-matching-fix/*"
  - ".sage/work/20260509-mcp-incident-followup-fixes/manifest.md"
  - ".sage/work/20260509-target-repo-ownership-harness-fix/manifest.md"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/harness/**"
  - "runtime/platforms/codex/audit/sage-writers.yaml"
  - "runtime/platforms/codex/hooks/**"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "runtime/platforms/codex/setup/tests/stage5-6-hooks.bats"
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

## Batch 5 state

Ten cycle jest anchor dla Batcha 5:

- `20260509-mcp-incident-followup-fixes`;
- `20260510-language-invariant-workflow-matching-fix`;
- `20260509-target-repo-ownership-harness-fix`.

## Next Legal Move

Cycle jest w `completion-checkpoint`. Następny legalny krok to decyzja Alexa:
approve closeout, revise albo dodatkowa weryfikacja. Nie oznaczać anchor cycle
jako `completed` przed akceptacją completion checkpoint.
