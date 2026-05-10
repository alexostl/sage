---
cycle_id: "20260422-sed-i-bsd-portability"
workflow: fix
phase: done
status: completed
created: 2026-04-22
updated: 2026-04-23
---

# Cycle: BSD sed -i Portability

## State

**Current phase:** done — fix landed in commit `702e867` and is shipping to
upstream via PR [xoai/sage#3](https://github.com/xoai/sage/pull/3).
**Next step:** watch the upstream PR for merge; no further local work.
**Artifacts:**
- plan.md: completed
- implementation: `bin/sage`, `runtime/platforms/claude-code/setup/generate-claude-code.sh`, `runtime/platforms/antigravity/setup/generate-antigravity.sh`
- quality-gates: root-cause review passed, fix scope approved, macOS verification completed by author

## Context Summary

This fix targets a macOS portability break in Sage shell scripts. The repo root
is already the framework, so the affected call sites live directly under
`bin/` and `runtime/platforms/`. Existing repo examples already use
`sed -i.bak`, so the chosen repair is to make the four remaining GNU-specific
sites consistent with that pattern without refactoring surrounding logic.
