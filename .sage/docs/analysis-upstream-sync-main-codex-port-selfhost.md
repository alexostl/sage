# Analysis: `main` -> `codex-port` -> `selfhost`

## Scope

Custom analysis of the upstream sync chain after:

1. `main` was fast-forwarded to `upstream/main`
2. `codex-port` merged refreshed `main`
3. `selfhost` merged refreshed `codex-port`

This analysis evaluates impact, overlap areas, and validation risk. It is not a
PR review.

## Evidence Reviewed

- `git diff --stat main..codex-port`
- `git diff --stat codex-port..selfhost`
- overlapping diffs in:
  - `bin/sage`
  - `runtime/platforms/claude-code/setup/generate-claude-code.sh`
  - `runtime/platforms/antigravity/setup/generate-antigravity.sh`
  - `runtime/platforms/codex/setup/generate-codex.sh`
  - `tools/sage-claude-plugin/scripts/sage`
- commit history for:
  - `main..codex-port`
  - `codex-port..selfhost`

## Findings

### Major

1. **Discovery happened after branch mutation, not before**
   Evidence: the branch chain was already updated before this analysis began,
   and the architect cycle itself concluded that impact discovery should have
   preceded the sync. This means we lost the cleaner "pre-integration" decision
   point and now can only do retrospective impact analysis plus post-sync QA.
   Recommendation: make "analyze upstream delta before branch sync" a mandatory
   repo-operation rule.

2. **`codex-port` now combines large upstream changes with local adapter and CLI changes in the same high-risk files**
   Evidence: `main..codex-port` touches 40 files with 3644 insertions / 805
   deletions, and the overlap includes `bin/sage`, both Claude/Antigravity
   generator scripts, and Codex adapter surfaces. These are exactly the files
   where local fixes and platform-port logic coexist.
   Recommendation: prioritize regression verification for CLI init/update,
   Codex adapter generation, and MCP runtime before treating the sync as stable.

### Minor

1. **`selfhost` adds branch-local self-host behavior on top of an already refreshed integration branch**
   Evidence: `codex-port..selfhost` changes `bin/sage`,
   `generate-codex.sh`, README/CONTRIBUTING guidance, and removes the public
   handoff file while adding self-host entrypoints (`--self-host`,
   `SAGE_FRAMEWORK_DIR`, framework-repo detection). The overlap is compact but
   operationally sensitive.
   Recommendation: run a dedicated self-host smoke flow in an isolated temp
   worktree, not just generic codex-port regressions.

2. **Public/fork branch status can be mistaken for compatibility status**
   Evidence: after the sync, GitHub shows `behind 0` for `codex-port` and
   `selfhost`, but that only proves commit ancestry, not behavior.
   Recommendation: track "validated after upstream sync" as a separate concept
   from ahead/behind state in future repo operations.

## Severity Summary

- Critical: 0
- Major: 2
- Minor: 2

## Top Priority

Run fresh regression and smoke verification for:

1. `codex-port` CLI/Codex/MCP paths
2. `selfhost` self-host init/update behavior

The sync is topologically complete but not yet behaviorally validated.

## Conclusion

No code-level incompatibility is proven yet from static analysis alone, but the
sync crossed enough overlapping runtime surfaces that QA is mandatory before the
updated branch chain should be treated as stable.
