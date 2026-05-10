---
title: "ADR — Public workflow skills and internal Sage library"
status: proposed
date: 2026-04-29
cycle_id: 20260429-codex-port-architecture-redesign
---

# ADR — Public Workflow Skills and Internal Sage Library

## Context

Codex skill discovery uses progressive disclosure: Codex initially receives
skill name, description, and path, then reads full `SKILL.md` only when the
skill is selected. A full list of roughly 60 Sage skills makes the Codex UI
palette harder to use because the user must mentally find the small set of
real entry points.

Codex docs do not provide a clean "hidden but native skill" flag. Disabling a
skill disables it; keeping it in `.agents/skills` keeps it discoverable.

## Decision

Expose only public workflow skills in `.agents/skills`. Treat all other Sage
methodology skills as an internal lazy-loaded library, referenced by manifest
and file path from workflow skills.

The public workflow list is a product contract. Internal skills remain
available to the agent through explicit workflow dependency instructions, not
through user-visible native skill discovery.

## Rationale

This keeps the UI useful and matches Sage's product promise: users choose a
mode of work, not an internal method fragment. It also preserves token economy
if the internal library uses metadata-first discovery and reads full skill
bodies only on phase entry.

## Alternatives Considered

- Expose all skills: simplest native Codex implementation, but poor UX.
- Prefix internal skills with `zz-`: moves noise to the end, but still exposes
  internals and requires users to understand two classes of skills.
- Disable internal skills with `skills.config`: hides them, but also removes
  native skill availability.

## Consequences

Workflow skills must own dependency loading. The adapter needs an internal skill
manifest and validation so workflow-library drift is caught before runtime.
