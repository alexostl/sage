---
title: "Milestone 3 plan: live work-index / status formalization"
cycle_id: "20260514-doc-lifecycle-bookkeeping-architecture"
workflow: build
phase: plan
status: completed
created: 2026-05-14
updated: 2026-05-14
approved_at: "2026-05-14"
approved_by: "alexostl"
approval_path: "skip_review"
related:
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/spec.md"
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/plan.md"
  - ".sage/docs/decision-doc-lifecycle-bookkeeping.md"
---

# Milestone 3 plan: live work-index / status formalization

## Goal

Sformalizowac lekki `work_index` dla `sage status --json`, bez tworzenia
nowego pliku indeksu, persistent cache albo duplikatu informacji z manifestow.

Efekt ma byc prosty:

- codzienny status pokazuje active/paused/intake bez czytania pelnych
  artefaktow;
- completed/folded history nie znika, ale nie jest domyslnie wypisywana jako
  dluga lista;
- agent ma stabilny JSON contract dla lifecycle state;
- `recent_decisions` i `health` sa osobnymi warstwami, nie source-of-truth dla
  workflow lifecycle.

## Minimization pass

Nie dodajemy `.sage/work-index.md`, `.sage/index.json`,
`.sage/status-cache.json`, nowej komendy ani nowego generatora cache.

Najmniejsza zmiana to rozbudowac obecne `sage status --json`:

- dodac top-level `work_index`;
- zachowac legacy top-level `cycles`, `decisions`, `health`;
- dodac alias `recent_decisions` dla czytelnego rozdzielenia warstw;
- utrzymac plain text status jako lekki active/parked summary;
- nie listowac completed cycles domyslnie, tylko liczyc je w
  `work_index.counts`.

## Proposed JSON contract

`sage status --json` powinien emitowac:

```json
{
  "work_index": {
    "cycles": [],
    "counts": {
      "by_status": {},
      "by_resolution": {}
    }
  },
  "cycles": [],
  "gates": [],
  "recent_decisions": [],
  "decisions": [],
  "health": {}
}
```

Contract details:

- `work_index.cycles[]` zawiera tylko lifecycle-visible cycles:
  `in-progress`, `paused`, `intake` i legacy aliasy statusu, jesli istnieja.
- `cycles[]` pozostaje backwards-compatible aliasem dla
  `work_index.cycles[]`.
- Completed/folded/rejected cycles nie sa domyslnie wypisywane jako entries,
  ale sa liczone w `work_index.counts.by_status` i
  `work_index.counts.by_resolution`.
- Entry fields sa manifest-frontmatter only:
  `id`, `cycle_id`, `title`, `workflow`, `status`, `phase`, `priority`,
  `owner`, `updated`, `resolution`, `folded_into`, `active_session_id`.
- `recent_decisions[]` to czytelny alias dla legacy `decisions[]`;
  obie tablice maja tylko ostatnie 3 headings/body snippets z current
  `.sage/decisions.md`, bez archive.
- `health` pozostaje diagnostic layer i nie decyduje o lifecycle state.

## Tasks

- [x] **Task 1: Status JSON contract tests**
  - **Read first:** `bin/sage`,
    `runtime/platforms/codex/setup/tests/status.bats`,
    `core/workflows/status.workflow.md`.
  - **Files:** `runtime/platforms/codex/setup/tests/status.bats`.
  - **Action:** Dodac failing tests dla:
    - top-level `work_index.cycles` i `work_index.counts`;
    - backwards-compatible top-level `cycles`, `decisions`, `health`;
    - `recent_decisions` jako alias dla `decisions`;
    - `cycles` == `work_index.cycles`;
    - required lifecycle fields: `cycle_id`, `priority`, `owner`,
      `resolution`, `folded_into`, `active_session_id`;
    - completed/folded cycles liczone w counts, ale nie listowane w default
      cycles;
    - parser ignoruje YAML-like lines w manifest body;
    - `sage status --json` nie czyta `.sage/decisions-archive.md`, raw
      evidence / harness output ani doctor-like source trees jako lifecycle
      state.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/status.bats`
  - **Depends on:** none.

- [x] **Task 2: Implement work_index in `bin/sage status --json`**
  - **Read first:** Task 1 tests, `bin/sage`.
  - **Files:** `bin/sage`.
  - **Action:** Refactor current status extraction minimally:
    - read only manifest frontmatter for lifecycle fields;
    - build `work_index.cycles` from lifecycle-visible statuses;
    - build `work_index.counts.by_status` and `by_resolution` across all
      manifests;
    - preserve legacy `cycles`, `gates`, `decisions`, `health`;
    - add `recent_decisions` alias;
    - keep plain text output focused on active and parked work.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/status.bats`
  - **Depends on:** Task 1.

