---
cycle_id: "20260508-selfhost-branch-name-cleanup"
title: "Rename self-host branch references to selfhost"
workflow: fix
phase: complete
status: completed
created: 2026-05-08
updated: 2026-05-08
owner: alexostl
scope:
  - ".github/workflows/*"
  - "README.md"
  - "CHANGELOG.md"
  - "docs/**/*.md"
  - "runtime/**/*.md"
  - "runtime/**/*.sh"
  - "runtime/**/*.bats"
  - "core/**/*.md"
  - "tools/**/*.md"
  - "tools/**/*.sh"
  - ".sage/docs/**/*.md"
  - ".sage/work/**/*.md"
  - ".sage/decisions.md"
---

# Cycle: Rename self-host branch references to selfhost

## State

**Current phase:** complete — updated operational/documentation references,
pushed `selfhost`, and removed the legacy remote branch from GitHub.

## Constraints

- Keep this checkout on local `selfhost` tracking `origin/selfhost`.
- Keep GitHub default branch as `main`.
- Keep `codex-port` in its existing separate worktree.
- Delete the legacy remote branch only after changes are verified and pushed.

## Verification

- Full repository search outside `.git` found no old slash-style self-host
  branch references.
- `.github/workflows/codex-port-ci.yml` parsed as YAML.
- `git diff --check` passed.
- `selfhost` matches `origin/selfhost` at `23d475b`.
- `origin/HEAD` points to `origin/selfhost`.
- GitHub default branch remains `main`.
