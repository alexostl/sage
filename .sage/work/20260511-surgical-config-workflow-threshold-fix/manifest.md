---
cycle_id: "20260511-surgical-config-workflow-threshold-fix"
title: "Fix: pojedyncza zmiana config nie powinna wymuszac Sage workflow"
workflow: fix
phase: completed
status: completed
created: 2026-05-11
updated: 2026-05-13
completed: 2026-05-13
owner: alexostl
priority: P1
source: "conversation"
source_thread: "codex://threads/019e185a-b3d2-7c21-a1e8-14a3cd345d24"
root_cause_approved: true
plan_approved: true
implementation_mode: full-autonomous
semantic_reclassification: accepted
classification: moderate
plan: ".sage/work/20260511-surgical-config-workflow-threshold-fix/plan.md"
verification: ".sage/work/20260511-surgical-config-workflow-threshold-fix/verification.md"
qa_report: ".sage/work/20260511-surgical-config-workflow-threshold-fix/qa-report.md"
qa_approved: true
qa_warning_resolved: true
scope:
  - ".sage/work/20260511-surgical-config-workflow-threshold-fix/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/lib/active_init.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - "runtime/platforms/codex/hooks/tests/active_init.bats"
  - "core/constitution/sage-process.constitution.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/lib/config-toml.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "runtime/platforms/codex/setup/tests/stage4-config-toml.bats"
---

# Fix: pojedyncza zmiana config nie powinna wymuszac Sage workflow

## State

**Current phase:** completed - implementacja, QA follow-up i finalna
weryfikacja zakonczone.

**Next step:** brak. Cykl zamkniety.

## Problem

W watku `codex://threads/019e185a-b3d2-7c21-a1e8-14a3cd345d24` pojedyncza
zmiana w pliku konfiguracyjnym zostala potraktowana tak, jakby sama z siebie
wymagala pelnej metodologii Sage. To jest ostrzejsze niz ustalony model:
Lightweight/Surgical moze przejsc bez cyklu, a dopiero zmiana w trzech plikach
albo realny Moderate+ zakres wymaga formalnego workflow.

## Root Cause

Root cause zostal skorygowany po odczycie wskazanego watku. Pierwsza diagnoza
byla zbyt pospieszna: wskazywala glownie na guidance/routing, ale transcript
pokazuje bezposrednia blokade `PreToolUse`.

W watku agent probowal wykonac pojedynczy patch:

```text
config/codex-config.toml
model_reasoning_effort = "low" -> "medium"
```

Hook zablokowal ten pierwszy `apply_patch` zanim zmiana weszla na dysk:

```text
Command blocked by PreToolUse hook: Sage: no active implementation cycle.
Found parked paused/intake work: ...
Parked cycles are manifest-only/resumable context, not implementation-active.
```

Rzeczywisty problem jest wiec w runtime enforcement: hook traktuje kazda
mutacje poza aktywnym cyklem jako wymagajaca formalnego workflow, takze
pojedyncza, chirurgiczna zmiane config. To omija ustalona kalibracje, w ktorej
1-2 pliki moga byc Lightweight/Surgical, a dopiero 3 pliki albo realny
Moderate+ zakres wymaga pelnej metodologii.

Guidance nadal jest prawdopodobnym wspolzrodlem, bo mowi bezwarunkowo, ze
`source/runtime/test/config/instruction behavior changes require the proper
Sage workflow`, ale dowod z watku pokazuje, ze najpierw trzeba naprawic albo
doprecyzowac zachowanie hooka `PreToolUse` dla single-file config changes.

## Rejected Earlier Hypothesis

Odrzucona / zdegradowana diagnoza: same zrodla kontraktu mieszaja dwie rozne
zasady:

- prog strukturalny dla fixow: `Surgical` to 1-2 pliki, a `Moderate+` zaczyna
  sie przy 3 plikach albo przy zmianie wzorca/test infrastructure;
