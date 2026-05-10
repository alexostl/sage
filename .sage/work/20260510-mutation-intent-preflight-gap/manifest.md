---
cycle_id: "20260510-mutation-intent-preflight-gap"
title: "Fix: mutation-intent preflight gap before working tree mutations"
workflow: fix
phase: intake
status: intake
created: 2026-05-10
updated: 2026-05-10
owner: alexostl
priority: high
tags:
  - needs-triage
  - codex-hooks
  - pre-tool-use
  - mutation-intent
  - conflict-resolution
source: "conversation"
source_thread: "codex://threads/019e0ec0-b0f4-7482-a92e-30ad16c33d3f"
related:
  - ".sage/work/20260509-mutation-enforcement-target-safety-fix/manifest.md"
  - ".sage/work/20260509-file-change-enforcement-fix/manifest.md"
  - ".sage/work/20260509-blocking-hook-guidance-review/manifest.md"
  - ".sage/work/20260510-closeout-ordering-workflow-hook-fix/manifest.md"
scope:
  - ".sage/work/20260510-mutation-intent-preflight-gap/*"
  - ".sage/decisions.md"
---

# Fix: mutation-intent preflight gap before working tree mutations

## State

**Current phase:** intake - captured as a future `/sage:fix` initiative.

**Next step:** Diagnose against recent real-agent transcripts and the latest
Bash hook fix before proposing implementation. Do not assume the fix is simply
"block git merge".

## Problem

Research on thread `019e0ec0-b0f4-7482-a92e-30ad16c33d3f` showed that
`PreToolUse` was pre only for the later `apply_patch`, not for the earlier
working-tree mutation. The agent first ran Bash/git operations (`mv`, then
`git merge origin/selfhost`) that changed the working tree and created merge
conflicts. Only afterward did `PreToolUse` block the attempted conflict
resolution as outside the active manifest scope.

This is a broader gap than "git merge bad": Sage currently lacks a reliable
preflight model for tool intents that can mutate the working tree before exact
paths are validated or before the agent has explicitly scoped the resulting
repair work.

## Research findings to preserve

- `PreToolUse` can correctly block a concrete `apply_patch` before that patch
  writes to disk.
- It can still be too late in the overall workflow if an earlier Bash/git/tool
  operation already dirtied the working tree.
- The recent Bash hook fix may improve simple shell mutations and recovery
  guidance, but there is not yet enough real-agent evidence that it addresses
  conflict-producing operations or other indirect mutations.
- The bug should be defined as a mutation-intent/preflight and scope-model
  problem, not narrowly as a Git problem.

## Desired diagnosis scope

Future implementation should first answer:

- Which real tool surfaces can mutate the working tree before path-level scope
  validation runs?
- Which cases are already covered by the current Bash hook fix?
- Which cases remain uncovered, such as merge/rebase/cherry-pick conflicts,
  generated files, cross-repo absolute paths, or native `file_change` behavior?
- What is the correct recovery model when the repo is already in conflict
  state and the only path forward is conflict resolution?

## Acceptance criteria

- Recent transcripts and real-agent harness evidence are reviewed, not only
  deterministic Bats.
- The issue is classified in terms of mutation intent and timing.
- The implementation does not overfit to `git merge` if the real class is
  broader.
- Any hook or guidance change includes real-agent evidence or a new scenario
  showing that agents are guided before wasting work on an invalid path.
