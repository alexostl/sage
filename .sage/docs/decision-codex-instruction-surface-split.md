---
title: "ADR — Codex instruction surface split"
status: proposed
date: 2026-04-29
cycle_id: 20260429-codex-port-architecture-redesign
---

# ADR — Codex Instruction Surface Split

## Context

The current Codex adapter puts most Sage process rules into generated
`AGENTS.md`. This made sense as a first port, but it turns `AGENTS.md` into a
large rulebook and creates pressure to duplicate the same reminders again in
hooks. Codex docs confirm that `AGENTS.md` is part of the project instruction
chain, while `SessionStart` and `UserPromptSubmit` hooks can inject additional
developer context at session or turn scope.

## Decision

Split Codex instructions by stability and timing:

- `AGENTS.md`: compact static contract and source-of-truth rules.
- `SessionStart`: dynamic project state snapshot.
- `UserPromptSubmit`: tiny per-turn salience nudge, capped at 200 tokens.
- Workflow skills: full workflow procedures after workflow selection.
- Internal library skills: lazy-loaded only by workflow phase.

## Rationale

This preserves the always-on authority of `AGENTS.md` while avoiding three
copies of the same rule text. It also uses Codex hooks for what they do best:
injecting current context close to the model decision point.

## Alternatives Considered

- Put everything in `AGENTS.md`: simpler, but bloats every session and loses
  dynamic project state.
- Put routing primarily in `UserPromptSubmit`: more salient, but expensive per
  prompt and brittle if hooks are disabled.
- Auto-load full Sage Navigator on every session: too large and too much
  methodology context before the user has asked for a workflow.

## Consequences

`AGENTS.md` must be rewritten as a short constitution. Existing long workflow
gate text moves into workflow skills, library manifests, and hook-generated
state. Hook text must be budgeted and tested for token size.
