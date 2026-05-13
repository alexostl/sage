---
cycle_id: "20260510-closeout-ordering-workflow-hook-fix"
title: "Fix: closeout ordering guidance and hook recovery message"
workflow: fix
phase: completed
status: completed
created: 2026-05-10
updated: 2026-05-13
owner: alexostl
priority: medium
folded_into: "20260509-closeout-documentation-mutation-model"
tags:
  - needs-triage
  - closeout
  - workflow-guidance
  - hook-message
source: "User observed hook block after manifest was closed before plan/decision closeout edits"
evidence_threads:
  - "codex://threads/019e21ed-db84-7a82-96d8-d0239a431a19"
scope:
  - ".sage/work/20260510-closeout-ordering-workflow-hook-fix/*"
  - ".sage/decisions.md"
  - "core/workflows/*.workflow.md"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
---

# Fix: closeout ordering guidance and hook recovery message

## State

**Current phase:** completed - folded into Batch 3 anchor
`20260509-closeout-documentation-mutation-model`.

**Next step:** No separate implementation. The Batch 3 anchor covers closeout
ordering guidance and hook recovery wording.

## Problem

During closeout of `20260509-mutation-enforcement-target-safety-fix`, the agent
set `manifest.md` to `status: complete` before finishing all closeout artifact
edits. After that, `pre-tool-validate` correctly saw no active implementation
cycle and blocked a later `plan.md` closeout edit.

This exposed a workflow ergonomics gap: the correct closeout order is obvious
in hindsight, but not strongly encoded for agents.

## Additional evidence: same-turn closeout after missed self-review

Thread `codex://threads/019e21ed-db84-7a82-96d8-d0239a431a19` showed the same
ordering failure in a lightweight cycle. The agent marked
`.sage/work/20260513-projectinit-gitignore-whitelist/manifest.md` as
`status: completed` / `phase: verified`, then immediately noticed a misleading
comment in the changed `.gitignore` template. The cleanup patch was blocked
because no implementation cycle was active, and the attempted manifest reopen
was also blocked because the cycle had already been closed.

Preserve this as evidence that closeout guidance needs a final self-review
step before the manifest is closed. The manifest status change should be the
last mutation only after the agent has checked the diff for small wording,
scope, and verification-note corrections.

## Desired scope

This future fix should cover two related improvements:

1. **Universal workflow guidance**
   - Review all `core/workflows/*.workflow.md`, not only `fix.workflow.md`.
   - Add or normalize closeout guidance so every workflow says that final
     closeout artifacts, decisions, QA summaries, and plans should be updated
     before setting `manifest.md` to `status: complete`.
   - Make `manifest.status: complete` the last closeout mutation, preferably in
     the same final patch as the last artifact updates when practical.
   - Keep guidance compact and reusable, not a one-off note for this single
     incident.

2. **Better hook recovery message**
   - Improve `pre-tool-validate` messaging when a completed cycle appears to be
     blocking closeout artifact edits.
   - The message should explain the likely cause: manifest was closed before
     closeout artifacts were finished.
   - Prefer guidance over broad allowance. Do not weaken completed-cycle
     protection unless the implementation can prove a very narrow, safe
     closeout-only case.

## Acceptance criteria

- All workflows with completion/closeout language are reviewed.
- Closeout ordering is stated consistently across workflows.
- Hook block message is clearer for the "manifest closed too early" situation.
- Tests cover the improved hook message or narrow recovery behavior.
- The implementation first checks whether another recent fix already solved
  any part of this intake.

## Disclaimer

This intake is intentionally provisional. By the time it is picked up, the
issue may already be addressed by a broader workflow-closeout, active-cycle, or
hook-recovery fix. The first implementation step should verify current source
state before changing anything.
