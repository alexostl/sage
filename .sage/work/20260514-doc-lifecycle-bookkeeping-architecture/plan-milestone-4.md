---
title: "Milestone 4 plan: one-time migration for sage-selfhost and alex-os-dev"
cycle_id: "20260514-doc-lifecycle-bookkeeping-architecture"
workflow: build
phase: plan
status: completed
created: 2026-05-14
updated: 2026-05-15
approved_at: "2026-05-15"
approved_by: "alexostl"
approval_path: "skip_review_after_superagent_review"
related:
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/spec.md"
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/plan.md"
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/plan-milestone-1.md"
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/plan-milestone-2.md"
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/plan-milestone-3.md"
---

# Milestone 4 plan: one-time migration for sage-selfhost and alex-os-dev

## Goal

Wykonac jednorazowe doprowadzenie realnych repo Alexa do kontraktu po
Milestone 1-3, ale z zachowaniem target repo ownership:

- w tym cyklu i w tym repo implementujemy tylko `sage-selfhost` migration/check;
- dla `/Users/alexostl/Developer/alex-os-dev` przygotowujemy handoff/checklist,
  a wlasciwa migracja idzie w osobnej sesji z cwd ustawionym na
  `/Users/alexostl/Developer/alex-os-dev`.

To nie jest nowy framework upgrade path, migrator, helper ani komenda. To
kontrolowany one-time job, ale bez cross-repo writes z poziomu
`sage-selfhost`.

## Minimization pass

Nie budujemy uniwersalnego mechanizmu migracji starych repo. Najmniejsza
bezpieczna sciezka:

- w `sage-selfhost` zweryfikowac, ze zmiany Milestone 1-3 sa juz w working tree
  i generowane surfaces/testy widza nowy kontrakt;
- dla `alex-os-dev` nie wykonywac mutacji z tego repo. Zamiast tego zapisac
  minimalny handoff: co sprawdzic, jakie komendy uruchomic i jakie stop
  conditions obowiazuja w osobnej sesji;
- nie ruszac business/personal Google Drive projects.

## Tasks

- [x] **Task 1: Preflight inventory and ownership boundary**
  - **Read first:** current plan, `AGENTS.md` in both repos if present,
    `bin/sage`, `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`,
    alex-os source-of-truth instructions in `/Users/alexostl/Developer/alex-os-dev/AGENTS.md`
    or equivalent repo docs.
  - **Files:** no edits.
  - **Action:** Gather minimal inventory:
    - git status of `sage-selfhost` and `alex-os-dev`;
    - whether each repo has `AGENTS.md`, `.sage/`, `.codex/hooks`;
    - whether `AGENTS.md` managed prefix contains Milestone 1-3 contracts:
      decision log/archive read policy, completed reconciliation, lightweight
      status/work-index wording;
    - whether user territory below `SAGE-MANAGED-END` exists and must be
      preserved;
    - confirm that `alex-os-dev` writes are out of scope for this current
      `sage-selfhost` cycle and require a separate target-repo session.
  - **Verify:** written checkpoint note in this plan or implementation result;
    no file mutation.
  - **Depends on:** none.

- [x] **Task 2: sage-selfhost migration check**
  - **Read first:** `AGENTS.md`, `.sage/decisions.md`,
    `.sage/decisions-archive.md` if present, `bin/sage`,
    changed Milestone 1-3 files.
  - **Files:** only `sage-selfhost` repo files already in approved scope unless
    preflight shows a missing generated surface.
  - **Action:** Ensure `sage-selfhost` itself has:
    - bounded current decision log behavior from Milestone 1;
    - completed manifest-only reconciliation contract from Milestone 2;
    - `sage status --json` `work_index` contract from Milestone 3;
    - generated `AGENTS.md` current enough for these policies where expected.
  - **Verify:** targeted deterministic tests, `sage status --json` sample, and
    `git diff --check`.
  - **Depends on:** Task 1.