- [x] **Task 3: Session-start/status lightness regression**
  - **Read first:** `runtime/platforms/codex/hooks/session-init.sh`,
    `runtime/platforms/codex/hooks/tests/session-init.bats`.
  - **Files:** `runtime/platforms/codex/hooks/tests/session-init.bats`,
    `runtime/platforms/codex/hooks/session-init.sh` only if tests expose a
    mismatch.
  - **Action:** Potwierdzic testami, ze SessionStart dalej emituje tylko
    active/paused/intake cycle summary i last 3 current decisions; nie czyta
    `.sage/decisions-archive.md`, completed history ani raw evidence. Nie
    zmieniac `session-init.sh`, jesli obecne zachowanie juz spelnia ten
    kontrakt.
  - **Verify:** `bats runtime/platforms/codex/hooks/tests/session-init.bats`
  - **Depends on:** none.

- [x] **Task 4: Status workflow wording**
  - **Read first:** `core/workflows/status.workflow.md`,
    `core/constitution/sage-process.constitution.md`,
    `runtime/platforms/codex/setup/tests/alex-native-core-text.bats`.
  - **Files:** `core/workflows/status.workflow.md`,
    optionally `core/constitution/sage-process.constitution.md` and
    `runtime/platforms/codex/setup/tests/alex-native-core-text.bats` only if
    the contract needs a generated/core assertion.
  - **Action:** Zmienic stary status workflow contract, a potem dopisac
    minimalny wording:
    - `work_index` is manifest-frontmatter derived;
    - status and session-start are lightweight;
    - completed/folded history is count-only in default status and search-first
      when details are needed, not default context;
    - `recent_decisions` and `health` are context/diagnostic layers, not
      lifecycle source-of-truth.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats`
  - **Depends on:** Task 2.

- [x] **Task 5: Milestone verification**
  - **Read first:** all changed files.
  - **Files:** no new implementation files unless tests expose a scoped miss.
  - **Action:** Run deterministic suites touched by Tasks 1-4 and
    `git diff --check`. Full RealHarness remains deferred to final
    cross-milestone verification.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/status.bats runtime/platforms/codex/hooks/tests/session-init.bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats && git diff --check`
  - **Depends on:** Tasks 1-4.

## Implementation result

Implemented `work_index` as a lightweight layer in existing
`sage status --json`:

- `work_index.cycles[]` is the manifest-frontmatter-derived lifecycle view for
  `in-progress`, `paused`, `intake`, and legacy active aliases;
- legacy `cycles[]` remains equal to `work_index.cycles[]`;
- `work_index.counts.by_status` and `by_resolution` count all manifests,
  including completed/folded/rejected history without listing it by default;
- `recent_decisions[]` is an alias for legacy `decisions[]`;
- `status.workflow.md` now describes completed/folded/rejected history as
  count-only in default status and search-first for details;
- `session-init.sh` was not changed because tests confirmed it already stays
  lightweight.

Verification passed:

```bash
bats runtime/platforms/codex/setup/tests/status.bats runtime/platforms/codex/hooks/tests/session-init.bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats && git diff --check
```

Result: 42 Bats tests passed; `git diff --check` passed.

## Proposed implementation scope

- `.sage/work/20260514-doc-lifecycle-bookkeeping-architecture/*`
- `bin/sage`
- `runtime/platforms/codex/setup/tests/status.bats`
- `runtime/platforms/codex/hooks/tests/session-init.bats`
- `runtime/platforms/codex/hooks/session-init.sh` only if Task 3 tests expose a
  mismatch
- `core/workflows/status.workflow.md`
- `core/constitution/sage-process.constitution.md` only if a compact core
  assertion is needed
- `runtime/platforms/codex/setup/tests/alex-native-core-text.bats` only if a
  compact core assertion is needed

## Explicitly out of Milestone 3

- New persistent index/cache files.
- New CLI command or manual cache refresh step.
- Listing every completed cycle in default status output.
- Reading `.sage/decisions-archive.md` by default.
- Sage Wiki / Sage Memory migration.
- RealHarness target selection/pass semantics fixes.
- One-time migration for `sage-selfhost` and `alex-os-dev`; that is Milestone 4.

## Stop conditions

- The implementation needs a persistent cache or generated file to be correct.
- Backwards-compatible `cycles` / `decisions` JSON cannot be preserved.
- Tests show that default status output would become larger than current
  active/parked summary.
- The work requires reading full manifest bodies, raw evidence, or archive
  decisions for ordinary status.

## Checkpoint

This plan needs approval before implementation.

[A] Subagent review — explicitly authorize Codex to spawn a read-only subagent
to review this milestone plan; findings are shown and you decide
[S] Skip review — approve Milestone 3 without independent review
[I] Revise and Implement in the same turn — give specific bounded revisions and
approve implementation after those changes
[R] Revise — adjust scope/tasks
[N] New session — use this plan as handoff for a fresh implementation thread

Pick A/S/I/R/N, or tell me what to change.
