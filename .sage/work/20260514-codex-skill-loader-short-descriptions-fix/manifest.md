---
cycle_id: "20260514-codex-skill-loader-short-descriptions-fix"
title: "Fix: Codex skill loaders need short descriptions"
workflow: fix
phase: completed
status: completed
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
priority: P2
needs-triage: false
implementation_approval:
  mode: approved
  approved_by: alexostl
  approved_at: "2026-05-15"
  gate: plan-gate
  artifact: ".sage/work/20260514-codex-skill-loader-short-descriptions-fix/plan.md"
  scope: manifest
source: "conversation"
tags:
  - codex-skills
  - gui
  - descriptions
related:
  - "runtime/platforms/codex/setup/lib/skills-deploy.sh"
  - "runtime/platforms/codex/setup/lib/extract-preamble.sh"
  - "core/workflows/*.workflow.md"
scope:
  - ".sage/work/20260514-codex-skill-loader-short-descriptions-fix/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/setup/lib/extract-preamble.sh"
  - "runtime/platforms/codex/setup/tests/preamble-extraction.bats"
---

# Fix: Codex skill loaders need short descriptions

## State

**Current phase:** completed - extractor preamble pomija `Artifact Language Contract`, a smoke setup/hooks/harness przechodzi.

## Problem

Codex GUI pokazuje workflow skille Sage z opisem `## Artifact Language Contract`,
bo loader bierze z workflow zły fragment jako `description`.

## Desired behavior

Nazwy `Sage` zostają bez zmian. Opisy workflow skillów mają być bardzo
skrótowe: jedno krótkie, ludzkie zdanie w stylu `Sage Navigator`.

## Acceptance Criteria

- Workflow loader descriptions nie pokazują nagłówków technicznych.
- Każdy publiczny workflow ma bardzo krótki opis użycia.
- `Sage` namespace / nazewnictwo nie jest zmieniane.
