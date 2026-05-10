# Analysis: `selfhost` Post-Symlink Incident Audit

> **Note (2026-04-28):** Project was renamed `sage-codex` → `sage-selfhost`.
> References below preserved verbatim from when this document was written.

## Scope

Audit of repository state after the attempted developer workflow that pointed
`~/.sage/framework` at `/Users/alexostl/Developer/sage-codex`, followed by the
rollback and emergency `.git` reconstruction.

## Evidence Summary

- Local `HEAD` matches `origin/selfhost` at commit
  `b8e00da5bdc89ae03271285a986f91928ba7848e`.
- Working tree is not clean relative to that commit.
- Four tracked `.github` files are missing from the working tree.
- The original `.git` directory was deleted and replaced with a freshly
  initialized local Git directory pointed at the same commit.
- The reconstructed `.git` is internally consistent enough for `status`,
  `show`, `fsck`, and `worktree list`, but it no longer contains the original
  local reflog/history context.

## Findings

### Critical

1. Local Git metadata was destroyed and only partially reconstructed.

Evidence:
- `.git/logs/HEAD` contains only two fresh entries from the recovery.
- `.git/logs/refs/heads/selfhost` contains only a single creation entry.
- `git branch -vv` shows only `selfhost`.
- `git branch -r` shows only `origin/selfhost`.

Impact:
- The current checkout is functional, but it is not provably equivalent to the
  pre-incident local repo administration.
- Any prior reflog history, local-only branches, unpublished refs, stash
  metadata, hook customizations, or worktree administration that existed only
  in the deleted `.git` is gone unless it still exists elsewhere.

Assessment:
- This is the highest-risk residual because it affects recoverability and local
  repo provenance, not just working tree contents.

### Major

2. Four tracked repository files are currently missing from the working tree.

Evidence:
- `git diff --name-status origin/selfhost --` shows:
  - `.github/ISSUE_TEMPLATE/bug_report.md`
  - `.github/ISSUE_TEMPLATE/feature_request.md`
  - `.github/ISSUE_TEMPLATE/skill_request.md`
  - `.github/REPO_SETUP.md`
- `git show HEAD:<path>` succeeds for representative missing files, so they are
  restorable from the current commit.

Impact:
- The checkout is not working-tree-equivalent to `origin/selfhost`.
- Any workflow depending on these GitHub templates/docs will see a damaged
  tree until they are restored.

Assessment:
- This is concrete filesystem damage with a straightforward repair path.

### Minor

3. Untracked local outputs exist, but they do not currently look like the main
incident damage.

Evidence:
- Untracked: `.agents/`, `.codex/`, `AGENTS.md`,
  `CODEX_FRAMEWORK_COMPLIANCE_REPORT_019dbe38.md`.
- `AGENTS.md` and the compliance report have recent mtimes from today.
- `.agents/` and `.codex/` have earlier mtimes (`2026-04-22` and
  `2026-04-21`), suggesting they predate the incident.

Impact:
- These add noise to status output, but they are not the primary correctness
  risk compared with missing tracked files and lost Git admin history.

Assessment:
- Treat as separate cleanup/audit work, not as the core incident damage.

## What Is Healthy

- `git fsck --full --no-dangling` passes.
- `git worktree list --porcelain` reports a valid worktree at
  `/Users/alexostl/Developer/sage-codex`.
- The current commit content is available locally; missing tracked files can be
  restored directly from `HEAD`.

## Recommended Repair Order

1. Restore the four missing tracked `.github` files from `HEAD`.
2. Audit whether any important local-only Git state existed before the
   incident:
   - unpublished local branches
   - stashes
   - custom hooks
   - extra worktrees
   - local config beyond remotes/branch tracking
3. Only after that, decide whether to clean untracked outputs such as
   `AGENTS.md`, `.agents/`, `.codex/`, and the compliance report.

## Bottom Line

The checkout is not catastrophically unreadable anymore, but it is also not a
clean 1:1 recovery of the previous local repository state. The concrete tree
damage is small and repairable (four missing tracked files). The bigger
residual risk is that the original `.git` administrative history was deleted,
so some local-only Git context may be permanently lost.

## Resolution Applied

After this audit:

- remote-tracking refs were repopulated from GitHub via `git fetch --all --tags --prune`
- the four missing tracked `.github` files were restored from `HEAD`
- `git diff --stat origin/selfhost --` is now empty
- `git fsck --full --no-dangling` passes

Residual state intentionally left untouched:

- untracked local outputs in `.agents/`
- untracked local `.codex/`
- untracked `AGENTS.md`
- untracked `CODEX_FRAMEWORK_COMPLIANCE_REPORT_019dbe38.md`

These no longer look like active incident damage. They remain local cleanup
decisions, not required integrity repairs.
