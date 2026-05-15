---
cycle_id: "20260514-architect-elicit-question-density-fix"
title: "Fix: Architect pyta o tryb prowadzenia elicitation"
workflow: fix
phase: intake
status: intake
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
needs-triage: true
priority: P2
source: "conversation"
suggested_workflow: fix
related:
  - "core/workflows/architect.workflow.md"
  - "core/capabilities/elicitation/deep-elicit/SKILL.md"
  - "runtime/platforms/codex/setup/tests/alex-native-core-text.bats"
  - "runtime/platforms/claude-code/setup/tests/generate-claude-code.bats"
scope:
  - ".sage/work/20260514-architect-elicit-question-density-fix/*"
  - ".sage/decisions.md"
---

# Fix: Architect pyta o tryb prowadzenia elicitation

## State

**Current phase:** intake. Implementacja nie została rozpoczęta.

**Next step:** Przy przyszłym `/sage:fix` zrobić krótką diagnozę surface'u
`architect`/`deep-elicit`, zaplanować minimalny scope i dopiero wtedy zmienić
instrukcje oraz testy.

## Finding

Alex chce rozbudować zachowanie `architect` przy wejściu w workflow. Dzisiaj
Sage ma zasadę `jedno pytanie naraz` i w `deep-elicit` ma mocniejsze,
przypominające grill.me dopytywanie o założenia. Brakuje jednak początkowego
wyboru tempa rozmowy.

Przy starcie `architect` agent powinien zapytać Alexa, który tryb woli:

- jedno pytanie naraz, z większym kontekstem i rekomendacją;
- kilka wątków w jednej wiadomości, z mniejszą ilością kontekstu.

## Desired behavior

- Wejście w `architect` powinno zawierać jedno pytanie o tryb prowadzenia
  rozmowy, zanim agent rozpocznie właściwe rundy elicitation.
- Tryb `jedno pytanie naraz` powinien być nadal junior-friendly: agent daje
  więcej kontekstu, rekomenduje opcję i pyta o jedną decyzję.
- Tryb `kilka wątków` powinien grupować powiązane decyzje w jednej wiadomości,
  ale krócej tłumaczyć tło, żeby nie rozdmuchać rozmowy.
- Grill.me / premise-challenge część `deep-elicit` ma respektować wybrany tryb:
  albo omawiać założenia pojedynczo, albo skondensować kilka wątków razem.

## Boundary

Ten fix nie należy do Batcha 7 i nie powinien powiększać aktywnego cyklu
`20260509-alex-readable-change-explanations-fix`.

Nie implementować teraz. To jest future fix intake. Przyszły scope powinien
być wąski: `architect.workflow.md`, ewentualnie `deep-elicit/SKILL.md`,
generator command mirrors/testy, jeśli wymagają aktualizacji.

## Candidate acceptance

- `architect` jasno pyta o preferowany tryb elicitation przy starcie nowego
  cyklu.
- Instrukcja rozróżnia większy kontekst + rekomendację od krótszego,
  wielowątkowego trybu.
- Test tekstowy pilnuje, że `architect` surface zawiera ten wybór.
- Batch 7 pozostaje bez tego scope.
