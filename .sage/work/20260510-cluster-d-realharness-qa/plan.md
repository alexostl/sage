---
cycle_id: "20260510-cluster-d-realharness-qa"
artifact: plan
status: approved
created: 2026-05-10
updated: 2026-05-10
---

# Plan - RealHarness QA rerun

## Cel

Uruchomić RealHarnessTests dla klastra D na `gpt-5.4`, reasoning `low`, bez
parametru `service_tier`.

## Zakres zmian pomocniczych

- Użyć tymczasowego wrappera pod
  `/Users/alexostl/tmp/cluster-d-realharness-20260510-133609-default-tier/`.
- Wrapper nie jest zmianą runtime repo; służy tylko do odpalenia QA.
- Wrapper ma:
  - wskazywać `HARNESS_DIR` i `FRAMEWORK_ROOT` na aktywny worktree `75f2`;
  - usunąć `--ignore-user-config`, żeby nie wyłączać hook-aware routing;
  - ustawić izolowany `CODEX_HOME`, żeby nie odziedziczyć globalnego parametru
    `service_tier`;
  - dodać target trust override;
  - nie przekazywać żadnego `service_tier`.

## Raport

Wynik zapisać w `.sage/work/20260510-cluster-d-realharness-qa/qa-report.md`.
