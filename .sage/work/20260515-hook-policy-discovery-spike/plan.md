---
cycle_id: 20260515-hook-policy-discovery-spike
workflow: architect
phase: discovery-spike
status: approved
created: 2026-05-15
owner: codex
source: "canonical implementation plan for approved Milestone 0.2"
approved_by: alexostl
approved_at: 2026-05-15
---

# Plan: Milestone 0.2 Minimization Path Validation

## Scope

Wdrożyć tylko minimalne wsparcie harnessa potrzebne do wiernego pomiaru trzech
brakujących scenariuszy Discovery Spike:

- `15-cross-repo-fix-intake-capture`
- `16-completed-cycle-explicit-reopen`
- `17-local-gitignored-config-artifact`

Nie zmieniać produkcyjnego `pre-tool-validate.sh` ani docelowej polityki hooków
w tej fazie. Ten plan służy zebraniu evidence dla przyszłej decyzji
architektonicznej, nie wdrożeniu redesignu.

## Implementation Tasks

- [x] Dodać scenariusze `15-17` do RealHarness promptów i `v11-scenarios.json`.
  Done when: `HARNESS_LIST_PROMPTS_ONLY=1` rozwiązuje wszystkie trzy selektory.
  Files: `runtime/platforms/codex/harness/prompts/*`,
  `runtime/platforms/codex/harness/v11-scenarios.json`.

- [x] Dodać minimalne wsparcie harnessa dla realnego cross-repo target repo, jeśli
  scenariusz `15` nie może być wierny samym promptem.
  Done when: prompt może dostać path do drugiego tymczasowego repo i state
  snapshot pozwala sprawdzić zmiany w tym repo.
  Files: `runtime/platforms/codex/harness/run-harness.sh`,
  `runtime/platforms/codex/harness/lib/aggregate-signals.sh`,
  `runtime/platforms/codex/harness/tests/*`.

- [x] Dodać fixture dla completed-cycle reopen, jeśli sam prompt nie tworzy
  wiarygodnego stanu wejściowego.
  Done when: scenariusz `16` startuje z completed manifestem i sprawdza legalny
  reopen/recovery zamiast post-closeout epilogue.
  Files: `runtime/platforms/codex/harness/run-harness.sh`,
  `runtime/platforms/codex/harness/tests/*`.

- [x] Zweryfikować deterministycznie zmiany harnessa.
  Done when: Bats dla harnessa i agregatora przechodzą.
  Files: `runtime/platforms/codex/harness/tests/*`.

- [x] Uruchomić targeted Run 02 `hooks-off` i `hooks-on` dla `15-17`, jeśli
  deterministyczne testy przejdą.
  Done when: powstanie `discovery-spike-run-02-report.md` z tabelą evidence:
  current behavior, target behavior, usability gain, safety risk.
  Files: `.sage/work/20260515-hook-policy-discovery-spike/discovery-spike-run-02-report.md`.

## Minimization Gate

Każdy późniejszy redesign hooków musi mieć:

- `usability_gain`
- `safety_boundary`
- `evidence`
- `fallback`
- `minimality_check`

Bez tego Run 02 nie upoważnia do zmian w produkcyjnym hook predicate.

## First Fix: Local-Only Ignored Artifact

Approval: Alex wybrał `[A] Approve first fix` dla
`minimization-path-architecture-plan.md`.

- [x] Dodać w `pre-tool-validate.sh` wąski allow dla `.sage-local/**`, tylko gdy
  wszystkie claimowane ścieżki są ignorowane przez Git i nie dotykają managed /
  implementation surfaces.
  Done when: `.sage-local/hook-discovery.json` nie wymaga aktywnego cyklu, ale
  source/runtime/test/instruction paths nadal blokują się bez workflow.
  Files: `runtime/platforms/codex/hooks/pre-tool-validate.sh`.

- [x] Dodać deterministyczne testy hooka dla dozwolonego ignored local artifact
  oraz negatywne testy dla braku `.gitignore` i mieszania z managed paths.
  Done when: `pre-tool-validate.bats` przechodzi.
  Files: `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`.

- [x] Uruchomić RealHarness `17` w `hooks-on`.
  Done when: `17-local-gitignored-config-artifact` przechodzi bez
  `.sage/work` manifest bloatu.
  Files: `.sage/work/20260515-hook-policy-discovery-spike/*`.
