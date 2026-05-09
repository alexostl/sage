---
cycle_id: "20260509-runtime-workflow-enforcement-hardening"
title: "Fix: hardening modelu cyklu, scope, recovery i harness"
workflow: fix
phase: closed
status: completed
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
priority: P1
semantic_reclassification: accepted
source_analysis: ".sage/docs/analysis-open-initiatives-consolidation.md"
scope:
  - ".sage/work/20260509-runtime-workflow-enforcement-hardening/*"
  - ".sage/decisions.md"
  - ".sage/docs/analysis-open-initiatives-consolidation.md"
  - ".sage/work/20260509-runtime-process-dummy-qa/qa-report.md"
  - ".sage/work/20260509-runtime-process-reliability-patch/review-report.md"
  - "core/workflows/fix.workflow.md"
  - "core/workflows/build.workflow.md"
  - "core/workflows/architect.workflow.md"
  - "core/workflows/sub-workflows/quality-gates.workflow.md"
  - "core/workflows/status.workflow.md"
  - "core/workflows/continue.workflow.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "runtime/platforms/codex/hooks/lib/active_init.sh"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/active_init.bats"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
  - "runtime/platforms/codex/harness/lib/aggregate-signals.sh"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
  - "bin/sage"
  - "runtime/platforms/codex/setup/tests/status.bats"
  - ".codex/hooks/lib/active_init.sh"
  - ".codex/hooks/pre-tool-validate.sh"
  - ".sage/work/20260509-binary-asset-mutation-contract-fix/*"
---

# Fix: hardening modelu cyklu, scope, recovery i harness

## State

**Current phase:** closed - implementacja zaakceptowana przez Alexa i
zweryfikowana testami.

**Root cause artifact:**
`.sage/work/20260509-runtime-workflow-enforcement-hardening/root-cause.md`

**Plan artifact:**
`.sage/work/20260509-runtime-workflow-enforcement-hardening/plan.md`

**Checkpoint:** fix zaakceptowany i zamknięty.

## Problem

Otwarte intake cycles z 2026-05-09 wskazują na powiązane luki w modelu Sage:
wybór bieżącego cyklu dla mutacji, klasyfikacja mutacji `.sage/**`, recovery
guidance, real-agent enforcement i publiczna powierzchnia skilli.

Dodatkowy runtime conflict wykryty 2026-05-09: Codex `spawn_agent` tool policy
pozwala odpalać subagentów tylko gdy user jawnie prosi o subagentów,
delegację albo równoległą pracę agentów. Obecne checkpointy Sage typu
`[A] Review` są zbyt niejawne i mogą prowadzić do self-review albo naruszenia
tool policy.

## Boundary

Ten manifest uruchamia umbrella `/sage:fix`, ale nie zatwierdza implementacji.
Przed zmianami w kodzie musi powstać zatwierdzona root cause diagnosis, a dla
Moderate/Systemic scope także `plan.md` z pełnym zakresem plików i testów.

## Implementation Summary

- Utrwalono invariant: checkpointy zostają `status: in-progress` i przesuwają
  `phase`; `paused` oznacza realne zaparkowanie/handoff.
- Doprecyzowano Cycle Resolver/capture path: cross-cycle capture do istniejącego
  intake/paused albo nowego minimalnego intake jest legalny tylko jako
  capture-only.
- Poprawiono recovery/status wording z `sage continue` na `sage:continue` albo
  natural-language resume.
- Dodano rubrykę release-blocking dla scenariusza 03 i guard w aggregatorze, że
  blocked/recovery release blocker nie może mieć pustej rubryki.
- Zaktualizowano dogfood `.codex/hooks` z source hooks.

## Verification

- `bats runtime/platforms/codex/hooks/tests/active_init.bats` — 15/15 passed
- `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` — 47/47 passed
- `bats runtime/platforms/codex/setup/tests/status.bats` — 15/15 passed
- `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats` — 44/44 passed
- `bats runtime/platforms/codex/setup/tests/stage5-6-hooks.bats` — 13/13 passed
- `bats runtime/platforms/codex/harness/tests/aggregate-signals.bats` — 10/10 passed
