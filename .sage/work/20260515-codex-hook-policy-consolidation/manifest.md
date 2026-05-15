---
cycle_id: "20260515-codex-hook-policy-consolidation"
title: "Architecture: Codex hook policy consolidation"
workflow: architect
phase: completed
status: completed
created: 2026-05-15
updated: 2026-05-15
owner: alexostl
priority: P0
source: "conversation + subagent reviews"
semantic_reclassification: accepted
implementation_approval:
  mode: approved
  approved_by: alexostl
  approved_at: "2026-05-15"
  gate: discovery-spike
  artifact: ".sage/work/20260515-codex-hook-policy-consolidation/plan.md"
  scope: manifest
milestone_0_approval:
  mode: approved
  approved_by: alexostl
  approved_at: "2026-05-15"
  artifact: ".sage/work/20260515-codex-hook-policy-consolidation/plan-milestone-0-discovery-spike.md"
scope:
  - ".sage/work/20260515-codex-hook-policy-consolidation/*"
  - ".sage/docs/decision-codex-hook-policy-consolidation.md"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/harness/run-harness.sh"
  - "runtime/platforms/codex/harness/lib/log-parser.sh"
  - "runtime/platforms/codex/harness/lib/aggregate-signals.sh"
  - "runtime/platforms/codex/harness/tests/run-harness.bats"
  - "runtime/platforms/codex/harness/tests/run-harness-log-parser.bats"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
  - "runtime/platforms/codex/harness/README.md"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
related:
  - "20260514-codex-runtime-alignment-fix"
  - "20260514-surgical-wording-hook-threshold-fix"
  - "20260514-source-mutating-cycle-concurrency-fix"
  - "20260514-multi-cycle-attribution-fix"
  - "20260514-framework-log-schema-observability-fix"
  - "20260510-codex-worktree-support-build"
  - "20260514-same-turn-deliver-approval-guard-fix"
  - "20260514-completed-cycle-bookkeeping-reconciliation-fix"
  - "20260514-selfhost-sage-update-pass"
  - "codex://threads/019e2874-24cc-72f3-b333-31d9a213ab7c"
  - "codex://threads/019e095f-5328-7e40-a288-0a524d6e0d0d"
  - "codex://threads/019e25b2-3a20-7ad3-ac90-bf4ded52b907"
---

# Architecture: Codex hook policy consolidation

## State

**Current phase:** completed. Alex zatwierdził kierunek Milestone 0,
implementacja prerequisite patcha RealHarness została wykonana, a targeted
RealHarness dla naprawianych scenariuszy przeszedł.

**Next step:** Targeted RealHarness dla `08-safe-autofix-metadata` i
`13-mutation-preflight-lightweight` jest zielony (`present=2`, `missing=[]`).
Alex jawnie zdecydował, że w tym wątku nie uruchamiamy pełnego RealHarness;
pełny run pozostaje deferred i nie blokuje zamknięcia tego cyklu.

**Discovery execution finding:** RealHarness jest właściwą bazą, ale przed
realnym runem potrzebuje małego patcha infrastrukturalnego: selector scenariuszy,
izolowany `CODEX_HOME`, brak domyślnego `fast` oraz izolowany tryb
`HARNESS_HOOK_MODE=on|off`. Audit-only powinien zostać osobną decyzją po
pierwszym porównaniu hooks-on/off, bo może wymagać dotknięcia produkcyjnego
hooka. Final verification cyklu doc lifecycle dodatkowo ujawnił, że parser
`.auto-fixes.log` nie obsługuje realnego bracket/key-value formatu, a rubryka
`13-mutation-preflight-lightweight` zbyt sztywno wymaga nowego manifestu mimo
bezpiecznego stopu przy aktywnym `plan-gate`.

**Implementation approval:** Alex wybrał `[S] Skip review` dla canonical
`plan.md`. Implementacja jest ograniczona do RealHarness runnera, agregatora,
testów Bats i README. Produkcyjny `pre-tool-validate.sh` pozostaje poza scope.

**Semantic reclassification:** Zaakceptowane dla zaplanowanych zmian w testach,
README i runtime harness files. To nie rozszerza scope na produkcyjny hook.

**Smoke evidence:** Pierwszy targeted RealHarness smoke (`11-bug-report-no-fix`)
przeszedł w `hooks-off` i `hooks-on`. Różnica jest architektonicznie istotna:
bez hooków agent zapisał capture-only intake bez implementacji, z hookami
capture został zablokowany i agent poprosił o wejście w `sage:fix`. Szczegóły są
w `discovery-spike-report.md`.

**Closeout:** Cykl został zamknięty po deterministic verification `31/31`,
targeted RealHarness `present=2`, `missing=[]` dla `08` i `13`, oraz decyzji
Alexa, że pełny RealHarness nie jest wykonywany w tym wątku. Zmiany są gotowe
do commita i push na branch `selfhost`.

## Boundary

Ten cykl na starcie nie zmienia hooków, runtime, generatorów ani testów.
Pierwszy deliverable to architektoniczny kontrakt: taksonomia mutacji, ownership
model, decision matrix i plan małych milestone'ów.

Po korekcie Alexa z 2026-05-15 pierwszy krok nie jest jeszcze designem. Najpierw
potrzebny jest Discovery Spike, żeby architektura opierała się na porównawczym
evidence, a nie tylko na analizie incydentów.
