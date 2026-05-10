---
title: "ADR — Codex approval proof"
status: proposed
date: 2026-04-29
cycle_id: 20260429-codex-port-architecture-redesign
---

# ADR — Codex Approval Proof

## Context

Sage gates depend on user approval. In conversational agents, "the user
approved this earlier" can easily become model memory rather than durable
project state. Codex drift in the architecture session showed that gate
semantics such as `[R]` and "design in review" must be machine-checkable, not
only remembered.

## Decision

Represent approval proof on disk using artifact frontmatter plus a matching
decision log entry.

New Codex-port workflow artifacts should record approval metadata when a gate
is accepted:

- `approved_at`;
- `approved_by`;
- `approval_source`;
- `approval_gate`;
- optional `approval_notes`.

The workflow state machine should treat approval as missing if it cannot be
derived from artifact state and decision log evidence.

## Rationale

This makes Sage gates observable and gives hooks/status a stable source of
truth. It also clarifies the meaning of `[A]`, `[S]`, and `[R]`:

- `[A]` approves and may run review;
- `[S]` approves while skipping independent review and records that risk;
- `[R]` keeps the artifact in review and allows revision only.

## Alternatives Considered

- Trust chat history: rejected because hooks/status cannot reliably inspect it.
- Use decision log only: human-readable, but weaker for machine validation.
- Use frontmatter only: machine-readable, but loses rationale and risk context.
- Add a separate approval event log immediately: deferred unless frontmatter
  plus decisions proves insufficient.

## Consequences

The generator and workflow helpers must standardize approval metadata. Status
and validators need migration language for legacy artifacts that only have
`status: completed`.
