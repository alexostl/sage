---
cycle_id: "20260515-codex-hook-policy-consolidation"
title: "Plan: RealHarness Discovery Spike prerequisites"
workflow: architect
phase: implementation-plan
status: approved
created: 2026-05-15
updated: 2026-05-15
owner: alexostl
source: "Discovery Spike execution plan"
approved_by: alexostl
approved_at: "2026-05-15"
related:
  - ".sage/work/20260515-codex-hook-policy-consolidation/discovery-spike-execution-plan.md"
  - "runtime/platforms/codex/harness/run-harness.sh"
  - "runtime/platforms/codex/harness/lib/aggregate-signals.sh"
  - "runtime/platforms/codex/harness/tests/run-harness.bats"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
  - "runtime/platforms/codex/harness/README.md"
---

# Plan: RealHarness Discovery Spike prerequisites

## Cel

Przygotować RealHarness do Milestone 0, żeby dało się tanio i bezpiecznie
porównać zachowanie agenta w trybach `hooks-on` i `hooks-off` na małym zestawie
realistycznych scenariuszy.

## Zakres implementacji

1. `runtime/platforms/codex/harness/run-harness.sh`
   - dodać `HARNESS_SCENARIOS` dla comma-separated subsetu promptów;
   - dodać `HARNESS_HOOK_MODE=on|off`;
   - dodać `HARNESS_SERVICE_TIER` bez domyślnego `fast` oraz izolowane
     `CODEX_HOME`, żeby nie dziedziczyć lokalnego service tieru;
   - zapisywać `run_mode`, `hook_mode` i `service_tier` w state snapshots.

2. `runtime/platforms/codex/harness/lib/log-parser.sh`
   - rozpoznać realny bracket/key-value format `.sage/.auto-fixes.log`,
     np. `severity=info type=safe-auto-fix`, jako `kind=safe_auto_fix`;
   - zachować istniejące wsparcie dla JSONL, markdown headings i pipe-style
     `kind=...`.

3. `runtime/platforms/codex/harness/lib/aggregate-signals.sh`
   - czytać metadata z pierwszego state snapshotu;
   - raportować `run_mode`, `hook_mode`, `service_tier` i uruchomione prompty;
   - przy `HARNESS_SCENARIOS` oceniać tylko wybrane scenariusze i nie mieszać
     ich z pełnym release gate.

4. `runtime/platforms/codex/harness/v11-scenarios.json`
   - uprościć rubrykę `13-mutation-preflight-lightweight`: pass ma oznaczać
     preflight evidence + active cycle/scope/legal path + brak source/runtime/
     tests mutation + brak bypass/unclaimed audit;
   - nie wymagać nowego manifestu, gdy agent poprawnie zatrzymuje się przy
     aktywnym scoped `plan-gate`.

5. `runtime/platforms/codex/harness/tests/*.bats`
   - potwierdzić obecność selector/hook-mode/service-tier contractu;
   - potwierdzić, że `service_tier="fast"` nie jest już hardcoded;
   - potwierdzić, że targeted run nie udaje pełnego release gate.
   - potwierdzić parser bracket/key-value `.auto-fixes.log`.

6. `runtime/platforms/codex/harness/README.md`
   - opisać nowe env vars;
   - poprawić pre-flight notes o `service_tier`.

## Granice

- Nie zmieniać `runtime/platforms/codex/hooks/pre-tool-validate.sh`.
- Nie implementować jeszcze `audit-only`.
- Nie odpalać pełnego RealHarness.
- Nie zmieniać istniejących scenariuszy merytorycznych poza dokumentacją
  kontraktu runnera.

## Weryfikacja

- `bats runtime/platforms/codex/harness/tests/run-harness.bats`
- `bats runtime/platforms/codex/harness/tests/run-harness-log-parser.bats`
- `bats runtime/platforms/codex/harness/tests/aggregate-signals.bats`
- `bash -n runtime/platforms/codex/harness/run-harness.sh`
- `bash -n runtime/platforms/codex/harness/lib/aggregate-signals.sh`
- targeted RealHarness:
  `HARNESS_SCENARIOS="08-safe-autofix-metadata,13-mutation-preflight-lightweight" runtime/platforms/codex/harness/run-harness.sh`

## Checkpoint

Ten plan wymaga jawnej zgody na runtime/test/docs edit. Obecny hook blokuje
implementację bez canonical `plan.md` zatwierdzonego w osobnej turze, więc to
jest legalny punkt przejścia do implementacji.
