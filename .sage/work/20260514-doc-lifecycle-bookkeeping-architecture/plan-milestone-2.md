---
title: "Milestone 2 plan: closeout lifecycle i bookkeeping reconciliation"
cycle_id: "20260514-doc-lifecycle-bookkeeping-architecture"
workflow: build
phase: plan
status: completed
created: 2026-05-14
updated: 2026-05-14
approved_at: "2026-05-14"
approved_by: "alexostl"
autonomy_grant: full
related:
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/spec.md"
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/plan.md"
  - ".sage/docs/decision-doc-lifecycle-bookkeeping.md"
  - ".sage/work/20260514-completed-cycle-bookkeeping-reconciliation-fix/manifest.md"
---

# Milestone 2 plan: closeout lifecycle i bookkeeping reconciliation

## Goal

Wdrozyc waski kontrakt dla completed-cycle lifecycle:

- closeout ma zostawiac cykl w spojnym stanie;
- completed cycles pozostaja immutable dla zmian merytorycznych;
- pure bookkeeping reconciliation jest legalne bez manualnego reopen, bez
  follow-up cycle, bez `.sage/decisions.md` entry i bez osobnego audit logu;
- reopen jest wyjatkiem tylko dla natychmiastowej korekty w tej samej aktywnej
  rozmowie.

Mechaniczny kontrakt Milestone 2 to `completed manifest-only reconciliation`:
hook dopuszcza tylko patch dotykajacy dokladnie jednego pliku
`.sage/work/<cycle>/manifest.md`, gdy cykl byl `status: completed` i po patchu
nadal ma `status: completed`. Wszystko inne blokuje. To celowo nie probuje
klasyfikowac intencji ani czytac semantyki manifest body.

Milestone 2 absorbuje intake
`20260514-completed-cycle-bookkeeping-reconciliation-fix`. Ten intake zostanie
po implementacji oznaczony jako folded into obecny architecture cycle.

## Constraints

- Nie tworzymy nowego workflow, migratora ani permanentnego reconciliation
  systemu.
- Nie dopuszczamy post-closeout `.sage` epilogue jako normalnej sciezki.
- Reconciliation nie dotyka `.sage/decisions.md`; decision log policy zostala
  zalatwiona w Milestone 1.
- Nie zmieniamy historycznych faktow: scope, approval meaning, verification
  evidence, implementation result, deliverables ani oceny czy fix byl poprawny.
  To jest zasada workflow/human discipline, nie classifier w hooku.
- Metadata repair/folding nie moze bazowac tylko na podobienstwie starego
  completed cycle. Trzeba respektowac chronologie batchy, session-start state i
  to, czy anchor powstal w tej samej sekwencji pracy.

## Technology decisions

Uzywamy istniejacego stacku: Bash, Bats, `jq`, `yq`, obecne helpers w
`runtime/platforms/codex/hooks/lib/`. Preferowany jest maly helper shellowy,
bo `pre-tool-validate.sh` juz rozstrzyga completed-cycle mutation boundary.

Nie dodajemy parsera natural language dla manifest body. Hook ma egzekwowac
tylko maly mechaniczny invariant: jeden plik, completed cycle, status po patchu
nadal completed.

## Tasks

- [x] **Task 1: Completed-cycle reconciliation tests**
  - **Read first:** `runtime/platforms/codex/hooks/pre-tool-validate.sh`,
    `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`,
    `runtime/platforms/codex/hooks/lib/active_init.sh`,
    `core/constitution/sage-process.constitution.md`.
  - **Files:** `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`.
  - **Action:** Dodac failing tests dla completed-cycle bookkeeping boundary:
    - allow: patch dotykajacy dokladnie jednego pliku
      `.sage/work/<cycle>/manifest.md`, gdy cykl jest completed i po patchu
      nadal ma `status: completed`;
    - allow: stale `phase` -> `phase: completed`, brakujace `closed_at`,
      `resolution`, `folded_into`, stale `Next step` wording, o ile patch
      nadal jest single-file manifest-only;
    - block: completed `manifest.md` zmieniajacy `status: completed` na
      `in-progress`, `paused` albo `intake`;
    - block: patch dotykajacy jakiegokolwiek drugiego pliku, w tym
      `.sage/decisions.md`, `plan.md`, `spec.md`, `root-cause.md`,
      `verification.md`, `qa-report.md`, source/runtime/test files albo drugi
      completed manifest.
  - **Test:** Nowe tests maja failowac przed helperem.
  - **Verify:** `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`
  - **Depends on:** none.

- [x] **Task 2: Closeout/reconciliation policy surface tests**
  - **Read first:** `core/constitution/sage-process.constitution.md`,
    `core/workflows/build.workflow.md`, `core/workflows/fix.workflow.md`,
    `core/workflows/architect.workflow.md`,
    `runtime/platforms/codex/setup/tests/alex-native-core-text.bats`,
    `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`.
  - **Files:** `runtime/platforms/codex/setup/tests/alex-native-core-text.bats`,
    optionally `runtime/platforms/codex/setup/tests/stage3-agents-md.bats` only
    if generated `AGENTS.md` needs existing closeout wording tightened.
  - **Action:** Dodac/zmienic assertions, ktore wymagaja:
    - completed-cycle artifacts are immutable except narrow bookkeeping
      reconciliation;
    - bookkeeping reconciliation does not create `.sage/decisions.md` entries;
    - closeout order keeps `manifest.status: completed` as final lifecycle
      mutation;
    - reopen is same-conversation only; later substantive error becomes
      follow-up cycle; later pure bookkeeping becomes reconciliation.
  - **Test:** Tests maja failowac na brakujacym wording.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - **Depends on:** none.

