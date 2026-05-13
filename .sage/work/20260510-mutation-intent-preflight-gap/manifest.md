---
cycle_id: "20260510-mutation-intent-preflight-gap"
title: "Fix: mutation-intent preflight gap before working tree mutations"
workflow: fix
phase: completed
status: completed
created: 2026-05-10
updated: 2026-05-13
owner: alexostl
priority: high
semantic_reclassification: accepted
tags:
  - needs-triage
  - codex-hooks
  - pre-tool-use
  - mutation-intent
  - conflict-resolution
  - agent-preflight
  - real-agent-transcript
source: "conversation"
source_thread: "codex://threads/019e0ec0-b0f4-7482-a92e-30ad16c33d3f"
evidence_threads:
  - "codex://threads/019e21ed-db84-7a82-96d8-d0239a431a19"
related:
  - ".sage/work/20260509-mutation-enforcement-target-safety-fix/manifest.md"
  - ".sage/work/20260509-file-change-enforcement-fix/manifest.md"
  - ".sage/work/20260509-binary-asset-mutation-contract-fix/manifest.md"
  - ".sage/work/20260509-blocking-hook-guidance-review/manifest.md"
  - ".sage/work/20260509-hook-block-recovery-behavior-fix/manifest.md"
  - ".sage/work/20260510-closeout-ordering-workflow-hook-fix/manifest.md"
  - ".sage/work/20260509-cycle-workflow-entry-enforcement-fix/manifest.md"
  - ".sage/work/20260512-hook-recovery-scope-amputation-fix/manifest.md"
scope:
  - ".sage/work/20260510-mutation-intent-preflight-gap/*"
  - ".sage/decisions.md"
  - "core/constitution/sage-process.constitution.md"
  - "core/capabilities/orchestration/sage-navigator/SKILL.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/lib/active_init.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
  - "runtime/platforms/codex/harness/prompts/13-mutation-preflight-lightweight.txt"
  - "runtime/platforms/codex/harness/prompts/14-hook-block-scope-amputation.txt"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
  - ".sage/work/20260509-file-change-enforcement-fix/manifest.md"
  - ".sage/work/20260509-binary-asset-mutation-contract-fix/manifest.md"
  - ".sage/work/20260512-hook-recovery-scope-amputation-fix/manifest.md"
  - ".sage/work/20260509-hook-block-recovery-behavior-fix/manifest.md"
  - ".sage/work/20260509-blocking-hook-guidance-review/manifest.md"
---

# Fix: mutation-intent preflight gap before working tree mutations

## State

**Current phase:** completed - implementacja i weryfikacja zaakceptowane.

**Next step:** Commit i push Batcha 2, potem przejść do Batcha 3.

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

## Additional evidence: thread `019e21ed`

Thread `codex://threads/019e21ed-db84-7a82-96d8-d0239a431a19` showed the same
class from the opposite side: `PreToolUse` blocked early enough to prevent
invalid writes, but the agent still learned the correct path by bouncing off
several blocks instead of doing a first-class preflight before tool use.

Observed block chain:

- first `apply_patch` was blocked because there was no active implementation
  cycle;
- the initial lightweight manifest used `scope_files`, so the hook saw only the
  default cycle scope and blocked source edits;
- after the manifest scope was fixed, the 3-file patch was blocked as
  Moderate+ work before approved artifacts;
- a temp-repo Bash verification was blocked as a mutating shell command whose
  exact paths could not be validated;
- after the agent closed the manifest, a small comment cleanup was blocked
  because there was no active implementation cycle;
- the attempted manifest reopen was also blocked because the cycle had already
  been closed.

Root-cause hypothesis to carry forward: the missing layer is not only hook
coverage. Sage needs an explicit mutation preflight contract that agents run
before `apply_patch` or mutating Bash: active cycle, claimed scope, file count,
workflow threshold, and closeout state. Hooks should remain the hard stop, but
normal operation should be guided before the stop is hit.

Important nuance from Alex: for a genuinely small/lightweight build, absence of
full `spec.md`/`plan.md` may be acceptable. The issue is the repeated
block-and-recover pattern, not necessarily that every tiny build must become a
full Standard+ workflow.

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
- Real-agent or harness coverage includes a lightweight task where the expected
  behavior is: run mutation preflight before the first patch, create/repair the
  minimal cycle shape if needed, and avoid repeated hook-driven recovery.

## Verification summary

See `verification.md`.

- Deterministic baseline passed before scope expansion:
  `pre-tool-validate.bats` 72/72, `stage3-agents-md.bats` 49/49,
  `aggregate-signals.bats` 16/16, JSON/shell syntax checks and
  `git diff --check`.
- Real harness completed all 14 scenarios once; after rubric tightening,
  re-aggregation on those real transcripts returned
  `v11_release_blocker_harness.complete=true`, `present=12`, `missing=[]`.
- Post-expansion targeted verification passed:
  `active_session_id` Bats filter 4/4, `inline scope.writable` Bats filter 1/1,
  `bash -n`, and targeted `git diff --check`.
