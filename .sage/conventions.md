# Project Conventions

Discovered by Sage on 2026-04-21.
The codebase-scan capability will enrich this on first run.

## Git Branch And Worktree Conventions

- Treat `upstream/main` as external truth and `main` as a manual fast-forward
  mirror of it. Do not add fork-specific commits directly to `main`.
- Treat `codex-port` as the shared integration branch for reusable fork work.
- Treat `selfhost` as the active local branch for repository-specific
  self-host work.
- Keep this repository's main checkout dedicated to self-host work:
  - `/Users/alexostl/Developer/sage-selfhost` -> `selfhost`
- Keep `main` remote-first; do not keep a resident local worktree for it.
- Keep `codex-port` in its existing separate worktree:
  - `/Users/alexostl/Developer/_worktrees/codex/sage-selfhost/codex-port`
    -> `codex-port`
- Create temporary upstream-fix worktrees only under
  `~/.codex/worktrees/sage-selfhost/` and only from fresh `upstream/main`.
- Update branch layers in this order: sync `origin/main` from
  `upstream/main`, then update `codex-port`, then update `selfhost`.
- Recreate small upstream PR branches from current `upstream/main`; do not open
  upstream PRs directly from `codex-port` or `selfhost`.
