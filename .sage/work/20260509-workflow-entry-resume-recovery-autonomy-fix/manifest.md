---
cycle_id: "20260509-workflow-entry-resume-recovery-autonomy-fix"
title: "Fix: workflow entry, resume, recovery i autonomia"
workflow: fix
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-10
owner: alexostl
priority: P1
classification: Systemic
semantic_reclassification: accepted
review_status: approve-with-changes
source_cycle: "20260509-open-work-cluster-map"
cluster: "B"
related:
  - ".sage/work/20260509-cycle-workflow-entry-enforcement-fix/manifest.md"
  - ".sage/work/20260509-agent-resume-intake-cycle-fix/manifest.md"
  - ".sage/work/20260509-hook-block-recovery-behavior-fix/manifest.md"
  - ".sage/work/20260509-blocking-hook-guidance-review/manifest.md"
  - ".sage/work/20260509-cycle-state-disclosure-fix/manifest.md"
  - ".sage/work/20260509-active-cycle-lease-lock/manifest.md"
  - ".sage/work/20260509-autonomous-approval-boundary-fix/manifest.md"
scope:
  - ".sage/work/20260509-workflow-entry-resume-recovery-autonomy-fix/*"
  - ".sage/docs/runbooks/codex-realharness.md"
  - ".sage/decisions.md"
  - "core/capabilities/orchestration/sage-navigator/SKILL.md"
  - "core/capabilities/orchestration/build-loop/SKILL.md"
  - "core/workflows/build.workflow.md"
  - "core/workflows/fix.workflow.md"
  - "core/workflows/continue.workflow.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/turn-audit.sh"
  - "runtime/platforms/codex/hooks/lib/active_init.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - "runtime/platforms/codex/hooks/tests/turn-audit.bats"
  - "runtime/platforms/codex/setup/lib/hooks-deploy.sh"
  - "runtime/platforms/codex/setup/tests/stage5-6-hooks.bats"
  - "runtime/platforms/codex/harness/lib/aggregate-signals.sh"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
  - "runtime/platforms/codex/harness/prompts/*.txt"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
---

# Fix: workflow entry, resume, recovery i autonomia

## State

**Current phase:** completed. Cykl został zamknięty po closeout checkpoint.
Implementacja bazowa została wykonana w zatwierdzonym scope, testy
deterministyczne przeszły, a QA RealHarness została opisana z jawnymi uwagami.

**Next step:** Brak dalszej pracy w tym cyklu. Residual findings zostały
przeniesione do istniejących follow-upów: recovery-first guidance w klastrze A
oraz Language Invariant Matching dla `12`.

**Closeout notes:** Nie zaostrzamy już Bash hooka w tym cyklu. Ostatni
RealHarness `03` pokazał obfuskowane obejście ścieżki przez `Bash`; traktujemy
to jako residual note / follow-up sygnał, a nie powód do budowy parsera shell.
Kierunek poprawy "hook ma naprowadzać agenta na dobrą korektę, nie eskalować
ściany" jest już ujęty w artefaktach klastra A:
`.sage/work/20260509-hook-block-recovery-behavior-fix/manifest.md` oraz
`.sage/work/20260509-blocking-hook-guidance-review/manifest.md`.

**Language-invariant note:** Scenario `12` semantycznie pokazało oczekiwane
zachowanie `[F]`, ale failuje przez językowo kruchą rubrykę transcript regex.
Ten temat zostaje poza Cluster B i jest przejęty przez
`.sage/work/20260510-language-invariant-workflow-matching-fix/manifest.md`.

**Flex rerun:** Subset `03 + 12` został uruchomiony z `service_tier="flex"` i
output przeniesiono pod
`~/tmp/codex-realharness-cluster-b-flex-20260510-112235`. Oba scenariusze
zakończyły się `rc=1`, ponieważ Codex API zwróciło
`Unsupported service_tier: flex`; to jest environment/API blocker, nie pass ani
fail zachowania agenta.

**RealHarness runbook:** przed kolejnym runem przeczytać
`.sage/docs/runbooks/codex-realharness.md`.

## Cluster Scope

Ten cykl konsoliduje Klaster B z
`.sage/work/20260509-open-work-cluster-map/cluster-map.md`:

- workflow entry musi tworzyć albo wznawiać formalny cykl;
- resume intake/paused cycle musi wykonać state transition przed artefaktami;
- recoverable hook block ma prowadzić do poprawionego retry;
- cycle state disclosure ma mówić o wykonanym transition, nie o intencji;
- active-cycle lease lock ma rozróżniać parked state od aktywnej sesji;
- `[F] Full autonomous implementation` ma być związane z konkretnym
  zatwierdzonym snapshotem planu i scope.

## Root Cause Summary

Sage ma kilka lokalnych reguł dla wejścia, wznowienia, recovery i autonomii,
ale brakowało jednego nadrzędnego kontraktu dla pracy, która realnie wymaga
stanu Sage: **Standard+/Moderate+ workflow, aktywny cykl, recovery i trwałe
decyzje muszą mieć widoczny state transition na dysku albo kontrolowany hard
stop.**

Lightweight/Surgical może pozostać lekkie i nie musi automatycznie tworzyć
wpisów w `.sage`, jeśli nie tworzy trwałej decyzji, incydentu, learningu ani
nie dotyka aktywnego cyklu.

## Evidence Links

- `.sage/work/20260509-workflow-entry-resume-recovery-autonomy-fix/root-cause.md`
- `.sage/work/20260509-open-work-cluster-map/cluster-map.md`
- `.sage/work/20260509-autonomous-approval-boundary-fix/plan.md`

## Boundary

Cykl jest zamknięty. Nie rozszerzać runtime ani hooków w tym cyklu. Każda
dalsza praca nad residual `03` albo `12` wymaga wznowienia właściwego follow-upu
lub nowego cyklu.

## User Calibration 2026-05-10

- Fix 1 musi wyjaśnić różnicę między Lightweight/Surgical a Standard+ i nie
  blokować oczywistych drobnych zmian, które Sage może zrobić bez pełnego
  cyklu artefaktów.
- Fix 3 ma traktować hook block jako recovery-first zawsze: blokada powinna
  zatrzymać nielegalną akcję, ale dać agentowi wykonalną ścieżkę korekty.
- Fix 5 ma obejmować jawną komunikację każdej zmiany statusu, nie tylko wejścia
  i wyjścia z cyklu.
- Fix 6, active-cycle lease lock, wdrażamy tylko jeśli plan znajdzie bardzo
  prosty wariant. Jeśli wymaga ciężkiego mechanizmu lease/TTL/session
  ownership, odrzucamy z zakresu tego klastra.
- Fix 7 ma być opisany miękko: `[F]` to zgoda na wykonanie zatwierdzonego planu
  bez checkpointów, chyba że w trakcie pojawią się kluczowe decyzje zasadniczo
  zmieniające założenia.

## User Calibration 2026-05-10, part 2

- Poniżej Standard+ agent nie powinien automatycznie tworzyć wpisów w `.sage`
  dla każdej drobnej zmiany. `.sage` zapisuje tylko wtedy, gdy drobna praca
  tworzy trwałą decyzję, follow-up, learning, incydent/recovery albo dotyka
  aktywnego cyklu.
- Prosty model Fix 6: cykl w `status: in-progress` może edytować tylko sesja,
  która aktywowała ten stan. Podfazy typu `plan-gate`, `fix-scope-gate`,
  `deliver` są traktowane jako fazy w ramach tego samego `in-progress` claim,
  a nie osobne locki.
