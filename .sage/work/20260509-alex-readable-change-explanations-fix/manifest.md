---
cycle_id: "20260509-alex-readable-change-explanations-fix"
title: "Fix: Sage ma tlumaczyc zmiany prostym jezykiem dla Alexa"
workflow: fix
phase: intake
status: intake
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
priority: P1
needs-triage: true
source: "conversation"
scope:
  - ".sage/work/20260509-alex-readable-change-explanations-fix/*"
  - "AGENTS.md"
  - "core/constitution/sage-process.constitution.md"
  - "core/capabilities/**"
  - "core/workflows/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/**"
---

# Fix: Sage ma tlumaczyc zmiany prostym jezykiem dla Alexa

## State

**Current phase:** intake - zapis wymagania. Implementacja nie zostala
rozpoczeta.

**Next step:** Wejsc w `/sage:fix` i doprecyzowac instrukcje Sage tak, zeby w
rozmowie z Alexem agent tlumaczyl zmiany prostym, praktycznym jezykiem.

## Problem

W projekcie jest juz zasada, ze Alex jest Junior Dev Vibecoderem i ze odpowiedzi
maja byc junior-friendly. To jednak nie wystarcza.

Agent nadal potrafi opisac findings tak:

- `broken_frontmatter` na `.sage/decisions.md`;
- `bypass_mutation` / `unclaimed_change`;
- `claim_no_op`;
- `phase_jump_observed`;
- `closeout/documentation mutation model`.

To jest technicznie poprawne, ale dla Alexa brzmi jak raport wewnetrzny systemu,
a nie jak wyjasnienie: "co sie stalo, czemu to przeszkadza i co trzeba zmienic".

## Desired behavior

Sage powinien domyslnie tlumaczyc zmiany w takim stylu:

- najpierw proste zdanie, co system robi zle;
- potem dlaczego to boli w pracy;
- dopiero potem nazwa techniczna w backtickach;
- na koncu konkret: co trzeba poprawic.

Przyklad dobrego stylu:

> Sage mysli, ze `.sage/decisions.md` powinien miec YAML frontmatter, ale to
> jest zwykly dziennik decyzji. Hook traktuje poprawny plik jak zepsuty. Trzeba
> nauczyc hook, ze `decisions.md` jest specjalnym typem pliku.

Przyklad stylu, ktorego chcemy unikac:

> `broken_frontmatter` na `.sage/decisions.md` nadal wystepuje po `bacc53c`,
> wiec nalezy dodac whitelist dla non-frontmatter artifacts.

## Candidate scope

- Doprecyzowac Alex-native instructions w generated `AGENTS.md` / constitution
  / relevant Sage skills.
- Dodac zasade: gdy agent omawia bugi, findings, plan fixa albo trade-offy,
  ma najpierw wyjasnic je ludzkim jezykiem, a dopiero potem nazwac mechanizm.
- Dodac test albo fixture, ktory pilnuje, ze generated guidance zawiera ten
  kontrakt komunikacyjny.
- Sprawdzic, czy podobne wymaganie trzeba dopisac do `sage-navigator`,
  `analyze`, `fix`, `review` albo wspolnej sekcji Alex-native.

## Acceptance criteria

- Nowe instrukcje mowia wprost, ze "junior-friendly" oznacza proste
  wyjasnienie skutku i przyczyny, nie tylko krotsze zdania.
- Agent ma wzorzec odpowiedzi: "co sie dzieje" -> "czemu to problem" -> "jak to
  sie technicznie nazywa" -> "co trzeba zmienic".
- Nazwy techniczne nadal moga byc uzywane, ale nie sa pierwszym ani jedynym
  sposobem wyjasnienia.
- Regresja/test potwierdza, ze generated Codex instructions zawieraja ten
  kontrakt.

## Boundary

Ten fix nie ma upraszczac kodu, nazw plikow, frontmatter ani command names.
Chodzi o jezyk rozmowy i naturalna prose w artefaktach dla Alexa.
