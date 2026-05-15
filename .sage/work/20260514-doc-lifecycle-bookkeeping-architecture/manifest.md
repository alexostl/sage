---
cycle_id: "20260514-doc-lifecycle-bookkeeping-architecture"
title: "Architecture: lifecycle, decisions i bookkeeping bez token bloat"
workflow: architect
phase: completed
status: completed
created: 2026-05-14
updated: 2026-05-15
owner: alexostl
priority: P1
semantic_reclassification: accepted
source: "sage:analyze follow-up conversation"
scope:
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/*"
  - ".sage/docs/decision-doc-lifecycle-bookkeeping.md"
  - "AGENTS.md"
  - ".sage/decisions.md"
  - ".sage/decisions-archive.md"
  - "core/constitution/sage-process.constitution.md"
  - "core/workflows/build.workflow.md"
  - "core/workflows/fix.workflow.md"
  - "core/workflows/architect.workflow.md"
  - "core/workflows/analyze.workflow.md"
  - "core/workflows/review.workflow.md"
  - "core/capabilities/orchestration/build-loop/SKILL.md"
  - "core/capabilities/orchestration/sage-navigator/SKILL.md"
  - "core/capabilities/review/auto-review/SKILL.md"
  - "core/capabilities/review/auto-qa/SKILL.md"
  - ".sage/work/20260514-completed-cycle-bookkeeping-reconciliation-fix/manifest.md"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "runtime/platforms/codex/setup/tests/alex-native-core-text.bats"
  - "runtime/platforms/codex/setup/tests/subagent-review-policy.bats"
  - "runtime/platforms/codex/hooks/post-tool-check.sh"
  - "runtime/platforms/codex/hooks/lib/*"
  - "runtime/platforms/codex/hooks/tests/post-tool-check.bats"
  - "bin/sage"
  - "runtime/platforms/codex/setup/tests/status.bats"
  - "runtime/platforms/codex/hooks/tests/session-init.bats"
  - "core/workflows/status.workflow.md"
  - "runtime/platforms/codex/harness/README.md"
  - "runtime/platforms/codex/harness/run-harness.sh"
  - "runtime/platforms/codex/harness/lib/log-parser.sh"
  - "runtime/platforms/codex/harness/lib/aggregate-signals.sh"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
  - "runtime/platforms/codex/harness/tests/run-harness-log-parser.bats"
  - "runtime/platforms/codex/harness/tests/run-harness.bats"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
autonomy_grant:
  mode: full
  approved_by: alexostl
  approved_at: "2026-05-14"
  plan: ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/plan-milestone-3.md"
  boundary: "Milestone 3 only; implement live work-index/status formalization. Stop on persistent cache/index requirement, compatibility break for cycles/decisions JSON, default status bloat, or ordinary status requiring full manifest bodies/raw evidence/archive decisions."
milestone_4_autonomy_grant:
  mode: full
  approved_by: alexostl
  approved_at: "2026-05-15"
  plan: ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/plan-milestone-4.md"
  boundary: "Milestone 4 only; implement sage-selfhost migration/check and alex-os-dev read-only handoff. Stop on any mutation needed under /Users/alexostl/Developer/alex-os-dev/**, user-territory overwrite risk, generic migrator requirement, or edits outside sage-selfhost scope."
---

# Architecture: lifecycle, decisions i bookkeeping bez token bloat

## State

**Current phase:** completed. Brief, architecture design, high-level
milestone plan, `plan-milestone-1.md` i `plan-milestone-2.md` zostaly
zaakceptowane przez Alexa. Milestone 2 implementation i deterministic
verification sa completed. P0 fix
`20260514-same-turn-deliver-approval-guard-fix` jest zamkniety, wiec cykl
wszedl w implementacje Milestone 3. Milestone 3 implementation i deterministic
verification sa completed. Alex wybral `C`, wiec cykl przeszedl do planowania
Milestone 4. Milestone 4 zostal zatwierdzony po Superagent Review,
zaimplementowany i zweryfikowany. Alex poprosil o przejscie do final
RealHarness verification. Pelny RealHarness zostal uruchomiony i jest czerwony:
`v11_release_blocker_harness.complete=false`, `present=10`, `total=12`. Wynik
zapisano w `realharness-final-report.md`. Dwa czerwone scenariusze zostaly
naprawione w cyklu `20260515-codex-hook-policy-consolidation`; targeted
RealHarness dla `08-safe-autofix-metadata` i `13-mutation-preflight-lightweight`
przeszedl (`present=2`, `missing=[]`).

**Next step:** Brak pracy w tym watku. Alex jawnie zdecydowal, ze pelny
RealHarness nie bedzie odpalany teraz; full run pozostaje deferred i nie
blokuje zamkniecia cyklu.

## Problem

Sage SelfHost miesza w `.sage` kilka rodzajow wiedzy: aktywny workflow state,
audit trail decyzji, process log checkpointow, bogate manifesty, long-form docs
i raw evidence. Efekt jest taki, ze prosty status moze przerodzic sie w
czytanie duzych fragmentow `.sage/work` i `.sage/decisions.md`.

## Key Direction

- Manifest pozostaje source-of-truth dla state.
- `sage status --json` / live scan manifestow ma zostac sformalizowany jako
  lekki work-index, bez nowego rownoleglego dokumentu.
- `.sage/decisions.md` ma byc decision logiem, nie process logiem.
- Completed-cycle bookkeeping reconciliation jest legalne bez follow-up cycle,
  jesli nie zmienia faktow historycznych.
- Reopen jest dozwolone tylko natychmiastowo w tej samej aktywnej rozmowie.
- Closeout path ma walidowac spojny state przed oznaczeniem cycle jako
  completed.

## Out Of Scope

- Sage Wiki / alex-os migration.
- `summary.md` dla cykli.
- Duza migracja raw evidence/log archive.
- `sage doctor` lub `sage status` warnings jako primary UX dla consistency.
