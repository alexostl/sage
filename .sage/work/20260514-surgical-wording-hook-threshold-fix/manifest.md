---
cycle_id: "20260514-surgical-wording-hook-threshold-fix"
title: "Fix: surgical wording edits nie powinny produkowac manifest bloatu"
workflow: fix
phase: intake
status: intake
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
priority: P1
needs-triage: true
source: "conversation"
suggested_workflow: fix
tags:
  - needs-triage
  - codex-hooks
  - surgical-fix
  - manifest-bloat
  - instruction-bloat
  - real-trace
related:
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/post-tool-check.sh"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
  - "20260514-instruction-surface-minimization-pass-fix"
  - "20260514-source-mutating-cycle-concurrency-fix"
external_trace:
  repo: "/Users/alexostl/Developer/alex-os-dev"
  commit: "7683f89 Polish SageWiki summary pointer wording"
  cycle: "20260514-project-memory-summary-wording"
  manifest: ".sage/work/20260514-project-memory-summary-wording/manifest.md"
  thread_hint: "Codex thread in alex-os-dev, 2026-05-14; search for: 'Chcemy zrobic punkt 2 jako szybki surgical fix w trybie bez planu?'"
---

# Fix: surgical wording edits nie powinny produkowac manifest bloatu

## State

**Current phase:** intake - capture only. Implementacja nie zostala rozpoczeta.

**Next step:** Wejsc w osobny `/sage:fix`, odtworzyc trace z `alex-os-dev` i
zdecydowac, czy hooki powinny miec osobna klase bezpiecznych micro/surgical
edits, czy wystarczy lepszy threshold i recovery message.

## Problem

Hooki Codex/Sage sa obecnie celowo konserwatywne, ale realny przypadek z
`alex-os-dev` pokazal, ze ta konserwatywnosc moze produkowac dokumentacyjny
bloat: jedna korekta zdania w skillu wymusila osobny manifest, mimo ze zmiana
byla mala, lokalna i wynikala z decyzji juz omowionej w rozmowie.

Punktem wyjscia nie jest abstrakcyjna prosba o "mniej papierologii", tylko
konkretny trace:

1. Alex zapytal, czy punkt 2 mozna zrobic jako szybki surgical fix bez planu:
   `Chcemy zrobic punkt 2 jako szybki surgical fix w trybie bez planu?`
2. Agent uznal, ze tak, bo realna zmiana dotyczyla jednego zdania w
   `skills/alex-os:project-memory/SKILL.md`.
3. Agent sprobowal zmienic wording z `lub capture w Sage Wiki` na
   `albo summary w Sage Wiki`.
4. PreToolUse hook zablokowal patch komunikatem o braku aktywnego cyklu
   implementacyjnego.
5. Agent utworzyl minimalny manifest
   `.sage/work/20260514-project-memory-summary-wording/manifest.md`, dopiero
   potem wykonal patch, sprawdzil `rg`/`git diff` i zamknal cykl commitem
   `7683f89 Polish SageWiki summary pointer wording`.
6. Po fakcie Alex zakwestionowal koszt procesu: realna zmiana to jedno zdanie,
   a obsluga wymagala okolo 20 linii manifestu plus osobnego cyklu.

Wniosek roboczy: dla true surgical wording fixes Sage powinien miec tanszy tryb
audytu niz pelny manifest, o ile da sie zachowac ochrone przed przypadkowymi
zmianami w instrukcjach, hookach, runtime i konfiguracji.

## Why this may be a larger fix

Ten intake moze urosnac do przebudowy logiki hookow, bo problem nie ogranicza
sie do jednego komunikatu. Trzeba przejrzec cala sciezke:

- klasyfikacje mutacji w `PreToolUse`;
- roznice miedzy runtime/source/config/security changes a wording-only edits;
- reguly dla instruction/process surfaces, ktore dzis sa traktowane bardzo
  ostroznie nawet przy jednym zdaniu;
- sposob, w jaki hook odroznia `Lightweight/Surgical` od `Standard+`;
- to, czy wystarczy final conversation summary, `.sage/.auto-fixes.log`, maly
  audit entry, czy jednak minimalny manifest;
- real harness scenarios, zeby nie poluzowac ochrony dla zmian ryzykownych.

Celem nie jest obejscie Sage gates. Celem jest mniejszy koszt dla drobnych,
lokalnych korekt, ktore nie zasluguja na pelny cykl, plan i dokumentacje.

## Desired behavior

Sage powinien pozwalac na bardzo male surgical fixes bez tworzenia manifestu,
jezeli spelniaja twarde kryteria bezpieczenstwa. Przykladowo:

- jedna lokalna zmiana wordingowa lub oczywista korekta;
- brak zmiany runtime behavior, hookow, security, MCP, generated output albo
  public API;
- brak nowego zakresu wzgledem rozmowy z uzytkownikiem;
- latwa weryfikacja przez `git diff`/`rg`;
- jasny final summary zamiast osobnego `.sage/work/*/manifest.md`.

Jezeli zmiana dotyka instruction/process surfaces, przyszly fix musi swiadomie
rozstrzygnac, czy wszystkie takie zmiany zawsze wymagaja manifestu, czy istnieje
bezpieczna podklasa: np. wording alignment z juz zatwierdzona decyzja.

## Acceptance Criteria

- Przyszly fix odtwarza trace z `alex-os-dev` i uzywa go jako regresji albo
  scenario note.
- Hook/harness rozroznia prawdziwy micro/surgical edit od zmian, ktore tylko
  udaja male, ale realnie zmieniaja zachowanie systemu.
- Drobne wording-only fixes nie tworza automatycznie manifest bloatu.
- Zmiany w hookach, security, runtime, MCP, generated output i niejasnych
  instruction surfaces nadal wymagaja wlasciwego workflow scope.
- Recovery message mowi agentowi, kiedy moze uzyc microfix path, a kiedy musi
  wejsc w `/sage:fix`.
- Rozwiazanie jest zgodne z intake
  `20260514-instruction-surface-minimization-pass-fix`: najpierw minimalna
  skuteczna zmiana, potem dopiero dodatkowy prompt/instruction text.

## Boundary

Ten intake niczego jeszcze nie zmienia w hookach. Nie zatwierdza tez
automatycznie zasady, ze kazda zmiana w skillach/instrukcjach moze isc bez
manifestu. To ma byc zdiagnozowane w przyszlym fixie na podstawie trace i
realnych scenariuszy harnessa.
