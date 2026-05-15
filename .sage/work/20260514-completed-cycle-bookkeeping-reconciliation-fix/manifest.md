---
cycle_id: "20260514-completed-cycle-bookkeeping-reconciliation-fix"
title: "Fix: completed-cycle bookkeeping reconciliation without manual reopen"
workflow: fix
phase: completed
status: completed
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
priority: P2
source: "conversation"
suggested_workflow: fix
resolution: folded_into
folded_into: "20260514-doc-lifecycle-bookkeeping-architecture"
closed_at: "2026-05-14"
related:
  - "core/constitution/sage-process.constitution.md"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - ".sage/work/20260510-language-invariant-workflow-matching-fix/manifest.md"
  - ".sage/work/20260510-subagent-self-learning-recall-fix/manifest.md"
  - ".sage/work/20260510-subagent-review-approval-boundary-fix/manifest.md"
scope:
  - ".sage/work/20260514-completed-cycle-bookkeeping-reconciliation-fix/*"
  - ".sage/decisions.md"
  - "core/constitution/sage-process.constitution.md"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
---

# Fix: completed-cycle bookkeeping reconciliation without manual reopen

## State

**Current phase:** completed. Ten intake został wchłonięty do
`20260514-doc-lifecycle-bookkeeping-architecture` jako Milestone 2.

**Next step:** Brak osobnego follow-up cycle. Implementacja i weryfikacja ida
przez główny architecture cycle.

## Finding

Batch 5 i Batch 6 zostały zaakceptowane, zacommitowane i wypchnięte, ale część
artefaktów `.sage/work/*/manifest.md` została z niespójnym bookkeeping:

- Batch 5 anchor ma `status: completed`, ale body nadal mówiło, że czeka na
  completion checkpoint.
- Batch 6 anchor ma `status: completed`, ale `phase: verify` i stale
  "Next step: Commit and push".
- Batch 6 sibling intake `20260510-subagent-review-approval-boundary-fix`
  został merytorycznie zaadresowany, ale nadal widnieje jako intake.

Obecny hook słusznie blokuje mutacje completed cycles, ale robi to zbyt
zero-jedynkowo: blokuje także wąską korektę metadanych/status wording, która
nie zmienia scope, deliverables, verification, implementation ani faktów
historycznych.

## Desired behavior

- Completed-cycle artifacts pozostają immutable po closeoucie.
- Wyjątek dotyczy wyłącznie narrow bookkeeping reconciliation.
- Constitution rule ma być po angielsku, bo `core/constitution` jest po
  angielsku.
- Wyjątek nie trafia do generated `AGENTS.md`; to mechaniczna polityka hooka,
  nie nowa instrukcja dla agenta.
- PreToolUse może dopuścić taki patch bez ręcznego reopen approval w rozmowie,
  jeśli struktura patcha jednoznacznie pokazuje bookkeeping-only.

## Candidate scope

- `core/constitution/sage-process.constitution.md`
  - Dodać krótką globalną zasadę po angielsku:
    completed-cycle artifacts are immutable except narrow bookkeeping
    reconciliation that does not change scope, deliverables, verification
    evidence, implementation, approval meaning, or historical facts.
- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
  - Dodać mały helper typu `is_completed_cycle_bookkeeping_patch`.
  - Allow tylko dla `manifest.md` completed cycle oraz opcjonalnie
    `.sage/decisions.md`.
  - Block, jeśli patch dotyka code/runtime/tests/workflow deliverables,
    `plan.md`, `root-cause.md`, `verification.md`, `qa-report.md` albo zmienia
    `status: completed` na inny status.
- `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`
  - Regression allow: stale completed manifest bookkeeping + decisions.
  - Regression block: completed manifest + runtime/code.
  - Regression block: completed manifest status reopened to `in-progress`.
  - Regression block: completed cycle `plan.md`, `root-cause.md`,
    `verification.md` albo `qa-report.md`.

## Boundary

Nie dodawać tego do `AGENTS.md` ani generated instruction surfaces. Nie zmieniać
znaczenia closeoutu. Nie dopuszczać post-closeout epilogów, nowych findings,
nowej weryfikacji ani zmian implementacyjnych w zamkniętym cyklu.
