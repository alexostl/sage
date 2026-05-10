---
title: "Plan for Branch and Worktree Operating Model"
status: "completed"
created: "2026-04-23"
updated: "2026-04-23"
---

# Plan

## Milestone 1: Clean up temporary state

- Remove the stale upstream issue worktrees and their temporary branches
- Preserve only long-lived branches in dedicated worktrees

## Milestone 2: Establish long-lived worktrees

- Create a `main` worktree at `/Users/alexostl/Developer/sage-main`
- Rename or recreate the self-host branch locally as `selfhost`
- Move the current working tree onto `selfhost`
- Create a `codex-port` worktree at `/Users/alexostl/Developer/sage-port`

## Milestone 3: Rebuild branch chain

- Fast-forward `main` to `upstream/main` and push `origin/main`
- Merge the refreshed `main` into `codex-port`
- Merge the refreshed `codex-port` into `selfhost`

## Milestone 4: Recreate upstream PR branches

- Create fresh `upstream-fix-*` branches from current `upstream/main`
- Reapply the minimal patches for issues `#1` and `#2`
- Push and open upstream PRs linked to their issues

## Result

- `xoai/sage#3` opened from `alexostl:upstream-fix-sed-i-bsd`
- `xoai/sage#4` opened from `alexostl:upstream-fix-copy-framework`
