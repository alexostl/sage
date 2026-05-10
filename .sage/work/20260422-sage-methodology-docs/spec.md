---
title: "Specification for Sage Documentation Package"
status: "completed"
phase: "design-spec"
created: "2026-04-22"
updated: "2026-04-22"
depends_on: "brief.md"
handoff: |
  Key decisions: `.sage/` is the working source of truth, `to-rewrite-in-sage/`
  is legacy input only, and the documentation package is intentionally compact:
  repository map, working model, Codex platform context, and a source-of-truth
  decision record.
  Research context: Inputs came from `to-rewrite-in-sage/`, `docs/`,
  `runtime/platforms/`, current `.sage/`, and repository structure inspection.
  Open questions: Whether any additional `.sage/docs/` artifact is needed will
  depend on implementation-time parity checks against legacy notes.
  Next agent should: Create the four `.sage/docs/` artifacts defined here,
  verify they make `to-rewrite-in-sage/` unnecessary for normal work, then
  write a plan and execute the documentation package.
---

# Specification: Sage Documentation Package for `sage-codex`

## Summary

Produce a compact Sage-native documentation package that lets future work on
`sage-codex` proceed from `.sage/` without relying on `to-rewrite-in-sage/` as
an active working surface.

This specification covers documentation artifacts only. It does not require
runtime, adapter, or repository-structure changes.

## Target Artifacts

Create the following project-level artifacts in `.sage/docs/`:

1. `learn-sage-codex-repository-map.md`
2. `learn-sage-codex-working-model.md`
3. `learn-sage-codex-codex-platform-context.md`
4. `decision-sage-source-of-truth.md`

This initiative keeps its own planning artifacts in:

- `.sage/work/20260422-sage-methodology-docs/brief.md`
- `.sage/work/20260422-sage-methodology-docs/spec.md`
- `.sage/work/20260422-sage-methodology-docs/plan.md` (next phase)

## Artifact Definitions

### 1. `learn-sage-codex-repository-map.md`

Purpose:
Provide a durable map of the repository's major surfaces and tell future
sessions where to look for canonical information by concern.

Required sections:

- Repository purpose and scope
- Major top-level directories and what they own
- Canonical source map:
  - philosophy and framework rationale
  - contribution and development guidance
  - platform adapters
  - runtime and generator behavior
  - project state in `.sage/`
- Reading order for a new agent entering the repo
- Explicit note that `to-rewrite-in-sage/` is legacy and non-canonical

Primary inputs:

- `docs/README.md`
- `docs/philosophy/design-philosophy.md`
- `runtime/platforms/README.md`
- current repo structure
- selected legacy notes where needed for parity

### 2. `learn-sage-codex-working-model.md`

Purpose:
Describe how ongoing work in this repository should be carried out using Sage
artifacts and which kinds of information belong in `.sage/docs/` versus
`.sage/work/`.

Required sections:

- Working model for Sage-on-Sage repository maintenance
- What belongs in `.sage/docs/`
- What belongs in `.sage/work/`
- How to start a new initiative in this repo
- How to resume an existing initiative
- How repo knowledge in `.sage` should reference, not duplicate, broader public
  docs when summaries are enough
- Rules that prevent reintroducing parallel sources of truth

Primary inputs:

- `docs/philosophy/project-state-convention.md`
- current `AGENTS.md`
- current `.sage/` structure and decisions
- session decisions from this initiative

### 3. `learn-sage-codex-codex-platform-context.md`

Purpose:
Capture the subset of Codex adapter and self-hosting context that future
working sessions need in `.sage/`, so they do not have to rediscover platform
constraints from legacy notes or broad product docs.

Required sections:

- What "Codex support" means in this repository today
- Generated Codex surfaces and their role
- Current posture on `.agents/skills/`, `AGENTS.md`, `.codex/config.toml`,
  automations, hooks, and native Git/worktree flows
- Self-hosted-repo caveats relevant to this repository
- Pointers to canonical deeper docs in `runtime/platforms/codex/`

