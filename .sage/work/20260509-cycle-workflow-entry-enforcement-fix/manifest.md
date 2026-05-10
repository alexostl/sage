---
cycle_id: "20260509-cycle-workflow-entry-enforcement-fix"
title: "Fix: deklaracja workflow musi otwierac realny cykl"
workflow: fix
phase: intake
status: intake
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
needs-triage: true
priority: P1
source: "conversation"
source_thread: "codex://threads/019e0e84-da08-7843-852e-7d4ad30e0ae0"
suggested_workflow: fix
related:
  - ".sage/work/20260509-agent-resume-intake-cycle-fix/manifest.md"
  - ".sage/work/20260509-cycle-state-disclosure-fix/manifest.md"
  - ".sage/work/20260509-codex-task-plan-visibility-fix/manifest.md"
  - "core/workflows/build.workflow.md"
  - "core/workflows/fix.workflow.md"
  - ".agents/skills/sage/SKILL.md"
  - ".agents/skills/sage-navigator/SKILL.md"
---

# Fix: deklaracja workflow musi otwierac realny cykl

## State

**Current phase:** intake - capture only. Implementacja nie zostala rozpoczeta.

**Next step:** Wejsc w `/sage:fix`, zdiagnozowac punkty routingu, w ktorych
agent deklaruje dopasowanie do workflow, i dodac enforcement, ze pewna
kwalifikacja typu "to pasuje do build workflow" musi utworzyc albo wznowic
formalny cykl przed dalsza praca.

## Finding

Alex wskazal, ze gdy agent mowi w odpowiedzi, ze zadanie pasuje np. do
`build workflow` i jest tego pewien, sama deklaracja w tekscie nie wystarcza.
Agent powinien realnie wejsc w workflow: otworzyc cykl, ustawic jego stan w
artefaktach Sage i dopiero potem kontynuowac prace zgodnie z bramkami tego
workflow.

## Root Problem

Obecny kontrakt moze pozwalac agentowi wykonac poprawna klasyfikacje
konwersacyjna bez odpowiadajacej jej mutacji stanu. W praktyce powstaje
rozjazd:

- rozmowa mowi "wchodzimy w build/fix/review";
- `.sage/work/.../manifest.md` nie istnieje albo nadal jest w stanie intake;
- hooki i kolejne agenty nie widza formalnie aktywnego workflow;
- checkpointy, scope, plan/spec gates i resume behavior staja sie zalezne od
  pamieci rozmowy zamiast od stanu na dysku.

## Why It Matters

Sage ma byc systemem operacyjnym workflow, nie tylko slownikiem etykiet. Jesli
agent trafnie wybiera workflow, ale nie otwiera cyklu, to:

- build/fix gates moga zostac pominiete mimo poprawnej deklaracji;
- runtime nie ma czego egzekwowac;
- uzytkownik widzi pewnosc agenta, ale projekt nie dostaje trwalego stanu;
- po kompakcji albo nowej sesji nastepny agent moze zaczac od zera.

## Candidate Scope

- Doprecyzowac w routerze/navigatorze Sage: pewna klasyfikacja Standard+
  wymaga natychmiastowego formalnego entry do workflow, nie tylko komunikatu.
- Zaktualizowac generated Codex `AGENTS.md` albo odpowiedni always-loaded
  kontrakt, jesli invariant musi byc widoczny przed aktywacja skilla.
- Dodac guidance dla przypadkow:
  - nowy task pasuje do build/fix/review -> utworz nowy cykl;
  - task wskazuje istniejacy intake/paused cycle -> formalnie wznow cykl;
  - agent nie jest pewien workflow -> zadaj krotkie pytanie albo pokaz opcje,
    bez falszywej deklaracji wejscia.
- Dodac regresje/harness:
  - prompt: "to brzmi jak build, zrobmy to";
  - expected: agent tworzy `manifest.md`/cykl przed spec/plan/code;
  - forbidden: sama odpowiedz tekstowa "wchodze w build workflow" bez stanu
    cyklu na dysku.
- Sprawdzic overlap z `agent-resume-intake-cycle-fix`, bo ten intake dotyczy
  wznowienia wskazanego cyklu, a tutaj chodzi szerzej o entry po klasyfikacji
  workflow.

## Boundary

Ten intake nie autoryzuje jeszcze implementacji ani zmiany runtime. To
capture-only follow-up dla wymogu: deklaracja workflow musi byc spelniona
stanem Sage na dysku.
