---
title: "ADR — Codex enforcement profiles"
status: proposed
date: 2026-04-29
cycle_id: 20260429-codex-port-architecture-redesign
---

# ADR — Codex Enforcement Profiles

## Context

The user normally works in Skip Permissions. In that mode Codex may run with no
approval prompts and no meaningful sandbox boundary. Official docs distinguish
approval policy from sandbox mode and warn that full access removes filesystem
and network boundaries. Official hooks docs also describe `PreToolUse` as a
guardrail, not a complete enforcement boundary.

## Decision

Define two Codex enforcement profiles:

- `fast-trusted`: default self-host profile for trusted repos and Skip
  Permissions. Uses behavioral guardrails, hooks, status warnings, and git
  backstops. It must not claim OS-level hard enforcement.
- `strict`: sandbox/permissions-backed profile for teams or environments that
  need stronger boundaries. Uses Codex sandbox and approval settings where
  available, plus the same Sage hooks.

## Rationale

This makes the guarantee level explicit. Sage should improve behavior in
fast-trusted mode without pretending it can enforce a security boundary that
Codex itself has bypassed.

## Alternatives Considered

- One universal strict model: safer, but conflicts with the user's actual
  trusted local workflow.
- One universal fast model: ergonomic, but misleading for teams expecting hard
  enforcement.

## Consequences

`sage status` and generated docs must report the active guarantee level. Tests
must cover both profiles where possible. Completion language must distinguish
"blocked by sandbox" from "redirected by Sage guardrail."
