---
cycle_id: "20260428-sage-init-hooks-ergonomics"
workflow: fix
phase: complete
status: complete
scope: standard
created: 2026-04-28
updated: 2026-04-28
---

# Cycle: bin/sage L5 cross-project ergonomics

## State

**Current phase:** verified — implementation complete, code review
APPROVE-WITH-NOTES, all 6 actionable issues folded in.
**Next step:** awaiting [A] from user on completion checkpoint.
**Artifacts:**
- fix-plan: completed (plan.md)
- implementation: 5 modified + 3 new test files
- verification: 65 tests green (was 53 before cycle)
- code review: APPROVE-WITH-NOTES (6 issues addressed in-place,
  1 perf nit deferred)
- self-test: bin/sage install-hooks wired sage-codex's own
  core.hooksPath = .githooks; live demo of hook firing on
  downstream-layout fixture passed

## Context Summary

Follow-up to `20260424-codex-enforcement-hybrid-levers` — that cycle
shipped L5 (`.githooks/pre-commit`) but the hook is dormant per-clone
(framework + downstream alike) because `bin/sage` has no install
mechanism and the hook itself hardcodes a path that breaks in
downstream projects.

Reviewer correction: copying hook 1:1 without path fix would BLOCK
every Standard+ commit (worse than dormant). Path resolution change
is mandatory part of the fix.

User context: junior dev, expects Sage to "just work" after install.
Manual `bin/sage-install-hooks` per clone is the wrong UX bar.

## Decisions So Far

- Auto-wire on init AND update (not just init — old projects need it
  too).
- Self-locating hook (search downstream path first, fallback to
  framework path) — NOT per-project templating, because update would
  clobber user edits.
- Don't overwrite existing user-edited hooks; print notice, skip.
- Don't clobber custom `core.hooksPath`; only set when unset or
  already `.githooks`.
- First-run nudge in `bin/sage` dispatcher, opt-out via env var.
- `bin/sage install-hooks` becomes the canonical command;
  `bin/sage-install-hooks` script delegates to it.

## Open Questions

- Whether `sage init` end-to-end test can drive the interactive flow
  non-interactively (resolved in plan: scope test to `ensure_hooks_wired`
  if not).

## Handoff Guidance

If resumed: read this manifest, then plan.md, then the root-cause
decision entry in `.sage/decisions.md` (2026-04-28). Do NOT change the
self-locating hook decision to per-project templating without
re-evaluating the `sage update` clobber risk.
