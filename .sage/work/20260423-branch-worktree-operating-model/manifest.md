---
cycle_id: "20260423-branch-worktree-operating-model"
workflow: architect
phase: deliver
status: complete
created: 2026-04-23
updated: 2026-04-23 10:34
---

# Cycle: Branch and Worktree Operating Model

## State

**Current phase:** complete — long-lived worktrees are established, `main` has
been synced to upstream, `codex-port` and `selfhost` have been integrated
forward, and both upstream issue fixes have fresh PRs from current upstream
truth.
**Next step:** review upstream PRs `xoai/sage#3` and `xoai/sage#4`, then decide
whether to promote this operating model into durable `.sage/docs/`.
**Artifacts:**
- brief.md: exists
- spec.md: exists
- plan.md: exists
- implementation: complete

## Context Summary

The repo had drifted into an ambiguous model where `main` was behind upstream,
`codex-port` was carrying shared changes, and `cap/self-host-framework` was the
practical working branch without a clear role boundary. The chosen design keeps
`main` as a manual fast-forward mirror of `upstream/main`, `codex-port` as the
shared integration branch, and a renamed local branch `selfhost` as the
active self-host work surface. Temporary upstream fix branches must be created
only from fresh `upstream/main`.

## Decisions So Far

- Do not use `main/self-host-framework`; Git ref naming conflicts with `main`.
- Keep one dedicated worktree per long-lived branch.
- Use merge-based integration for now instead of rebasing published branches.

## Open Questions

- Whether to push `selfhost` to origin after the local model stabilizes.
- Whether to promote this operating model into durable `.sage/docs/`.

## Handoff Guidance

If resumed, treat `/Users/alexostl/Developer/sage-codex` as the primary
`selfhost` worktree and the additional Codex-managed worktrees under
`~/.codex/worktrees/sage-codex/` as the canonical locations for `main`,
`codex-port`, and temporary upstream-fix branches.
