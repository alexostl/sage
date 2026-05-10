---
title: "Sage Methodology Documentation for sage-codex"
status: "completed"
phase: "design-brief"
created: "2026-04-22"
updated: "2026-04-22"
---

# Brief: Sage Methodology Documentation for `sage-codex`

## Objective

Create the minimum durable Sage documentation needed to continue work on
`sage-codex` inside Sage methodology with `.sage/` as the working source of
truth and `to-rewrite-in-sage/` reduced to a temporary legacy input slated for
deletion after parity is confirmed.

## Problem

The repository already contains rich project knowledge, but the information
needed for ongoing work is still split across:

- public product docs in `docs/`
- operational framework material in `core/`, `runtime/`, and `develop/`
- a concentrated legacy handoff/reference bundle in `to-rewrite-in-sage/`
- a mostly empty `.sage/` state layer

That means the repo can be understood, but the operative source of truth for
future work is still fragmented. The missing piece is not new product design or
repo migration. The missing piece is Sage-native documentation that consolidates
project-working truth into `.sage/` and captures:

- what this repository is
- which documents are the current sources of truth
- how ongoing work should be framed inside `.sage/`
- what special rules apply to this self-hosted Sage-on-Sage setup

`to-rewrite-in-sage/` is not part of the desired end state. It is a legacy
staging folder used only while rewriting knowledge into Sage-native artifacts.

## Source Inputs

Primary discovery inputs for this brief:

- `to-rewrite-in-sage/README.md`
- `to-rewrite-in-sage/CONTRIBUTING.md`
- `to-rewrite-in-sage/SELF_HOSTING.md`
- `to-rewrite-in-sage/runtime/platforms/codex/README.md`
- `to-rewrite-in-sage/runtime/platforms/codex/HOOKS.md`
- `to-rewrite-in-sage/runtime/platforms/codex/IMPLEMENTATION_READY_HANDOFF.md`
- `docs/README.md`
- `docs/philosophy/design-philosophy.md`
- `docs/philosophy/project-state-convention.md`
- current repository structure and current `.sage/` contents

## Users

Primary users of this documentation set:

- future Codex or Claude agents resuming work in this repository
- maintainers working on Sage itself
- contributors who need the repo's current operating model

## User Decisions

These decisions are fixed by the current session and should drive the spec:

| Item | Decision | Direction |
| --- | --- | --- |
| Framing | Keep | This is a documentation task, not a repo migration |
| Main goal | Keep | Enable continued project work in Sage methodology |
| Source folder | Keep | `to-rewrite-in-sage/` is a legacy input-only folder during rewrite |
| Working source of truth | Keep | All project-operational truth for future work should live in `.sage/` |
| Legacy cleanup | Keep | `to-rewrite-in-sage/` should be removable after Sage artifact parity is confirmed |
| Fidelity | Keep | Reflect current repo reality over historical completeness |
| Scope | Limit | No code or adapter changes are required in this phase unless a doc gap blocks comprehension |

## Documentation Direction

### Structure Direction

Use Sage's standard split:

- initiative-specific work for this effort in `.sage/work/20260422-sage-methodology-docs/`
- durable repo knowledge in `.sage/docs/`

The output should make `.sage/` the only place a future working session needs to
consult for project state and methodology context.

The output should make it obvious which knowledge in `.sage/` is:

- temporary planning for this documentation effort
- durable project knowledge for future sessions

### Content Direction

The documentation should be:

- operational rather than promotional
- source-mapped rather than rewritten from memory
- concise enough for agents to load selectively
- explicit about what is canonical versus supporting context

### Narrative Direction

The resulting documentation should answer, in order:

1. What is `sage-codex` as a repository?
2. Which directories and docs are authoritative for different concerns?
3. Which parts of that authority must be mirrored or condensed into `.sage/` to
   support ongoing work?
4. How should future work in this repo be recorded in Sage artifacts?
4. What special constraints apply because this repo is Sage working on Sage?

## Proposed Deliverable Shape

The specification should define a documentation package that likely includes:

1. A repo operating overview for Sage-driven work in this repository, stored in
   `.sage/`.
2. A source-of-truth map that tells future sessions what remains canonical in
   the repo and what must be consulted through `.sage/`.
3. A self-hosting / platform-context note for Codex-specific work.
4. Any required decision records needed to remove ambiguity about how to use
   `.sage/` in this repo going forward.
5. A documented parity condition for when `to-rewrite-in-sage/` can be deleted.

Exact filenames and boundaries should be finalized in `spec.md`.

## Constraints

- Do not treat legacy reference docs as publish-as-is final artifacts.
- Do not leave `to-rewrite-in-sage/` as a parallel working source of truth.
- Do not duplicate large sections of existing public docs if a focused
  Sage-native summary with pointers is enough.
- Do not invent framework behavior that is not supported by the current repo.
- Keep the doc set small enough that future agents can quickly identify the
  right file instead of scanning many overlapping documents.
- Preserve the distinction between project-level knowledge in `.sage/docs/`
  and initiative-level work in `.sage/work/`.

## Success Criteria

This brief succeeds if the spec can produce a doc set where a new agent can:

1. Explain the repository's current purpose and major surfaces without first
   opening `to-rewrite-in-sage/`.
2. Identify which documents are canonical for philosophy, contribution,
   self-hosting, and Codex adapter behavior.
3. Continue work in this repo using `.sage/work/` and `.sage/docs/` as the
   practical source of truth without guessing where new state belongs.
4. Determine when the Sage artifact set is complete enough to remove
   `to-rewrite-in-sage/`.
5. Avoid confusing documentation work with codebase migration or adapter
   implementation work.

## Out of Scope

- rewriting the entire public documentation tree
- changing runtime behavior, generators, or platform adapters
- planning implementation work beyond the documentation package itself
