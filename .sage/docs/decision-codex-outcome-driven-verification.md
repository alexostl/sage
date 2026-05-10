---
title: "ADR — Outcome-driven Codex verification"
status: proposed
date: 2026-04-29
cycle_id: 20260429-codex-port-architecture-redesign
---

# ADR — Outcome-Driven Codex Verification

## Context

The reverted Codex enforcement activation cycle had 78/78 mechanical tests
passing but failed the first real pilot prompt. The failure was not unit-test
coverage; it was choosing proxy success criteria instead of behavioral outcome
criteria.

## Decision

Every Codex enforcement milestone must include an empirical pilot before it can
be considered complete. The pilot should include 12-15 prompts across:

- casual chat;
- read-only analysis;
- Polish build request with typos;
- fix request;
- architect/refactor request;
- explicit workflow invocation;
- invalid write attempt before Sage artifacts;
- valid write after workflow artifacts;
- pseudo-Sage attempt without files;
- optional diagnostic temp writes.

## Rationale

The target behavior is conversational and agentic. Unit tests validate helper
logic, but they cannot prove that the full Codex loop follows Sage.

## Alternatives Considered

- One end-to-end scenario: better than none, but too narrow.
- Mechanical hook tests only: already failed to predict real behavior.

## Consequences

Milestones can be implementation-complete but not done until the pilot passes.
Verification artifacts must include real pilot transcripts or summarized
observable outcomes with enough detail to reproduce failures.
