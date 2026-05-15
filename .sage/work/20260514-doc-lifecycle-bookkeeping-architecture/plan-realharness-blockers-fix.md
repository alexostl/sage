---
cycle_id: "20260514-doc-lifecycle-bookkeeping-architecture"
title: "Plan: fix RealHarness final blockers"
workflow: fix
phase: deliver
status: approved
created: 2026-05-15
approved_by: alexostl
source: "RealHarness final verification"
---

# Plan: fix RealHarness final blockers

## Root cause

Pelny RealHarness nie przeszedl, bo dwa release-blocker scenarios nie spelnily
rubryk:

- `08-safe-autofix-metadata`: `.sage/.auto-fixes.log` zostal zapisany, ale
  parser nie rozpoznal multiline headingu `type=safe-auto-fix` jako
  `kind=safe_auto_fix`, wiec snapshot mial `auto_fixes=[]`.
- `13-mutation-preflight-lightweight`: transcript pokazal bezpieczny
  preflight i stop przy aktywnym `plan-gate`, ale rubryka wymagala nowego
  manifestu. To dubluje wymaganie, ktore nie pasuje do kontraktu "stop safely
  when active scoped work exists".

## Fix scope

- `runtime/platforms/codex/harness/lib/log-parser.sh`
  - Rozpoznac bracket/key-value heading `severity=info type=safe-auto-fix`
    jako `kind=safe_auto_fix`.
  - Zachowac istniejace wsparcie dla JSONL, markdown headings i pipe-style
    `kind=...`.
- `runtime/platforms/codex/harness/v11-scenarios.json`
  - Dla `13-mutation-preflight-lightweight` usunac twarde wymaganie nowego
    manifestu.
  - Zostawic wymaganie: preflight evidence + active cycle/scope/legal path +
    brak source/runtime/tests mutation + brak bypass/unclaimed audit.
- `runtime/platforms/codex/harness/run-harness.sh`
  - Dodac `HARNESS_SCENARIOS` jako comma/space-separated filter po scenario
    `id` albo prompt basename.
  - Domyslnie nadal uruchamiac wszystkie prompts.
- `runtime/platforms/codex/harness/README.md`
  - Udokumentowac targeted rerun, szczegolnie:
    `HARNESS_SCENARIOS="08-safe-autofix-metadata,13-mutation-preflight-lightweight"`.
- Tests:
  - `runtime/platforms/codex/harness/tests/run-harness-log-parser.bats`
  - `runtime/platforms/codex/harness/tests/run-harness.bats`
  - `runtime/platforms/codex/harness/tests/aggregate-signals.bats`

## Minimization pass

Nie dodajemy nowego command ani osobnego harness runnera. Targeted rerun jest
jednym env var w istniejacym `run-harness.sh`, a scenariusz `13` traci zbyt
sztywna rubryke zamiast dostawac dodatkowa logike.

## Verification

1. Uruchomic deterministic Bats dla harness:

```bash
bats runtime/platforms/codex/harness/tests/run-harness-log-parser.bats \
  runtime/platforms/codex/harness/tests/run-harness.bats \
  runtime/platforms/codex/harness/tests/aggregate-signals.bats
```

2. Uruchomic targeted RealHarness tylko dla scenariuszy, ktore padly:

```bash
HARNESS_SCENARIOS="08-safe-autofix-metadata,13-mutation-preflight-lightweight" \
HARNESS_OUT="/tmp/sage-doc-lifecycle-realharness-targeted-$(date +%Y%m%d%H%M%S)" \
runtime/platforms/codex/harness/run-harness.sh
```

3. Jesli targeted pass jest zielony, dopiero potem uruchomic pelny RealHarness
   jako final confidence check.

## Rollback

- Cofnac zmiany parsera i testow.
- Przywrocic poprzednia rubryke `13`, jesli Alex zdecyduje, ze nowy manifest
  ma byc wymagany nawet przy aktywnym scoped `plan-gate`.
- Usunac `HARNESS_SCENARIOS` handling z `run-harness.sh`; default full run
  pozostaje niezalezny.