- osobna linia w always-loaded policy mowi, ze `source/runtime/test/config/
  instruction behavior changes require the proper Sage workflow`, bez progu
  plikow i bez wyjatku dla malej, pojedynczej zmiany config.

To nadal moze pchac agentow w zla strone, ale w analizowanym watku triggerem
nie byla tylko interpretacja agenta. Blokada przyszla z hooka.

## Evidence

- Wskazany transcript:
  `/Users/alexostl/.codex/archived_sessions/rollout-2026-05-11T20-44-18-019e185a-b3d2-7c21-a1e8-14a3cd345d24.jsonl`.
- Pierwszy `apply_patch` na
  `/Users/alexostl/Developer/alex-os-dev/config/codex-config.toml` zostal
  zablokowany przez `PreToolUse`.
- Komunikat hooka mowil `Sage: no active implementation cycle`, mimo ze
  zmiana dotyczyla jednego klucza w jednym pliku.
- Po utworzeniu minimalnego manifestu hook przepuscil te sama klase zmiany.
- `core/constitution/sage-process.constitution.md` i generowany Codex
  `AGENTS.md` zawieraja bezwarunkowa guidance dla config/instruction behavior
  changes, co moze utrwalac ten runtime policy choice.

## Hook Log Findings

Logi hookow z target repo `alex-os-dev` potwierdzaja i doprecyzowuja obraz:

- `.sage/.session-mutations.log` nie zawiera pierwszej zablokowanej proby
  zmiany `config/codex-config.toml`, bo `PreToolUse` zatrzymal `apply_patch`
  przed zapisem i przed dopisaniem mutation log entry.
- Po utworzeniu minimalnego manifestu log zapisuje:
  - `18:46:31Z` - `.sage/work/20260511-codex-reasoning-medium/manifest.md`;
  - `18:46:37Z` - `config/codex-config.toml`;
  - `18:47:03Z` - `.sage/decisions.md`;
  - `18:47:08Z` - zamkniecie manifestu.
- Sprawdzono tez pozniejsze incydenty po `alex-os:sync`; na decyzje Alexa sa
  poza zakresem tego fixa i nie stanowia acceptance criteria.

Kodowa galaz blokujaca jest w deployed
`/Users/alexostl/Developer/alex-os-dev/.codex/hooks/pre-tool-validate.sh`:

- `resolve_cycle_for_patch` zwrocilo `none`;
- poniewaz istnialy parked paused/intake cycles, linie 128-132 wypisaly
  `Sage: no active implementation cycle...` i zakonczyly hook `exit 2`;
- ta sciezka nie rozroznia single-file config change od szerszej implementacji.

## Boundary

Nie luzujemy ochrony dla zmian poza scope, wielu plikow ani zmian semantycznych
o duzym zasiegu. Luzujemy falszywy skrot w hooku/policy: pojedyncza
chirurgiczna zmiana config nie moze automatycznie znaczyc "formal Sage
workflow", jesli nie ma aktywnej implementacji, decyzji architektonicznej ani
3-file Moderate+ scope.

## Explicit Non-Goal

Nie naprawiamy w tym cyklu broad generated mutations po `alex-os:sync` ani
`unclaimed_change`/`bypass_mutation` dla wygenerowanych plikow. To jest osobny
temat i nie ma byc mieszany z pierwotnym zgloszeniem.

## Review Revision

Po review root-cause artefakt zostal poprawiony:

- scope obejmuje teraz hook `runtime/platforms/codex/hooks/pre-tool-validate.sh`
  oraz testy hooka, bo to jest wskazana sciezka blokady;
- opis sync/generated-file incidents zostal zredukowany do non-goal, bez
  wciagania go do root cause ani planowanego zakresu.

## Plan Checkpoint

Plan zapisany w `plan.md`. Klasyfikacja: Moderate, bo patch zmienia runtime
predicate, testy hooka oraz generated guidance/testy. Implementacja jest
zablokowana do czasu akceptacji planu.
