---
title: "ADR — Codex workflow state machine"
status: proposed
date: 2026-04-29
cycle_id: 20260429-codex-port-architecture-redesign
---

# ADR — Codex Workflow State Machine

## Context

Recent Codex behavior showed that invoking a Sage skill is not enough to keep
the agent inside Sage guardrails. The agent can say `Sage -> architect
workflow` and still drift: offer false choices, blur `[R]` semantics, skip
checkpoint discipline, or produce pseudo-Sage without correct artifacts.

Mutation guards catch file writes, but they do not catch conversational process
drift before a write happens.

## Decision

Add an explicit workflow state machine and gate validator to the Codex adapter.
It derives current state from `.sage/` artifacts and answers:

- what initiative is active;
- which workflow and phase are active;
- what gate is currently open;
- what actions are allowed next;
- what response shape is required;
- whether project mutation is allowed.

The validator should be shared by hooks, `sage status`, and generated context.
It should validate workflow transitions, conversation transitions, and mutation
transitions.

## Rationale

Sage's real contract is not "a skill was invoked." The contract is "the agent
is at a specific workflow gate and can only take the next allowed step." Codex
needs that contract represented outside the model's voluntary memory.

This layer directly targets pseudo-Sage: behavior that uses Sage language but
does not follow Sage process.

## Alternatives Considered

- Rely on workflow skills alone: rejected because observed behavior drifted
  even after skill invocation.
- Rely only on mutation guardrails: incomplete because process drift can happen
  before writes.
- Add a standalone phase tracker immediately: deferred because it risks a
  second source of truth unless artifact-derived state proves insufficient.

## Consequences

Implementation must define a canonical gate schema per workflow. Hook payloads
and status output should use that schema instead of duplicating workflow logic.
Verification must include pseudo-Sage cases, not only invalid write attempts.
