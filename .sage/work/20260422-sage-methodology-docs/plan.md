---
title: "Implementation Plan for Sage Documentation Package"
status: "completed"
phase: "build-plan"
created: "2026-04-22"
updated: "2026-04-22"
depends_on: "spec.md"
---

# Implementation Plan: Sage Documentation Package

**Spec:** `.sage/work/20260422-sage-methodology-docs/spec.md`
**Brief:** `.sage/work/20260422-sage-methodology-docs/brief.md`
**Mode:** build
**Status:** completed
**Started:** 2026-04-22
**Last updated:** 2026-04-22

## Constitution Constraints

- Keep the working source of truth for this initiative in `.sage/`.
- Do not leave `to-rewrite-in-sage/` as a parallel operating surface.
- Prefer concise operational summaries with explicit pointers over duplicating large blocks of existing repo docs.
- This cycle is documentation-only; do not change runtime, adapter, or repository behavior unless a factual doc mismatch blocks the deliverable.

## Technology Decisions

Using the existing repository documentation stack:

- Markdown artifacts in `.sage/docs/` for durable operational knowledge
- Markdown artifacts in `.sage/work/20260422-sage-methodology-docs/` for initiative state
- Canonical deeper references remain in `docs/`, `runtime/`, `develop/`, and other repo paths as linked from the new `.sage/docs/` files

## Milestone 1: Establish the working layer in `.sage/docs/`

Delivers: repository orientation and Sage-on-Sage operating model

### Task 1: Repository map for future sessions [DOC] [done]

**Read first:** `spec.md` sections "Target Artifacts" and "Artifact Definitions"; `docs/README.md`; `docs/philosophy/design-philosophy.md`; `runtime/platforms/README.md`
**Output:** `.sage/docs/learn-sage-codex-repository-map.md`
**Action:** Write a repository map that explains what `sage-codex` is, what each major top-level directory owns, which repo locations are canonical by concern, and why `to-rewrite-in-sage/` is legacy/non-canonical.
**Criteria:** Includes repository purpose, top-level map, canonical-source matrix, recommended reading order for a new agent, and an explicit non-canonical note for `to-rewrite-in-sage/`.
**Depends on:** none

### Task 2: Working model for Sage-on-Sage maintenance [DOC] [done]

**Read first:** `spec.md` section "Artifact Definitions"; `docs/philosophy/project-state-convention.md`; `AGENTS.md`; `.sage/decisions.md`
**Output:** `.sage/docs/learn-sage-codex-working-model.md`
**Action:** Write the working model that tells future sessions how to use `.sage/docs/` versus `.sage/work/`, how to start and resume initiatives, and how to avoid recreating parallel sources of truth.
**Criteria:** Clarifies where state belongs, how work starts/resumes, how `.sage` references deeper repo docs, and what practices would violate the source-of-truth model.
**Depends on:** Task 1

🔒 CHECKPOINT: The `.sage/docs/` working layer is understandable enough that a future session can orient itself in the repo without opening the legacy folder first.

## Milestone 2: Capture platform context and source-of-truth policy

Delivers: Codex/self-host operational context and explicit decision record

### Task 3: Codex platform context note [DOC] [done]

**Read first:** `spec.md` section "Artifact Definitions"; `runtime/platforms/codex/README.md`; `runtime/platforms/codex/INSTALL.md`; `runtime/platforms/codex/HOOKS.md`; `to-rewrite-in-sage/SELF_HOSTING.md`
**Output:** `.sage/docs/learn-sage-codex-codex-platform-context.md`
**Action:** Write a compact operational note covering current Codex adapter surfaces, hooks/automations posture, self-hosting caveats, and where deeper canonical platform docs live.
**Criteria:** Explains current Codex support honestly, captures only the practical context needed for work in this repo, and points to canonical deeper docs in `runtime/platforms/codex/`.
**Depends on:** Task 1

### Task 4: Source-of-truth decision record [DOC] [done]

**Read first:** `spec.md` sections "Source Mapping Rules" and "Parity Requirement for Legacy Removal"; `.sage/decisions.md`; `brief.md`
**Output:** `.sage/docs/decision-sage-source-of-truth.md`
**Action:** Write the decision record that formalizes `.sage/` as the working source of truth, marks `to-rewrite-in-sage/` as legacy input only, and states the deletion condition after parity.
**Criteria:** Includes context, decision, consequences, and a concrete legacy-folder deletion condition consistent with the approved spec.
**Depends on:** Task 2, Task 3

🔒 CHECKPOINT: Future sessions have both the platform-specific context and the explicit policy needed to treat `.sage` as the first stop for project work.

## Final: Parity and package verification

### Task 5: Verify parity and tighten cross-links [DOC] [done]

**Read first:** `spec.md` acceptance criteria; all new `.sage/docs/` artifacts; key legacy inputs in `to-rewrite-in-sage/`
**Output:** `.sage/docs/` package updates across the four created files
**Action:** Review the documentation package as a whole, close any missing parity gaps, ensure cross-links/pointers are sufficient, and confirm no final artifact requires `to-rewrite-in-sage/` for normal work comprehension.
**Criteria:** All spec acceptance criteria are met; each file is clear about canonical vs summarized vs legacy content; the package defines when the legacy folder can be deleted.
**Depends on:** Task 1, Task 2, Task 3, Task 4

## Gate Log

| Task | Gate 1 | Gate 2 | Gate 3 | Gate 4 | Gate 5 |
|------|:---:|:---:|:---:|:---:|:---:|
| Task 1 | pass | pass | n/a | n/a | n/a |
| Task 2 | pass | pass | n/a | n/a | n/a |
| Task 3 | pass | pass | n/a | n/a | n/a |
| Task 4 | pass | pass | n/a | n/a | n/a |
| Task 5 | pass | pass | n/a | n/a | n/a |
