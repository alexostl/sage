---
cycle_id: "20260509-manifest-completion-audit-capture"
title: "Manifest completion audit and Sage open/close findings"
workflow: fix
phase: folded
status: completed
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
needs-triage: true
folded_into: "20260509-runtime-process-reliability-patch"
source_threads:
  - "codex://threads/019e02ea-f313-7e10-aa5c-ace6271a881e"
  - "codex://threads/019e0986-9c21-7b53-99c8-0d86e9cf8165"
  - "codex://threads/019e088e-9a75-74f1-a6d3-40e75561ed2d"
  - "codex://threads/019e0c3b"
related:
  - ".sage/work/20260507-codex-operating-model-v11/manifest.md"
  - ".sage/work/20260507-codex-close-cycle-epilogue-fix/manifest.md"
  - ".sage/work/20260508-alex-native-operating-model/manifest.md"
  - ".sage/work/20260508-selfhost-branch-name-cleanup/manifest.md"
  - ".sage/work/20260507-codex-upstream-pr-prep/manifest.md"
---

# Cycle: Manifest completion audit and Sage open/close findings

## State

**Current phase:** intake — capture only. No implementation has started.

**Next step:** Fold this into the planned runtime/process reliability patch,
or resume as a focused `/sage:fix` if it should ship separately.

## Finding 1 — Final status audit trigger should be manifest completion only

**Decision candidate:** Add a lightweight final status audit that runs only
when an edit to `.sage/work/<cycle>/manifest.md` changes the cycle to
`status: completed` or `status: complete`.

**Do not trigger on:**

- every Codex `Stop`;
- every assistant response;
- ordinary commit/push;
- normal reads/status checks.

**Why:** Recent threads show that agents do not consistently use `sage close`
or `bin/sage-close`. The real recurring action is a manual manifest status
flip. Therefore enforcement should attach to the actual behavior, not to the
ideal close command.

**Minimum audit questions:**

- Does the manifest status change make `sage status` agree with the task
  reality?
- Are sibling workflow artifacts coherent enough for the workflow type
  (`plan.md`, and where relevant `brief.md`, `spec.md`, `qa-report.md`)?
- Is the status flip happening after final documentation/evidence, rather than
  before an epilogue that the hook will later block?
- If the cycle is intentionally not complete, should it be `paused` or
  `follow-up` instead of `completed`?

## Finding 2 — Sage Open is soft and sometimes ambiguous

In observed threads, "workflow open" did not always mean the same thing to the
agent, user, and hook runtime.

Observed deviations:

- Agent can talk as if a workflow is active while hook state depends only on an
  in-progress `manifest.md`.
- Parked `paused`/`intake` cycles can be treated as if they are active context
  unless the agent explicitly tells the user what is being resumed.
- `plan.md` may exist while manifest state still says `intake`/`paused`,
  creating ambiguous lifecycle meaning.

Desired direction:

- Sage Open should have a single observable act: create or resume one manifest
  as `status: in-progress`.
- The agent should state which cycle is active and why before mutating files.

## Folded status

Ten intake został wciągnięty do
`.sage/work/20260509-runtime-process-reliability-patch/`. Patch dodał
intent-aware cycle resolver jako observable open/selection model oraz
manifest-completion audit w `post-tool-check.sh`, który wykrywa status flip do
`completed` i zapisuje critical incident dla późnych mutacji poza dozwolonym
closeout context.
- Parked cycles remain context until explicitly resumed.

## Finding 3 — Sage Close is not consistently used

Representative evidence:

- `codex://threads/019e02ea-f313-7e10-aa5c-ace6271a881e`
  (`20260507-codex-operating-model-v11`): workflow was open, but no real
  `sage close` / `bin/sage-close` call was found in function calls. The cycle
  was closed by editing frontmatter to `status: completed`; after that, the
  hook blocked a final epilogue mutation as "no active cycle".
- `.sage/work/20260507-codex-close-cycle-epilogue-fix/manifest.md`: this intake
  was created specifically to capture the status-flip-before-epilogue failure.
- `codex://threads/019e0986-9c21-7b53-99c8-0d86e9cf8165`
  (`20260508-alex-native-operating-model`): workflow was open, but no close
  command was found. The cycle stayed `paused`/`follow-up`, which appears
  intentional after real-use findings.
- `codex://threads/019e088e-9a75-74f1-a6d3-40e75561ed2d`
  (`20260508-selfhost-branch-name-cleanup`): manifest and plan are completed,
  but no close command was found; status appears manually closed.
- `codex://threads/019e0c3b` / current cleanup of
  `20260507-codex-upstream-pr-prep`: stale active status was corrected
  manually after the fact, not through `sage close`.

Conclusion: `sage close` can remain a convenience path, but it cannot be the
only enforcement point. The crucial enforcement point is the manifest status
flip to complete/completed.

## Finding 4 — Current hook blocks capture-only updates when no cycle is active

On 2026-05-09, an attempt to append this finding to an existing intake manifest
was blocked because no cycle had `status: in-progress`; only parked
`paused`/`intake` work existed.

Question for the runtime patch: should explicit user-requested capture-only
updates to parked intake manifests be allowed through a narrow audited path, or
should every such capture require formally resuming/creating an in-progress
workflow first?

Current assessment: the block is correct for implementation changes, but too
strict for explicit capture-only documentation when the destination is a
parked intake manifest and the user directly asked to save the finding.