- [x] **Task 3: alex-os-dev handoff for separate target-repo session**
  - **Read first:** `/Users/alexostl/Developer/alex-os-dev/AGENTS.md`,
    alex-os source-of-truth config docs, and any Sage-managed generated
    sections in that repo.
  - **Files:** current cycle artifact only, preferably this plan result or a
    short handoff section/file under
    `.sage/work/20260514-doc-lifecycle-bookkeeping-architecture/`.
  - **Action:** Prepare a handoff for the future `alex-os-dev` session:
    - short summary of Milestone 1-3 contracts:
      decision log/archive read policy, completed manifest-only
      reconciliation, and lightweight `work_index` status;
    - target cwd: `/Users/alexostl/Developer/alex-os-dev`;
    - do not edit installed `~/.codex/*` or `~/.claude/*` directly;
    - preserve user territory below managed markers;
    - if config deployment is needed, edit alex-os source-of-truth first and
      use existing sync/update path;
    - include read-only inventory results from this cycle;
    - include a concrete start checklist for the new thread: set cwd, inspect
      `AGENTS.md`, inspect `.sage` state, run targeted `sage status --json`,
      inspect relevant alex-os config source-of-truth, then decide whether
      updates are needed;
    - stop conditions: ambiguous ownership, unmanaged config drift, user
      territory overwrite risk, any proposed write outside
      `/Users/alexostl/Developer/alex-os-dev`, or need for a general migrator.
  - **Verify:** handoff is self-contained enough to start a separate
    `alex-os-dev` migration thread without reading this whole cycle.
  - **Depends on:** Task 1.

- [x] **Task 4: Selfhost status smoke and alex-os-dev read-only sanity**
  - **Read first:** outputs from Tasks 2-3.
  - **Files:** no edits unless a smoke exposes a scoped miss.
  - **Action:** Run targeted checks:
    - in `sage-selfhost`, `sage status --json` should expose `work_index`;
    - active/paused/intake work should be readable without archive/raw evidence;
    - completed/folded history should be count/search-first, not default list;
    - in `alex-os-dev`, read-only sanity is allowed, but no writes from this
      cycle.
  - **Verify:** paste exact command output summary into this plan result or
    closeout; any `alex-os-dev` mutation remains deferred to the separate
    target-repo session.
  - **Depends on:** Tasks 2-3.

- [x] **Task 5: Milestone verification**
  - **Read first:** all changed files in both repos.
  - **Files:** no new files unless Tasks 2-3 require scoped corrections.
  - **Action:** Run deterministic suites affected in `sage-selfhost`,
    selfhost `git diff --check`, and read-only `alex-os-dev` handoff sanity.
    Do not mutate `alex-os-dev` here.
  - **Verify:** command output with exact pass/fail summary.
  - **Depends on:** Tasks 1-4.

## Implementation result

### Preflight inventory

`sage-selfhost`:

- `AGENTS.md`: present.
- `.sage/`: present.
- `.codex/hooks`: present.
- `.sage/decisions-archive.md`: absent before migration, created by rotation.
- Git checkout: primary checkout
  (`git-dir == git-common-dir`), so archive rotation is allowed.
- Current decisions before rotation: 421 entries.

`alex-os-dev` read-only inventory:

- `AGENTS.md`: present.
- `.sage/`: present.
- `.codex/hooks`: present.
- `.sage/decisions-archive.md`: absent.
- Git status had existing untracked paths:
  `.sage/work/20260514-sagewiki-watcher-stability/` and `var/`.
- Managed `AGENTS.md` still has older decision wording; actual migration is
  deferred to a separate target-repo session.

### sage-selfhost result

- Rotated `.sage/decisions.md` with existing
  `decisions_rotate_if_needed` helper.
- Current `.sage/decisions.md`: 50 entries.
- `.sage/decisions-archive.md`: 371 entries, newest-first after archive header.
- `sage status --json` exposes `work_index`.
- `AGENTS.md` has compact decision/archive policy. Completed reconciliation and
  work-index details intentionally remain in workflow/runtime surfaces, not in
  extra always-loaded `AGENTS.md` prose.

Selfhost status smoke:

```json
{"has_work_index":true,"visible_cycles":18,"current_decisions":3,"completed_count":85}
```

### alex-os-dev handoff

Open a separate session with:

```bash
cd /Users/alexostl/Developer/alex-os-dev
```

Milestone 1-3 contracts to check there:

- `.sage/decisions.md` is a decision log, not a process log.
- Current decisions should be bounded to 50 in primary checkout; overflow goes
  to `.sage/decisions-archive.md`, newest-first.
