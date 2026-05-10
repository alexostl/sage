---
title: "Plan: RealHarness safe auto-fix audit parser"
status: approved
phase: plan
classification: Moderate
approved_by: "Alex"
approved_at: 2026-05-10
---

# Plan: RealHarness safe auto-fix audit parser

## Scope classification

Moderate. Fix dotyka harness parsera i testow regresyjnych, czyli wchodzi w
test infrastructure. Nie zmienia publicznego API Sage ani runtime hookow.

## Root cause

Parser fallback w `run-harness.sh` nie rozpoznaje realnego Markdownowego formatu
`.sage/.auto-fixes.log`, bo szuka tylko `### ...` albo `kind=...`, a realny log
zapisuje wpisy jako `## 2026-...` plus pola opisowe.

## Files to change

- `runtime/platforms/codex/harness/run-harness.sh`
  - przeniesc `read_json_or_key_value_log` do malej biblioteki i source'owac ja
    z harness runnera;
  - zachowac dotychczasowy runtime contract runnera.
- `runtime/platforms/codex/harness/lib/log-parser.sh`
  - rozszerzyc `read_json_or_key_value_log` tak, zeby rozpoznawal wpisy
    `.sage/.auto-fixes.log` zaczynajace sie od `## ...` i klasyfikowal je jako
    `kind: safe_auto_fix`;
  - zachowac obecne wsparcie dla JSONL i `kind=...`.
- `runtime/platforms/codex/harness/tests/run-harness-log-parser.bats`
  - dodac unit tests parsera dla realnego Markdownowego `.auto-fixes.log`;
  - zachowac regresje dla `kind=...`.
- `runtime/platforms/codex/harness/tests/aggregate-signals.bats`
  - bez zmian funkcjonalnych, uruchomic jako downstream contract test, zeby
    potwierdzic ze agregator nadal wymaga scenario-local `auto_fixes`.

## Tests

1. Najpierw odtworzyc fail na aktualnym parserze na probce realnego logu.
2. Po patchu uruchomic:

```bash
bats runtime/platforms/codex/harness/tests/run-harness-log-parser.bats
bats runtime/platforms/codex/harness/tests/aggregate-signals.bats
```

3. Dla sanity uruchomic `git diff --check`.

## Rollback

Rollback to cofniecie zmian w `run-harness.sh` i nowego testu. Efekt rollbacku:
RealHarness znowu nie bedzie rozpoznawal opisowych safe auto-fix audit entries.
