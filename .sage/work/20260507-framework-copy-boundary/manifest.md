---
cycle_id: "20260507-framework-copy-boundary"
title: "Framework copy boundary"
workflow: fix
phase: complete
status: completed
created: 2026-05-07
updated: 2026-05-07
owner: alexostl
scope:
  - "bin/sage"
  - "tools/sage-claude-plugin/scripts/sage"
  - "runtime/platforms/codex/setup/tests/bin-sage-wiring.bats"
  - ".sage/work/20260507-framework-copy-boundary/*"
  - ".sage/decisions.md"
---

# Cycle: Framework copy boundary

## State

**Current phase:** complete — framework copy/update paths now use a filtered
distribution boundary instead of raw-copying active self-host project state.
**Next step:** optional follow-up: consider a packaging manifest or dirty
source warning if future evidence shows the blacklist is too implicit.

## Root Cause

`~/.sage/framework` intentionally points at the active
`/Users/alexostl/Developer/sage-selfhost` checkout. `bin/sage init/update`
then copies `SAGE_FRAMEWORK` into consumer `sage/` with raw `cp -a`, followed
by a narrow post-copy prune that removes only `.git`, `.github`, `.tmp`, and
`.DS_Store`. Because `sage-selfhost` now contains QA outputs under
`.sage/work/.../qa/run-*/target/sage`, every consumer framework copy can inherit
the project working state, including nested prior framework copies.

## Evidence

- The symlink workflow spec explicitly left `sage-update-prune-extended` as a
  follow-up and warned that `.sage/`, `.sage-memory/`, `.claude/`, and `.codex/`
  would currently be copied into consumers.
- All existing Codex QA run targets contain
  `target/sage/.sage/work/20260429-codex-port-rewrite/qa`.
- `sage-init.log` times increased from `2.4s` to `1115.6s` as nested QA run
  copies accumulated.

## Decisions

- Preserve the local symlink developer workflow; it is not the bug.
- Fix the distribution boundary used by `init` and `update`.
- Keep `selfhost` scope; do not edit consumer repositories in this cycle.
- Mirror the CLI fix in the Claude plugin script to avoid entrypoint drift.

## Open Questions

- Whether later upstream work should replace the blacklist with a formal
  packaging manifest. This cycle uses a focused fix.

## Verification

- `bash -n bin/sage`
- `bash -n tools/sage-claude-plugin/scripts/sage`
- `bats runtime/platforms/codex/setup/tests/bin-sage-wiring.bats` → 5/5
- `bats runtime/platforms/codex/setup/tests/stage10-tighten.bats` → 13/13
- Manual temp smoke: `bin/sage init --platform codex --preset base` followed
  by `bin/sage update`; copied `sage/` had no `.sage`, `.sage-memory`, or
  `runtime/mcp/node_modules`.