Primary inputs:

- `to-rewrite-in-sage/runtime/platforms/codex/README.md`
- `to-rewrite-in-sage/runtime/platforms/codex/INSTALL.md`
- `to-rewrite-in-sage/runtime/platforms/codex/HOOKS.md`
- `to-rewrite-in-sage/SELF_HOSTING.md`
- current `runtime/platforms/codex/*`

### 4. `decision-sage-source-of-truth.md`

Purpose:
Make the source-of-truth policy explicit and durable so future sessions do not
treat legacy files as co-equal with `.sage`.

Required sections:

- Context
- Decision
- Consequences
- Legacy-folder deletion condition

Decision content must state:

- `.sage/` is the working source of truth for project execution
- `to-rewrite-in-sage/` is legacy input only
- the legacy folder may be removed after parity is verified against this spec

## Source Mapping Rules

The documentation package must use this mapping logic:

- `.sage/docs/` contains condensed operational knowledge for future work
- broader public framework docs in `docs/` remain canonical for product-facing
  explanations unless the new `.sage` docs explicitly narrow or summarize them
  for repository operations
- platform implementation details remain canonical in `runtime/`
- legacy content in `to-rewrite-in-sage/` may inform the rewrite but must not
  remain required reading after completion

In practice:

- summarize and point when a repo surface already has good canonical docs
- restate only the minimum needed to make `.sage` usable as the working layer
- record any repo-specific interpretation directly in `.sage/docs/`

## Parity Requirement for Legacy Removal

`to-rewrite-in-sage/` is removable only when all of the following are true:

1. Every operational concept needed for continuing work in this repo can be
   found from `.sage/docs/` plus the canonical repo paths it references.
2. The repository map identifies where philosophy, contribution, platform, and
   self-hosting truth live today.
3. The working model explains how new work should be recorded in `.sage/`.
4. The Codex platform context captures the practical constraints that otherwise
   required consulting the legacy folder.
5. The decision record explicitly marks the legacy folder non-canonical.

## User Flow Requirements

Future sessions should be able to follow this path:

1. Read `.sage/decisions.md` for recent decisions.
2. Read `.sage/docs/learn-sage-codex-working-model.md` for how to work in the
   repo.
3. Use `.sage/docs/learn-sage-codex-repository-map.md` to locate deeper
   canonical repo docs.
4. Open `.sage/docs/learn-sage-codex-codex-platform-context.md` only when the
   task touches Codex/self-hosting behavior.
5. Treat `to-rewrite-in-sage/` as archival input, not part of normal flow.

## Boundaries

In scope:

- writing the four `.sage/docs/` artifacts above
- extracting and condensing operational knowledge from legacy and canonical docs
- documenting the deletion condition for the legacy folder

Out of scope:

- deleting `to-rewrite-in-sage/` in this design phase
- editing runtime code, generators, or adapter behavior
- rewriting public `docs/` content unless a broken link or factual mismatch
  blocks the documentation package

## Quality Requirements

Each final doc must be:

- operational: it helps a future working session take action
- source-aware: it points to canonical repo locations for deeper detail
- non-duplicative: it avoids copying large chunks of existing docs
- explicit about canonical vs summarized vs legacy material

## Error States and Recovery

- If a legacy note conflicts with the current repository, prefer current repo
  state and record the interpretation in `.sage/docs/`.
- If a required concept has no reliable canonical source in the current repo,
  flag it in the implementation plan as a gap instead of inventing certainty.
- If a `.sage` artifact risks becoming a duplicate of a public doc, compress it
  into a summary plus pointers.

## Acceptance Criteria

1. The four specified `.sage/docs/` artifacts exist with the required sections.
2. A future agent can determine normal working procedure for this repository by
   reading `.sage/` first.
3. `to-rewrite-in-sage/` is described consistently as legacy input only.
4. The spec defines a concrete parity gate for eventual legacy-folder removal.
5. No artifact requires a reader to scan the legacy folder to understand how to
   continue normal work on the repo.
