---
title: "Spec for Branch and Worktree Operating Model"
status: "completed"
created: "2026-04-23"
updated: "2026-04-23"
handoff: |
  Key decisions: keep fork main as a fast-forward mirror of upstream/main;
  keep codex-port as the shared integration branch in its own worktree; use
  selfhost as the active local self-host branch name because main/... is
  invalid alongside main; rebuild upstream issue branches only from fresh
  upstream/main.
  Open questions: whether to publish selfhost remotely and whether to
  promote this operating model into durable docs.
  Risks: merge conflicts while bringing upstream/main into codex-port and then
  codex-port into the self-host branch.
  Next agent should: create worktrees, sync main, integrate codex-port, then
  rebuild the upstream PR branches from fresh upstream/main.
---

# Design

## Branch roles

- `main`
  Fast-forward mirror of `upstream/main`. No fork-specific commits.
- `codex-port`
  Shared integration branch for Codex-port and other reusable fixes not yet
  upstreamed.
- `selfhost`
  Active local branch for repository-specific self-host work. This is a local
  alias/continuation of the previous `cap/self-host-framework` line because
  `main/self-host-framework` cannot coexist with `main`.
- `upstream-fix-*`
  Temporary, single-purpose branches created from fresh `upstream/main` only
  when preparing isolated upstream PRs.

## Worktree roles

- `/Users/alexostl/Developer/sage-codex`
  Primary self-host worktree on `selfhost`
- `/Users/alexostl/Developer/sage-port`
  Shared integration worktree on `codex-port`
- `/Users/alexostl/Developer/sage-main`
  Clean fork mirror worktree on `main`
- `/Users/alexostl/Developer/sage-upstream-*`
  Temporary issue/PR worktrees only; safe to delete and recreate

## Update chain

1. Sync `main` to `upstream/main`
2. Update `codex-port` from the refreshed `main`
3. Update `selfhost` from the refreshed `codex-port`
4. Create isolated upstream-fix branches from current `upstream/main` as needed

## Trade-offs

- Manual sync is acceptable because it keeps shared and self-host concerns
  explicit instead of hiding them behind implicit rebases.
- Merge-based updates are preferred for now because they minimize history
  rewriting while the branch model is still stabilizing.
- Keeping a dedicated `main` worktree costs one extra checkout, but it makes it
  much easier to see what is upstream truth versus fork-specific work.
