# Learn: `sage-selfhost` Working Model

## Purpose

This file defines how to work on the Sage framework repository using Sage
artifacts. It is the operational contract for future sessions: where state
lives, where durable knowledge lives, and how to avoid rebuilding parallel
sources of truth.

## Core Working Model

`sage-selfhost` should be worked as a Sage project first and a framework repo
second.

That means:

- initiative state lives in `.sage/work/`
- durable repo-operational knowledge lives in `.sage/docs/`
- significant decisions are logged in `.sage/decisions.md`
- deeper framework/reference material remains in canonical repo paths and is
  reached through `.sage` pointers

The practical starting point for a working session is always `.sage/`.

For repository-operational Git work, `.sage/` is not enough by itself. Future
sessions must also follow `.sage/docs/learn-sage-selfhost-branch-worktree-model.md`
for branch roles, local-vs-remote branch handling, update order, and upstream
PR rules.

## What Belongs In `.sage/docs/`

Put information in `.sage/docs/` when it is:

- needed across multiple future sessions
- specific to how this repository should be worked
- useful as operational guidance rather than public product documentation
- better expressed as a concise summary with pointers than rediscovered each time

Good examples:

- repository maps
- working model notes
- platform-context summaries for repo operations
- decision records that change how future work should be done
- reflection reports and learnings that matter across initiatives

## What Belongs In `.sage/work/`

Put information in `.sage/work/YYYYMMDD-slug/` when it is tied to one
initiative or cycle.

That includes:

- `brief.md`
- `spec.md`
- `plan.md`
- `manifest.md`
- initiative-specific research or scratch notes
- initiative-scoped QA/review artifacts

If a document answers "how do we do this repo in general?", it does not belong
only in `work/`. Promote the reusable part into `.sage/docs/`.

## How To Start A New Initiative

1. Read `.sage/decisions.md` and any relevant `.sage/docs/` notes.
2. Create a new `.sage/work/YYYYMMDD-slug/` folder for the initiative.
3. Follow the Sage workflow gates for the chosen workflow.
4. Keep initiative state inside that folder rather than in free-floating notes.
5. Promote only reusable repo knowledge into `.sage/docs/`.

## How To Resume Existing Work

1. Check `.sage/work/` for active initiative folders.
2. Read `manifest.md` first when it exists.
3. Read the latest approved artifact and recent `.sage/decisions.md` entries.
4. Use `.sage/docs/` when the initiative depends on repo-wide operating context.
5. Open deeper repo docs only through the path suggested by `.sage/docs/` or the active artifact.

## How `.sage` Should Relate To The Rest Of The Repo

`.sage` is the working layer, not a full mirror of the repository.

Use this rule:

- if a broad public or implementation doc already exists and is still accurate,
  summarize it in `.sage` only as much as needed for execution and link onward
- if a repo-operational conclusion is specific to working on `sage-selfhost`, keep
  that conclusion in `.sage`
- if a document would only repeat existing public docs line-by-line, do not
  duplicate it

This keeps `.sage` useful without turning it into another documentation tree.

## Preventing Parallel Sources Of Truth

The following are anti-patterns:

- leaving active project-working guidance only in `to-rewrite-in-sage/`
- creating new ad hoc status notes outside `.sage/work/`
- storing reusable operational knowledge only in an initiative folder after it
  clearly matters repo-wide
- rewriting large public docs into `.sage/docs/` without adding working value

The preferred pattern is:

1. capture the reusable operational truth in `.sage`
2. point to deeper canonical repo paths for full detail
3. archive or delete legacy notes once parity is achieved

## Source-Of-Truth Rule For This Repo

For normal project work:

- `.sage/` is the first stop
- `docs/`, `runtime/`, `core/`, and `develop/` provide deeper canonical detail
- `to-rewrite-in-sage/` is not part of the normal working loop

If a future session cannot start effectively from `.sage`, the missing context
should be added to `.sage` rather than left implicit.

## Source-Of-Truth Rule For Repo Operations

For branch and upstream operations, the source-of-truth chain is:

1. `upstream/main` for external truth
2. `origin/main` as the fork's mirrored upstream branch on GitHub
3. `origin/codex-port` as the shared integration branch on GitHub
4. local `self-host/main` as the active self-host work surface

That operational chain is defined in
`.sage/docs/learn-sage-selfhost-branch-worktree-model.md` and should not be
reinvented ad hoc in future sessions.

Before mutating any long-lived branch in that chain:

1. produce an upstream-impact analysis artifact that identifies overlap files,
   risk areas, and planned QA scope
2. sync forward only after that analysis exists
3. treat `behind 0` or successful merges as topology only, not compatibility
4. run fresh QA after the sync and do not call the chain stable until that QA
   passes

For this repo, only `self-host/main` is expected to have a resident local
worktree. `main` and `codex-port` are remote-first branches maintained on
GitHub and should be recreated locally only for short-lived sync, QA, or
upstream-prep tasks.
