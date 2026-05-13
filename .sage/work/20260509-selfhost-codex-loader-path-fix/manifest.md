---
title: "Fix: self-host Codex loader stubs use target-only workflow paths"
workflow: fix
status: completed
phase: completed
priority: high
created: 2026-05-09
updated: 2026-05-13
batch: "Batch 4 - Codex surface, loader i instruction reachability"
related:
  - "20260509-duplicate-sage-entrypoint-fix"
  - "20260509-sage-navigator-skill-drift-fix"
  - "20260509-codex-hooks-feature-flag-migration-fix"
scope:
  - ".sage/work/20260509-selfhost-codex-loader-path-fix/*"
  - ".sage/work/20260509-duplicate-sage-entrypoint-fix/manifest.md"
  - ".sage/work/20260509-sage-navigator-skill-drift-fix/manifest.md"
  - ".sage/work/20260509-codex-hooks-feature-flag-migration-fix/manifest.md"
  - "runtime/platforms/codex/setup/lib/skills-deploy.sh"
  - "runtime/platforms/codex/setup/tests/stage7-skills.bats"
  - "runtime/platforms/codex/setup/lib/config-toml.sh"
  - "runtime/platforms/codex/setup/tests/stage4-config-toml.bats"
  - "runtime/platforms/codex/setup/generate-codex.sh"
  - "runtime/platforms/codex/setup/tests/stage10-tighten.bats"
  - "runtime/mcp/json_to_toml.py"
  - "runtime/mcp/tests/run-regression.sh"
  - ".agents/skills/sage/SKILL.md"
  - ".agents/skills/sage-navigator/SKILL.md"
  - ".agents/skills/sage:*/SKILL.md"
  - ".agents/skills/sage:sage/"
  - ".codex/config.toml"
  - ".sage/decisions.md"
---

# Intake

## Problem

Fix F1-7 corrected generated Codex target loader stubs to point at
`sage/core/workflows/<workflow>.workflow.md`, because target repositories vendor
the Sage framework under `sage/`.

In the framework repository itself (`sage-selfhost`), `.agents/skills/sage:*`
were also generated with that target-local path. This repository does not have
`sage/core/workflows`; it has `core/workflows`. A current Codex thread can
therefore activate a Sage skill, follow the loader stub, and hit `No such file
or directory` even though F1-7 was already fixed for generated targets.

## Why It Matters

This is not a recurrence of the exact original F1-7 bug. It is the missing
self-host variant of the same path contract:

- generated target repo: loader should read `sage/core/workflows/...`;
- framework/self-host repo: loader should read `core/workflows/...`.

The current generator/test coverage proves the target case, but does not prove
that the self-host `.agents/skills` deployed in this repository can be followed
successfully.

## Candidate Fix

Make Codex skill deployment path-aware:

- when deploying into the framework repository itself, render loader stubs with
  `core/workflows/<workflow>.workflow.md`;
- when deploying into a target repository with vendored Sage, keep
  `sage/core/workflows/<workflow>.workflow.md`;
- add regression coverage for both contexts;
- regenerate the self-host `.agents/skills/sage:*` stubs after the generator
  contract is updated.

## Acceptance

- In `sage-selfhost`, every `.agents/skills/sage:*` loader points to an
  existing workflow file.
- In generated target repos, every `.agents/skills/sage:*` loader still points
  to `sage/core/workflows/...`.
- A regression test fails if either context points at a non-existent workflow
  file.
