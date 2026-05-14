---
cycle_id: "20260514-real-harness-targeted-scenarios-fix"
title: "Fix: real harness can run selected scenarios"
workflow: fix
phase: intake
status: intake
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
needs-triage: true
priority: P2
source: "conversation"
suggested_workflow: fix
related:
  - "runtime/platforms/codex/harness/run-harness.sh"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
  - "runtime/platforms/codex/harness/prompts/*.txt"
  - "runtime/platforms/codex/harness/tests/*"
  - ".sage/work/20260510-subagent-self-learning-recall-fix/manifest.md"
scope:
  - ".sage/work/20260514-real-harness-targeted-scenarios-fix/*"
  - ".sage/decisions.md"
---

# Fix: real harness can run selected scenarios

## State

**Current phase:** intake. Implementacja nie została rozpoczęta.

**Next step:** Uruchomić `/sage:fix`, potwierdzić root cause i zaplanować mały
patch dla selektywnego uruchamiania real harnessa.

## Finding

Podczas Batcha 6 okazało się, że real Codex harness jest potrzebny jako evidence
dla klas zachowań typu `memory reuse across sessions`, ale obecny
`runtime/platforms/codex/harness/run-harness.sh` uruchamia wszystkie prompty z
`runtime/platforms/codex/harness/prompts/*.txt`.

To utrudnia tanie, punktowe potwierdzanie jednego albo kilku scenariuszy, np.
`09-memory-correction-reuse`, bez pełnego kosztownego runu harnessa.

## Desired Behavior

Real harness powinien pozwalać uruchomić dowolną liczbę wybranych scenariuszy,
z zachowaniem obecnego full-run defaultu.

Proponowany kontrakt:

- bez parametrów/env vars: uruchom wszystkie scenariusze jak dziś;
- z listą scenariuszy: uruchom tylko wskazane prompty/scenario ids;
- akceptuj stabilne identyfikatory z `v11-scenarios.json`, np.
  `09-memory-correction-reuse`, oraz/lub nazwy promptów bez `.txt`;
- fail fast na nieznanym scenariuszu, pokazując dostępne ids;
- report JSON i `v11_release_blocker_harness` muszą jasno pokazać, że to był
  targeted run i których release-blockerów nie można oceniać z braku runu;
- agregator nie może udawać, że pełny release-blocker harness jest complete,
  jeśli uruchomiono tylko subset.

## Candidate Scope

- `runtime/platforms/codex/harness/run-harness.sh`
- `runtime/platforms/codex/harness/lib/aggregate-signals.sh` jeśli obecny report
  wymaga rozróżnienia full vs targeted run
- `runtime/platforms/codex/harness/tests/*`
- `runtime/platforms/codex/harness/README.md` / runbook docs, jeśli istniejący
  usage wymaga aktualizacji

## Test Ideas

- Deterministic shell/Bats test: selector `09-memory-correction-reuse` wybiera
  dokładnie jeden prompt.
- Deterministic shell/Bats test: selector kilku scenariuszy zachowuje kolejność
  i uruchamia dokładnie te prompty.
- Unknown selector failuje przed startem Codex exec i wypisuje dostępne ids.
- Targeted report nie oznacza full `v11_release_blocker_harness.complete=true`.

## Boundary

Ten intake nie wymaga zmiany samych scenariuszy, promptów ani rubryk
merytorycznych. Chodzi o runner/reporting ergonomics, żeby przyszłe fixy mogły
dostarczyć real-agent evidence punktowo zamiast odpalać cały harness.