- [x] **Task 3: Completed-cycle reconciliation helper**
  - **Read first:** Task 1 tests, `runtime/platforms/codex/hooks/pre-tool-validate.sh`,
    `runtime/platforms/codex/hooks/lib/active_init.sh`,
    `runtime/platforms/codex/hooks/lib/artifact_order.sh`.
  - **Files:** `runtime/platforms/codex/hooks/pre-tool-validate.sh`,
    opcjonalnie nowy helper w `runtime/platforms/codex/hooks/lib/`.
  - **Action:** Dodac waska allowlist sciezke w PreToolUse dla
    `completed manifest-only reconciliation`. Minimalny kontrakt:
    - dziala tylko, gdy path resolver wskazuje completed cycle;
    - `claimed_paths` ma dokladnie jeden path:
      `.sage/work/<cycle>/manifest.md`;
    - manifest po patchu nadal ma `status: completed`;
    - kazdy drugi path albo zmiana statusu z completed na inny status blokuje;
    - hook nie analizuje, czy body zmienia approval/verification/result.
      Ograniczamy ryzyko przez single-file manifest-only blast radius i Git
      diff review.
  - **Test:** Task 1 tests.
  - **Verify:** `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`
  - **Depends on:** Task 1.

- [x] **Task 4: Policy wording implementation**
  - **Read first:** Task 2 tests,
    `core/constitution/sage-process.constitution.md`,
    `core/workflows/build.workflow.md`, `core/workflows/fix.workflow.md`,
    `core/workflows/architect.workflow.md`.
  - **Files:** same as read-first source files; `runtime/platforms/codex/setup/lib/agents-md.sh`
    only if Task 2 proves generated router text is part of this surface.
  - **Action:** Dopisac minimalny wording:
    - completed-cycle artifacts immutable except narrow bookkeeping
      reconciliation;
    - bookkeeping-only reconciliation is not decision-worthy;
    - closeout validation should check structural state before final
      `manifest.status: completed`;
    - reopen boundary: same active conversation only.
  - **Test:** Task 2 tests.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - **Depends on:** Task 2.

- [x] **Task 5: Fold absorbed intake**
  - **Read first:** `.sage/work/20260514-completed-cycle-bookkeeping-reconciliation-fix/manifest.md`,
    this plan, main `manifest.md`.
  - **Files:** `.sage/work/20260514-completed-cycle-bookkeeping-reconciliation-fix/manifest.md`,
    `.sage/work/20260514-doc-lifecycle-bookkeeping-architecture/manifest.md`.
  - **Action:** Po implementacji oznaczyc intake jako folded into architecture
    cycle. To jest bookkeeping result, bez `.sage/decisions.md` entry.
    Nie robic tego przed przejsciem tests, zeby nie zamknac intake'u z
    niedostarczonym zakresem.
  - **Test:** N/A; covered by final status/frontmatter sanity.
  - **Verify:** frontmatter shows `status: completed`, `resolution:
    folded_into`, `folded_into:
    20260514-doc-lifecycle-bookkeeping-architecture`.
  - **Depends on:** Tasks 1-4.

- [x] **Task 6: Milestone verification**
  - **Read first:** all changed files.
  - **Files:** no new implementation files unless tests expose a scoped miss.
  - **Action:** Run deterministic suites touched by Tasks 1-5 and `git diff
    --check`. Full RealHarness remains deferred to final cross-milestone
    verification.
  - **Verify:** `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats && git diff --check`
  - **Depends on:** Tasks 1-5.

## Implementation result

Implemented `completed manifest-only reconciliation` jako waski, mechaniczny
wyjatek w `pre-tool-validate.sh`:

- allow tylko dla single-file `apply_patch` na
  `.sage/work/<cycle>/manifest.md` completed cycle;
- block dla reopen status, status removal, drugiego pliku i payloadow bez
  inspectowalnego patch detail;
- policy wording dodany tylko do process/workflow surfaces;
- intake `20260514-completed-cycle-bookkeeping-reconciliation-fix` oznaczony
  jako `folded_into` obecny architecture cycle, bez `.sage/decisions.md` entry.

Verification passed:

```bash
bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats && git diff --check
```

Result: 146 Bats tests passed; `git diff --check` passed.

## Proposed implementation scope

Milestone 2 implementation scope should include:

- `.sage/work/20260514-doc-lifecycle-bookkeeping-architecture/*`
- `.sage/work/20260514-completed-cycle-bookkeeping-reconciliation-fix/manifest.md`
- `core/constitution/sage-process.constitution.md`
- `core/workflows/build.workflow.md`
- `core/workflows/fix.workflow.md`
- `core/workflows/architect.workflow.md`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
- `runtime/platforms/codex/hooks/lib/*`
- `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`
- `runtime/platforms/codex/setup/tests/alex-native-core-text.bats`
- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
- `runtime/platforms/codex/setup/lib/agents-md.sh` only if tests prove the
  generated operating kernel is part of the required surface.

Explicitly out of Milestone 2:

- `.sage/decisions.md` changes for reconciliation itself;
- broad migration of historical `.sage/work`;
- status/work-index implementation;
- Claude Code, Antigravity, generic platform docs;
- RealHarness target selection/pass semantics fixes.

## Stop conditions

- The allowlist would need a semantic/natural-language diff classifier to be
  considered safe. In that case stop instead of adding classifier logic.
- The required implementation touches files outside proposed scope.
- Tests show `pre-tool-validate.sh` is the wrong layer for this exception.
- Existing completed-cycle state conflicts with session-start chronology or
  batch order in a way that would require guessing; hard-stop and ask Alex.

## Checkpoint

This plan needs approval before implementation.

[A] Approve — implement Milestone 2 in this cycle
[R] Revise — adjust scope/tasks
[N] New thread — use this plan as handoff for a fresh implementation thread

Pick A/R/N, or tell me what to change.
