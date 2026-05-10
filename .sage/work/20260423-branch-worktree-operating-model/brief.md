---
title: "Brief for Branch and Worktree Operating Model"
status: "completed"
created: "2026-04-23"
updated: "2026-04-23"
---

# Vision

This repository needs a predictable branch and worktree model so day-to-day
work, shared integration, and upstream contributions stop bleeding into each
other. The user wants the self-host capability branch to be the practical main
working surface, while shared and upstream-targeted work remain isolated and
easy to reason about.

Success looks like:

- one obvious local worktree for active self-host work
- one separate worktree for the shared Codex-port integration branch
- one separate worktree for a clean fork/upstream mirror branch
- temporary upstream-fix worktrees created only when needed
- a simple update chain from upstream -> fork mirror -> integration -> self-host

# Constraints

- `upstream/main` is already 5 commits ahead of the fork's `main`
- `codex-port` contains shared integration work and should not be the daily
  self-host worktree
- `cap/self-host-framework` carries repository-specific self-host changes and
  should become the practical source of truth for local work
- Git cannot have both a local `main` branch and a local `main/...` branch, so
  `main/self-host-framework` is not a valid coexistence naming scheme
- upstream PRs for small shared fixes must be recreated from fresh
  `upstream/main`, not from the long-lived integration branches

# Gaps

- Whether the user eventually wants to publish a remote self-host branch or keep
  it local-only for now
- Whether the longer-term relationship between `codex-port` and self-host work
  should remain merge-based or later be cleaned up via rebase once the model is
  stable
- Whether branch/worktree operating rules should be promoted from `.sage/work/`
  into a durable `.sage/docs/` note after this reorganization succeeds
