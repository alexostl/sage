---
title: "ADR — Codex layered runtime model"
status: proposed
date: 2026-04-29
cycle_id: 20260429-codex-port-architecture-redesign
---

# ADR — Codex Layered Runtime Model

## Context

The failed Codex enforcement attempt treated pre-turn routing as the main
control point. That made the design depend on classifying the user's words
before the model acted. The user also works in Skip Permissions, so hook-based
blocks must not be described as hard filesystem enforcement.

The new Codex design needs to preserve loose conversation while still making
Sage mandatory before repository mutation.

## Decision

Model Sage on Codex as four runtime lifecycles:

1. Session lifecycle: inject durable project orientation through
   `SessionStart`.
2. Turn lifecycle: inject a compact semantic routing nudge through
   `UserPromptSubmit`, capped at 200 tokens.
3. Mutation lifecycle: evaluate a shared valid-Sage-state predicate before
   common write/edit operations.
4. Recovery lifecycle: use `PostToolUse`, `Stop`, pre-commit, and
   `sage status` to expose and recover from bypasses.

`.sage/` remains the workflow state source of truth. Runtime helpers may derive
summaries, but should not create a competing Codex-only state model in v1.

## Rationale

This separates timing concerns cleanly:

- session context answers "where are we?";
- turn context answers "what kind of work might this be?";
- mutation guards answer "is it valid to change files now?";
- recovery layers answer "did something drift anyway?".

The model avoids regex-based routing as the authority while still allowing
Codex to self-route early when the user's intent is clear.

## Alternatives Considered

- Full Sage Navigator on every session: rejected as too token-heavy and likely
  to duplicate `AGENTS.md`.
- Semantic classifier subagent on every prompt: deferred because it adds
  latency, cost, and another integration surface.
- Mutation-only guardrails: too late for a good user experience; the agent
  should try to enter Sage before reaching the first write.
- Codex-only phase tracker in v1: deferred to avoid competing sources of truth.

## Consequences

The build must implement one shared predicate for valid mutation state and use
it from hooks and status. Verification must test the whole lifecycle, not only
individual hook scripts.