- Archive reads are search-first: use `rg`, then read fragments.
- Completed-cycle bookkeeping uses narrow `completed manifest-only
  reconciliation`.
- `sage status --json` should expose lightweight `work_index`; completed/folded
  history should be counts/search-first, not default context.

Start checklist for the future `alex-os-dev` thread:

1. Set target repo/cwd to `/Users/alexostl/Developer/alex-os-dev`.
2. Read that repo's `AGENTS.md` and preserve everything below
   `SAGE-MANAGED-END`.
3. Inspect `.sage/` state and current `git status`.
4. Run targeted `sage status --json` and check for `work_index`.
5. Inspect alex-os source-of-truth config before any deployed config changes.
6. If config deployment is needed, edit alex-os source-of-truth first and use
   the existing sync/update path.
7. Do not edit installed `~/.codex/*` or `~/.claude/*` directly.

Stop in the future `alex-os-dev` thread if ownership is ambiguous, user
territory would be overwritten, unmanaged config drift appears, the work needs
a general migrator, or a proposed write escapes
`/Users/alexostl/Developer/alex-os-dev`.

Read-only smoke from this cycle using the current selfhost `bin/sage`:

```json
{"has_work_index":true,"visible_cycles":4,"current_decisions":3,"counts":{"complete":4,"completed":36,"paused":1,"intake":2,"in-progress":1}}
```

### Verification

Final Milestone 4 verification passed:

```bash
bats runtime/platforms/codex/hooks/tests/post-tool-check.bats runtime/platforms/codex/setup/tests/status.bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats && git diff --check && printf 'current_decisions=' && rg -c '^### ' .sage/decisions.md && printf 'archive_decisions=' && rg -c '^### ' .sage/decisions-archive.md
```

Result:

- 96 Bats tests passed.
- `git diff --check` passed.
- `current_decisions=50`.
- `archive_decisions=371`.

## Proposed implementation scope

Selfhost:

- `.sage/work/20260514-doc-lifecycle-bookkeeping-architecture/*`
- `AGENTS.md` only if generated prefix is stale and update path changes it
- `.sage/decisions.md`
- `.sage/decisions-archive.md`
- `bin/sage`
- `runtime/platforms/codex/setup/lib/agents-md.sh`
- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
- `runtime/platforms/codex/setup/tests/status.bats`
- `runtime/platforms/codex/hooks/tests/session-init.bats`
- `core/constitution/sage-process.constitution.md`
- `core/workflows/status.workflow.md`

Alex-os-dev:

- no write scope in this `sage-selfhost` cycle;
- read-only inspection only for inventory/handoff;
- actual writes must happen in a separate session whose cwd/target repo is
  `/Users/alexostl/Developer/alex-os-dev`.

## Explicitly out of Milestone 4

- A generic migration command/helper/framework.
- Editing installed `~/.codex/*`, `~/.claude/*`, or global symlinks directly.
- Editing `/Users/alexostl/Developer/alex-os-dev/**` from this
  `sage-selfhost` cycle.
- Migrating all old Sage projects.
- Business/personal Google Drive project docs.
- Sage Wiki / Sage Memory content migration.
- Full RealHarness; final cross-milestone RealHarness remains after this
  migration milestone.

## Stop conditions

- `sage update` or any existing update path would overwrite user territory.
- `alex-os-dev` source-of-truth ownership is ambiguous.
- Required edits escape `sage-selfhost` during this cycle.
- Any mutation under `/Users/alexostl/Developer/alex-os-dev/**` is needed; stop
  and start a separate target-repo session instead.
- The migration would require a reusable migrator or new permanent command.
- `sage status --json` is missing `work_index` in `sage-selfhost` for a reason
  that cannot be fixed by existing source-of-truth/update paths.

## Checkpoint

This plan needs approval before implementation.

[A] Subagent review — explicitly authorize Codex to spawn a read-only subagent
to review this migration plan; findings are shown and you decide
[S] Skip review — approve Milestone 4 without independent review
[I] Revise and Implement in the same turn — give specific bounded revisions and
approve implementation after those changes
[R] Revise — adjust scope/tasks
[N] New session — use this plan as handoff for a fresh implementation thread

Pick A/S/I/R/N, or tell me what to change.
