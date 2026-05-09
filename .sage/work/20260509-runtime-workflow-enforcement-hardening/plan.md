---
title: "Plan: hardening modelu cyklu, scope, recovery i harness"
workflow: fix
cycle_id: "20260509-runtime-workflow-enforcement-hardening"
phase: fix-scope-gate
status: in-progress
created: 2026-05-09
updated: 2026-05-09
classification: Systemic
---

# Plan: hardening modelu cyklu, scope, recovery i harness

## Scope Classification

**Systemic fix.**

Powód: zmiana obejmuje model workflow state, hook resolver, status/recovery UX,
deployed/source hook consistency i harness release blockers. To jest więcej niż
lokalna poprawka w jednym pliku.

## Decisions To Lock

1. **Checkpoint state:** checkpoint w aktywnej rozmowie nie pauzuje cyklu.
   Canonical state:

   ```yaml
   status: in-progress
   phase: root-cause-gate | fix-scope-gate | plan-gate | findings-checkpoint
   ```

   `paused` oznacza session handoff albo realne odłożenie cyklu.

2. **Cycle Resolver:** resolver wybiera ownera mutacji z path intentu i typu
   mutacji, nie z globalnego newest active.

3. **Cross-cycle capture:** agent w cyklu A może zapisać finding do istniejącego
   cyklu B albo utworzyć minimalny intake C, jeśli patch jest capture-only.

4. **Implementation boundary:** capture-only nie może zawierać runtime/code/test
   changes. Implementacja dla B/C wymaga formalnego resume/start i gates.

5. **Recovery wording:** domyślnie poprawiamy komunikaty z `sage continue` na
   jednoznaczny workflow/skill wording `sage:continue` albo natural-language
   "resume the selected cycle"; CLI alias rozważyć tylko jeśli plan review uzna
   go za potrzebny.

6. **Codex subagent authorization:** Sage nie próbuje obchodzić `spawn_agent`
   policy. Checkpointy i full-autonomy opcje muszą zawierać jawne
   upoważnienie usera do odpalenia subagenta, np. `[A] Subagent review —
   explicitly authorize Codex to spawn a read-only subagent for this review`.
   Wybranie `A` po takim tekście jest traktowane jako literalna prośba o
   subagenta/delegację. Samo "review poproszę" bez takiego kontekstu nie
   wystarcza; wtedy Sage ma zapytać o subagent review vs self-review.

## Files To Change

### Core workflow/state rules

- `core/workflows/fix.workflow.md`
  - doprecyzować, że root cause gate i scope gate zostawiają `status:
    in-progress`;
  - `paused` tylko dla `[N] New session` albo jawnego odłożenia.
  - zmienić root-cause/fix-scope `[A] Review` na explicit subagent
    authorization wording.

- `core/workflows/build.workflow.md`
  - sprawdzić i zachować spójność już istniejącego invariant: checkpoint update
    bez pauzy.
  - zmienić checkpointy `[A] Review` na jawne `[A] Subagent review` z tekstem,
    że wybór tej opcji autoryzuje odpalenie read-only subagenta.

- `core/workflows/architect.workflow.md`
  - analogicznie zmienić ADR/design i plan checkpointy, które dziś mówią
    "sub-agent reviews", na jawne authorization wording.

- `core/workflows/sub-workflows/quality-gates.workflow.md`
  - usunąć niejawne "MUST use sub-agent when available" bez zgody usera;
  - jeśli subagent gate ma być wymagany w trybie Codex, approval musi pochodzić
    z wcześniejszej opcji checkpointu, np. `[F] Full autonomous implementation`
    z explicit subagent authorization, albo z osobnego pytania przy gate.

- `core/workflows/status.workflow.md`
  - doprecyzować różnicę między `in-progress` gated state a `paused/intake`.

- `core/workflows/continue.workflow.md`
  - opisać formalne resume dla prawdziwie parked cycles.

### Codex generated guidance

- `runtime/platforms/codex/setup/lib/agents-md.sh`
  - dodać concise invariant: checkpoint nie pauzuje cyklu;
  - opisać cross-cycle capture jako legalną capture-only ścieżkę;
  - odróżnić capture-only od implementation.
  - dopisać Codex-specific rule: subagenta wolno odpalić tylko po jawnej
    zgodzie usera; Sage checkpoint może ją uzyskać przez opcję zawierającą
    słowa `subagent`, `delegation` albo `parallel agent work`.

- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - dodać regresje dla checkpoint active gated state i cross-cycle capture
    wording.
  - dodać regresję, że wygenerowany `AGENTS.md` zawiera explicit subagent
    authorization rule i nie sugeruje niejawnego auto-spawn po zwykłym
    "review".

### Hook resolver and deployed consistency

- `runtime/platforms/codex/hooks/lib/active_init.sh`
  - utrwalić albo poprawić `resolve_cycle_for_patch`;
  - dodać classification helper dla same-cycle gated updates, cross-cycle
    capture i new intake manifest.

- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
  - użyć resolvera jako canonical path;
  - pozwolić na capture-only update do existing parked/intake cycle oraz new
    intake bootstrap;
  - blokować mixed capture + implementation;
  - poprawić recovery wording dla parked cycles.

- `.codex/hooks/lib/active_init.sh`
- `.codex/hooks/pre-tool-validate.sh`
  - zaktualizować dogfood deployed hooks po zmianie source albo przez
    `bin/sage update`; nie zostawiać aktywnego repo na starszym hooku.

### Status and CLI UX

- `bin/sage`
  - zmienić `status` output z `next: sage continue` na wykonalny tekst;
  - jeśli zdecydujemy się na alias CLI, dodać go wraz z testem; domyślnie
    preferować korektę wording bez aliasu.

- `runtime/platforms/codex/setup/tests/status.bats`
  - zaktualizować oczekiwania statusu dla parked/intake next move.

### Hook/harness tests

- `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`
  - test: same-cycle gated update allowed when `status: in-progress`,
    `phase: root-cause-gate`;
  - test: cross-cycle capture to existing intake/paused cycle allowed;
  - test: cross-cycle capture with implementation file blocks;
  - test: new minimal intake manifest allowed while another cycle is active;
  - test: ambiguous multi-cycle implementation blocks.

- `runtime/platforms/codex/hooks/tests/active_init.bats`
  - testy dla `resolve_cycle_for_patch`: path-intent owner, parked capture,
    bootstrap i ambiguous multi-cycle paths.

- `runtime/platforms/codex/harness/v11-scenarios.json`
  - dodać release-blocking rubric dla scenariusza 03, np.
    `forbidden_changed_patterns: ["^src/"]` i/lub required recovery transcript.
  - dodać albo rozszerzyć scenariusz checkpoint review: user wybiera opcję,
    która jawnie autoryzuje subagenta, i transcript musi pokazać próbę
    subagent review; osobny wariant "review poproszę" nie może spontanicznie
    spawnować subagenta.

- `runtime/platforms/codex/harness/lib/aggregate-signals.sh`
  - upewnić się, że empty rubric nie liczy się jako wystarczający blocker, gdy
    claim mówi o blocked mutation.

- `runtime/platforms/codex/harness/tests/aggregate-signals.bats`
  - zaktualizować lub dodać testy dla release-blocker rubric scenariusza 03 i
    pustej rubryki przy claimie wymagającym blocked mutation.

## Tests To Run

1. `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`
2. `bats runtime/platforms/codex/hooks/tests/active_init.bats`
3. `bats runtime/platforms/codex/setup/tests/status.bats`
4. `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
5. `bats runtime/platforms/codex/setup/tests/stage5-6-hooks.bats`
6. `bats runtime/platforms/codex/harness/tests/aggregate-signals.bats`
7. Relevant harness aggregate check for `v11-scenarios.json`.
8. `rg -n "\\[A\\] Review|sub-agent reviews|MUST use sub-agent" core/workflows runtime/platforms/codex/setup/lib/agents-md.sh`
   should return only deliberately updated compatibility notes, not active
   Codex checkpoint wording that lacks explicit authorization.

## Review Fixes

Auto-review 2026-05-09 zwrócił `NEEDS REVISION`. Poprawki:

- dodano `core/workflows/build.workflow.md` do manifest scope;
- dodano `runtime/platforms/codex/hooks/tests/active_init.bats` do scope i
  testów;
- dodano `runtime/platforms/codex/harness/tests/aggregate-signals.bats` do
  scope i testów;
- zmieniono frontmatter planu z `status: pending-approval` na
  `status: in-progress`, żeby checkpoint nie wyglądał jak parked state.
- po Codex `spawn_agent` policy finding dodano workaround: Sage checkpointy
  muszą prosić o explicit subagent authorization, a nie traktować zwykłego
  "review" jako zgody na delegację.

## Rollback

Zmiany są tekstowe/bashowe i odwracalne przez revert patcha. Jeśli dogfood
`.codex/hooks/**` po update okaże się problematyczny, revert source + deployed
hooków razem; nie zostawiać rozjazdu między source i deployed.

## Risk

- Zbyt szeroki capture-only exception może stać się furtką do cross-cycle
  implementation.
- Zbyt wąski exception zostawi obecny problem: nie da się zapisać findingu do
  właściwego cyklu.
- Aktualizacja `.codex/hooks/**` w aktywnym repo może zmienić zachowanie hooków
  w trakcie pracy, więc musi być testowana przed kontynuacją implementacji.

## Review Recommendation

Proceed as `/sage:fix` Systemic, nie eskalować do `/sage:architect`, jeśli plan
pozostanie przy uszczelnieniu istniejącego modelu. Eskalować dopiero, jeśli w
implementacji okaże się potrzebna nowa formalna state machine albo nowy runtime
service zamiast bash hooków.
