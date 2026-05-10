---
cycle_id: "20260507-framework-copy-boundary"
title: "Fix Plan - Framework copy boundary"
workflow: fix
phase: complete
status: completed
created: 2026-05-07
updated: 2026-05-07
scope: Moderate
---

# Fix Plan: Framework copy boundary

## Classification

Moderate. The fix touches the shared CLI copy/update path, the plugin copy path,
and Bats coverage.

## Files To Change

- `bin/sage`
  Replace raw `cp -a "$SAGE_FRAMEWORK" "$target/sage"` and update-copy raw
  `cp -a "$update_source" "$target/sage"` with a helper that copies the
  framework distribution boundary. The helper should exclude local project
  state and generated/runtime bulk: `.git`, `.github`, `.sage`,
  `.sage-memory`, `.claude`, `.codex`, `.agents`, `.tmp`, `.DS_Store`,
  `node_modules`, `__pycache__`, and Python cache files.
- `tools/sage-claude-plugin/scripts/sage`
  Mirror the same helper and use it for plugin init/update framework copies.
- `runtime/platforms/codex/setup/tests/bin-sage-wiring.bats`
  Add focused regressions proving `bin/sage init` does not copy `.sage/`,
  `.sage-memory/`, `.codex/`, `.claude/`, `.agents/`, or nested `node_modules`
  from a self-host source into the consumer `sage/` directory.

## Tests

- Run the focused Bats file:
  `bats runtime/platforms/codex/setup/tests/bin-sage-wiring.bats`
- Run adjacent setup smoke if time permits:
  `bats runtime/platforms/codex/setup/tests/stage10-tighten.bats`

## Rollback

Revert the helper and test changes. The old behavior returns to raw `cp -a`
plus narrow post-copy prune.

## Risks

- Excluding too much could omit files the runtime actually needs.
- BSD/macOS portability matters; prefer POSIX shell and tools already present
  in the test environment.

## Completion

Implemented 2026-05-07. The main CLI and Claude plugin script now use
`copy_framework_distribution`, backed by an expanded post-copy prune for
legacy safety. Focused Codex `bin/sage` wiring tests assert that consumer
`sage/` copies exclude self-host project state and nested `node_modules`.
