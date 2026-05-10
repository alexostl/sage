---
title: "ADR — Codex mutation guardrail stack"
status: proposed
date: 2026-04-29
cycle_id: 20260429-codex-port-architecture-redesign
---

# ADR — Codex Mutation Guardrail Stack

## Context

Regex-based intent detection failed because user prompts vary by language,
typos, synonyms, and phrasing. The more stable trigger is not what the user
said, but what the agent tries to do: mutate files.

Codex `PreToolUse` can intercept `apply_patch`, `Edit`, `Write`, Bash, and MCP
tool calls, but the docs explicitly call it a guardrail rather than a complete
enforcement boundary.

## Decision

Use a layered mutation guardrail stack:

1. Soft routing before mutation: compact `AGENTS.md`, `SessionStart`, and
   `UserPromptSubmit`.
2. `PreToolUse` guardrails for common mutation paths:
   `apply_patch|Edit|Write`, selected MCP write tools, and narrow Bash writes
   where command shape is obvious.
3. `PostToolUse` mutation detection for commands that already ran.
4. `Stop` validation to catch pseudo-Sage or missing artifact updates before
   the turn ends.
5. `.githooks/pre-commit` as the last repository backstop.

## Rationale

No single Codex hook is sufficient in Skip Permissions. Layering gives earlier
course correction while preserving honest guarantees.

## Alternatives Considered

- Prompt classifier as primary gate: rejected after empirical failure.
- Semantic subagent on every prompt: potentially useful later, but costly and
  not deterministic enough for the main gate.
- Pre-commit only: too late; it catches commits, not the working tree drift
  that happens during the conversation.

## Consequences

The adapter needs shared state predicates for "valid Sage workflow state" so
`PreToolUse`, `PostToolUse`, `Stop`, and status reporting do not each invent
their own logic.
