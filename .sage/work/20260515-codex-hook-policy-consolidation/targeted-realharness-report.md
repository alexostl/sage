---
cycle_id: "20260515-codex-hook-policy-consolidation"
title: "Targeted RealHarness report for 08 and 13"
workflow: qa
status: completed
created: 2026-05-15
source: "runtime/platforms/codex/harness/run-harness.sh"
---

# Targeted RealHarness report for `08` and `13`

## Verdict

**PASS for targeted blockers.**

Po poprawkach uruchomiono RealHarness tylko dla scenariuszy, ktore padly w
poprzednim full run:

- `08-safe-autofix-metadata`
- `13-mutation-preflight-lightweight`

Wynik targeted gate:

```text
v11_release_blocker_harness.total=2
v11_release_blocker_harness.present=2
v11_release_blocker_harness.missing=[]
v11_release_blocker_harness.run_mode=targeted
v11_release_blocker_harness.complete=false
```

`complete=false` jest oczekiwane, bo targeted run nie udaje pelnego release
gate. Oznacza to: dwa naprawiane scenariusze przeszly, ale caly v1.1 gate nadal
wymaga osobnego full RealHarness.

Output:

```text
/tmp/sage-doc-lifecycle-realharness-targeted-20260515053218
```

Report:

```text
/tmp/sage-doc-lifecycle-realharness-targeted-20260515053218/report.json
```

## Deterministic verification

```text
bats runtime/platforms/codex/harness/tests/run-harness-log-parser.bats runtime/platforms/codex/harness/tests/run-harness.bats runtime/platforms/codex/harness/tests/aggregate-signals.bats
1..31
ok 1-31
```

Also passed:

```text
bash -n runtime/platforms/codex/harness/run-harness.sh
bash -n runtime/platforms/codex/harness/lib/aggregate-signals.sh
```

## What changed

- `log-parser.sh` rozpoznaje teraz realne formaty `.sage/.auto-fixes.log`:
  JSONL, markdown headings, bracket/key-value heading oraz bullet log pod
  `# Auto Fixes`.
- `HARNESS_SCENARIOS` obsluguje scenario `id`, prompt basename i prompt
  filename, rozdzielane przecinkiem albo whitespace.
- `aggregate-signals.sh` filtruje `v11_release_blocker_harness` i Signal 8 do
  wybranych scenariuszy, gdy `HARNESS_SCENARIOS` jest ustawione.
- Scenariusz `13` nadal blokuje `bypass_mutation` i source/runtime/tests
  mutation, ale nie failuje od samego `unclaimed_change` na bookkeeping
  manifestach.

## Remaining work

Pelny RealHarness nadal powinien zostac uruchomiony przed finalnym green
closeoutem calego release gate.
