---
cycle_id: "20260509-duplicate-sage-entrypoint-fix"
title: "Fix: podwójny ogólny Sage entrypoint"
workflow: fix
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-13
owner: alexostl
needs-triage: true
priority: P2
folded_into: "20260509-selfhost-codex-loader-path-fix"
source: "conversation"
suggested_workflow: fix
related:
  - ".agents/skills/sage/SKILL.md"
  - ".agents/skills/sage:sage/SKILL.md"
  - "core/workflows/sage.workflow.md"
  - "runtime/platforms/codex/setup/lib/skills-deploy.sh"
  - "runtime/platforms/codex/setup/tests/stage7-skills.bats"
  - ".sage/work/20260509-runtime-process-dummy-qa/run-20260509153121/transcripts/"
---

# Fix: podwójny ogólny Sage entrypoint

## State

**Current phase:** completed - folded into Batch 4 anchor
`20260509-selfhost-codex-loader-path-fix`.

**Next step:** Brak osobnej implementacji. Batch 4 anchor usuwa redundantny
`sage:sage` z aktywnej selfhost powierzchni i Stage 7 nie odtwarza go ponownie.

## Finding

W `.agents/skills/` istnieją dwa ogólne wejścia Sage:

- `.agents/skills/sage/SKILL.md` - pierwotny ogólny router z konkretną logiką
  stanu i routingu;
- `.agents/skills/sage:sage/SKILL.md` - wygenerowany loader stub dla
  `core/workflows/sage.workflow.md`.

Efekt w UI jest mylący: Sage / Sage / Sage robi wrażenie potrójnego,
zduplikowanego entrypointu. Dodatkowo obserwacje z badań/harnessu agentów
sugerują, że stary `sage` entrypoint jest wywoływany, a `sage:sage` praktycznie
nie jest używany jako realna ścieżka.

## Alex direction

Preferowana hipoteza do sprawdzenia:

- pierwotny `.agents/skills/sage/SKILL.md` powinien zostać w jakiejś formie;
- wygenerowany `.agents/skills/sage:sage/SKILL.md` powinien zostać usunięty z
  publicznej powierzchni Codex;
- podobnie jak `sage-navigator`, ogólny `sage` entrypoint powinien być jawny i
  bez dodatkowego routingu przez zduplikowany workflow stub.

## Likely root cause

`runtime/platforms/codex/setup/lib/skills-deploy.sh` ma `sage` w
`CODEX_V1_WORKFLOWS`, więc Stage 7 traktuje ogólne `sage.workflow.md` tak jak
pozostałe workflow i tworzy `sage:sage`. To koliduje z osobnym ogólnym
entrypointem `.agents/skills/sage/SKILL.md`.

## Desired behavior

Codex public skill surface powinna mieć jedno czytelne ogólne wejście Sage:

- `sage` jako ręczny/jawny router entrypoint;
- brak redundantnego `sage:sage` na liście UI;
- workflow-specific entrypointy nadal działają jako `sage:build`, `sage:fix`,
  `sage:qa`, itd.;
- testy Stage 7 powinny pilnować, że `sage:sage` nie wraca po `bin/sage update`.

## Candidate scope

- Usunąć `sage` z listy workflow loaderów Codex albo obsłużyć go jako specjalny
  przypadek.
- Zaktualizować testy Stage 7: liczba loaderów, lista workflow i asercje dla
  `sage:sage`.
- Dodać regresję, że `.agents/skills/sage/SKILL.md` istnieje, a
  `.agents/skills/sage:sage/SKILL.md` nie jest generowany.
- Sprawdzić czy dokumentacja/README nie obiecuje `sage:sage`.
- Uwzględnić transcript evidence z QA/harnessu, gdzie agenci czytali
  `sage:sage`, ale routing użytkownika/historycznie korzystał ze starego
  `sage`.

## Boundary

Ten intake nie usuwa jeszcze żadnego skilla. Ostateczna decyzja wymaga
diagnozy w `/sage:fix`, bo trzeba upewnić się, że usunięcie `sage:sage` nie
psuje explicit `$sage:sage` ani ścieżki przez `core/workflows/sage.workflow.md`,
jeśli istnieje zależność runtime.
