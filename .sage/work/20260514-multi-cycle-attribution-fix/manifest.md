---
cycle_id: "20260514-multi-cycle-attribution-fix"
title: "Fix: jawna atrybucja mutacji dotykajacych wielu cykli"
workflow: fix
phase: intake
status: intake
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
needs-triage: true
priority: P1
source: "sage:analyze log review"
suggested_workflow: fix
related:
  - ".sage/.session-mutations.log"
  - ".sage/.skipped-checks.log"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/lib/active_init.sh"
  - ".sage/work/20260509-multi-active-cycle-model-fix/manifest.md"
  - ".sage/work/20260509-cross-cycle-scope-workaround-fix/manifest.md"
scope:
  - ".sage/work/20260514-multi-cycle-attribution-fix/*"
  - ".sage/decisions.md"
---

# Fix: jawna atrybucja mutacji dotykajacych wielu cykli

## State

**Current phase:** intake. Implementacja nie zostala rozpoczeta.

**Next step:** Uruchomic `/sage:fix`, odroznic legalny batch/capture cleanup od
nielegalnego cross-cycle scope bypass i zaprojektowac najmniejszy kontrakt
logowania/blokowania.

## Finding

Logi pokazuja, ze multi-cycle activity jest wystarczajaco czeste, zeby ukryc
bledy:

- sesje dotykaly wiecej niz jednego `cycle_id`;
- wiele cykli bylo dotykanych przez wiecej niz jedna sesje;
- pojedyncze mutation entries potrafily zawierac pliki z kilku
  `.sage/work/<cycle>/` katalogow.

To czasem jest legalne: batch cleanup, folded intake closeout albo capture.
Problem polega na tym, ze `.sage/.session-mutations.log` nie rozroznia tego
semantycznie. Bez jawnego `kind`/klasyfikacji framework nie wie, czy zmiana
jest `batch_metadata_cleanup`, `folded_intake_closeout`,
`cross_cycle_capture`, czy przypadkowym pisaniem poza aktywny cykl.

## Desired Behavior

- Multi-cycle mutation musi miec jawny typ albo zostac zablokowana.
- Legalne batch/capture operacje maja strukturalny slad w logu, a nie tylko
  liste plikow.
- Active-cycle lease i cycle resolver nie moga domyslnie wybierac newest cycle
  bez zapisania structured degraded/selection evidence.
- Cross-cycle implementation mutation bez zatwierdzonego scope pozostaje
  blokowana.

## Candidate Scope

- Dodac albo doprecyzowac mutation kind taxonomy.
- Zrobic structured event dla active_init multi-cycle selection/degraded path.
- Dodac testy dla legalnego folded-intake cleanup i nielegalnego cross-cycle
  implementation patcha.
- Sprawdzic, czy `20260509-multi-active-cycle-model-fix` zamknal tylko czesc
  problemu, czy zostawil luke w log attribution.

## Evidence

- `.sage/.session-mutations.log`
- `.sage/.skipped-checks.log`
- `runtime/platforms/codex/hooks/lib/active_init.sh`
