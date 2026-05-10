# Learn: `sage-selfhost` Branch and Worktree Model

## Purpose

This note is the repository-operational contract for Git work in `sage-selfhost`.
Use it whenever a task touches branch roles, worktree placement, upstream sync,
or preparation of upstream PRs.

## Current Branch Roles

- `upstream/main`
  External source of truth from `xoai/sage`.
- `main`
  Manual fast-forward mirror of `upstream/main` on GitHub. No fork-specific
  commits. **GitHub default branch on `alexostl/sage`** — kept as default so
  the public repo page presents as a clean upstream mirror. Never merge
  self-host work into it; manually pick a different base when opening a PR.
- `codex-port`
  Shared integration branch on GitHub for Codex-port and other reusable fork
  changes that have not been fully upstreamed yet.
- `selfhost`
  Active branch for repository-specific self-host work. **Local
  `origin/HEAD` points here** so Claude Code Desktop, IDE diffs, and
  `git rev-parse origin/HEAD` use it as the comparison base. Base for
  self-host PRs.
- `upstream-fix-*`
  Temporary single-purpose branches created from fresh `upstream/main` only.

### Split-default convention

GitHub's default branch and the local `origin/HEAD` intentionally diverge:

- GitHub web (`alexostl/sage`) → `main` (clean upstream mirror facade)
- Local `refs/remotes/origin/HEAD` → `selfhost` (actual work trunk)

When opening a PR on GitHub web, the base auto-fills as `main` — **always
re-pick `selfhost` manually** unless the PR is genuinely an upstream
fast-forward of `main`. To re-sync the local pointer after a fresh clone:

```
git remote set-head origin selfhost
```

## Why `selfhost` Exists

The desired name `main/self-host-framework` was rejected because Git cannot
store both `main` and `main/...` refs at the same time. `selfhost` keeps
the semantic meaning while remaining compatible with a real `main` branch.

## Canonical Local Layout

- `/Users/alexostl/Developer/sage-selfhost`
  Primary worktree for `selfhost`
- `~/.codex/worktrees/sage-selfhost/upstream-fix-*`
  Temporary worktrees for small upstream fix branches
- `origin/main`
  Remote-only mirror of `upstream/main`; no resident local worktree.
- `/Users/alexostl/Developer/_worktrees/codex/sage-selfhost/codex-port`
  Separate resident worktree for `codex-port`.

Do not keep a resident local worktree for `main`. Its default home is GitHub
(`origin/main`) as the fork mirror of upstream. `codex-port` is allowed to keep
its separate resident worktree because it is a distinct integration surface.

## Update Chain

When upstream has moved, update branches in this order:

1. refresh `origin/main` to match `upstream/main`
2. update `origin/codex-port` against the refreshed `origin/main`
3. update local `selfhost` from the refreshed `codex-port`

This preserves a clear provenance chain and avoids treating stale integration
branches as if they were current upstream truth.

## Upstream PR Rules

For small shared fixes:

1. Start from fresh `upstream/main`
2. Create a dedicated temporary branch named `upstream-fix-*`
3. Keep the diff limited to the issue-specific fix
4. Open the PR against `xoai/sage:main`
5. Link the PR body to the relevant upstream issue with `Closes #N`

Do not open upstream PRs from `codex-port` or `selfhost`. Those branches
mix repository-local context with shared fixes and make review harder.

## Practical Checks Before Repo Git Work

- Is `origin/main` actually current with `upstream/main`?
- Is this change shared/fork-wide (`origin/codex-port`) or self-host-specific
  (`selfhost`)?
- Does this PR target `selfhost` (correct) and not `main` (which would
  poison the upstream mirror)?
- Do I really need a temporary local worktree for `main` or `codex-port`, or
  can this stay remote-only?
- If preparing an upstream PR, is the branch freshly recreated from
  `upstream/main`?

If any answer is "no" or "not sure", pause and fix the operating model first.
