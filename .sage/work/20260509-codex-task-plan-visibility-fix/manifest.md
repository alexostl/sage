---
cycle_id: "20260509-codex-task-plan-visibility-fix"
title: "Fix: widoczność tasków Codexa dla workflow Sage"
workflow: fix
phase: intake
status: intake
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
needs-triage: true
priority: P2
source: "side conversation"
suggested_workflow: fix
related:
  - ".sage/work/20260509-open-initiatives-consolidation/manifest.md"
  - ".sage/work/20260509-cycle-state-disclosure-fix/manifest.md"
  - "core/capabilities/orchestration/sage-navigator/SKILL.md"
  - "core/workflows/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/**"
scope:
  - ".sage/work/20260509-codex-task-plan-visibility-fix/*"
  - ".sage/decisions.md"
  - "core/capabilities/orchestration/sage-navigator/SKILL.md"
  - "core/workflows/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/**"
---

# Fix: widoczność tasków Codexa dla workflow Sage

## State

**Current phase:** intake - capture only. Implementacja nie została rozpoczęta.

**Next step:** Wejść w `/sage:fix` i ustalić, gdzie dopisać invariant:
przy Standard+ pracy Sage agent powinien używać natywnego Codex task-plan UI
(`update_plan`) oraz aktualizować statusy kroków przy checkpointach.

## Finding

Podczas cyklu `20260509-open-initiatives-consolidation` użytkownik pierwszy raz
zobaczył w Codex czytelny widok tasków wykonywanych w ramach pracy Sage. To
zadziałało dlatego, że agent użył natywnego mechanizmu `update_plan`, a nie
dlatego, że Sage sam z siebie renderuje taki widok.

Efekt jest pożądany: użytkownik widzi równolegle formalny workflow Sage oraz
żywy, aplikacyjny pasek postępu Codexa.

## Desired behavior

Dla Standard+ workflow Sage w Codex:

- agent tworzy krótki plan przez `update_plan`, zwykle 3-6 kroków;
- plan odzwierciedla realny etap pracy, nie zastępuje `manifest.md` ani
  checkpointów Sage;
- agent aktualizuje statusy, gdy kończy istotny krok;
- przy checkpointach plan pozostaje zgodny ze stanem artefaktów;
- lekkie pytania/read-only rozmowy nadal nie wymagają task-plan UI.

## Candidate scope

- Dopisać zasadę do generated Codex operating contract albo `sage-navigator`.
- Ustalić progi: kiedy `update_plan` jest wymagany, a kiedy byłby hałasem.
- Dodać regresję tekstową w Stage 3/AGENTS.md albo odpowiednim teście
  instrukcji, żeby invariant nie zniknął po `bin/sage update`.
- Sprawdzić związek z `cycle-state-disclosure-fix`: task-plan UI pokazuje
  postęp kroków, a disclosure komunikuje formalne wejście/wyjście z cyklu.

## Boundary

Ten cycle nie zmienia jeszcze instrukcji ani runtime. Nie wymusza task-plan UI
dla każdej odpowiedzi. Dotyczy tylko pracy Standard+ w Codex, gdzie plan
rzeczywiście pomaga użytkownikowi śledzić wykonanie.
