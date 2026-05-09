---
cycle_id: "20260507-codex-close-cycle-epilogue-fix"
title: "Codex close-cycle epilogue hook fix"
workflow: fix
phase: folded
status: completed
created: 2026-05-07
updated: 2026-05-09
owner: alexostl
source_cycle: "20260507-codex-operating-model-v11"
suggested_workflow: fix
needs-triage: true
folded_into: "20260509-runtime-process-reliability-patch"
scope:
  - ".sage/work/20260507-codex-close-cycle-epilogue-fix/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/hooks/**"
  - "runtime/platforms/codex/setup/tests/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "core/workflows/**"
---

# Cycle: Codex close-cycle epilogue hook fix

## State

**Current phase:** intake — follow-up captured after closing
`20260507-codex-operating-model-v11`. No implementation has started.

**Next step:** Resume with `/sage:fix` or `/continue`, diagnose the exact close
flow, then write a plan before changing hook behavior.

## Context summary

After the v1.1 cycle was approved, the agent changed the active manifest
frontmatter from `status: in-progress` to `status: completed`. That immediately
made `active_init_path` return no active cycle. A subsequent attempt to add a
final epilogue line to the same manifest was blocked by `pre-tool-validate.sh`
with `no active cycle`.

The hook behavior was internally consistent, but the UX exposes a close-cycle
edge case: final closeout often needs one last same-cycle documentation/state
mutation after the status flip. The framework should either make the status
flip the last required mutation by convention, or provide a narrow, safe,
audited epilogue allowance.

## Candidate work

- Define the desired close-cycle contract: either "status flip must be the last
  mutation" or "one same-cycle epilogue mutation is allowed after completion".
- If allowing epilogues, add a narrow safe predicate: same cycle only, manifest
  or decisions/QA report only, short time/window or same session if available,
  no implementation files, and durable audit evidence.
- Update generated `AGENTS.md` / workflow guidance so agents know the correct
  close order.
- Add deterministic tests for the observed failure:
  1. closing a cycle by changing manifest status to `completed`;
  2. attempting same-cycle epilogue mutation;
  3. ensuring cross-cycle or implementation mutations remain blocked.
- Keep this separate from the v1.1 completed cycle and from the broader harness
  audit follow-ups unless triage decides to merge them.

## Evidence

- Source cycle:
  `.sage/work/20260507-codex-operating-model-v11/manifest.md`
- Observed hook message:
  `Sage: no active cycle. Run /sage:build (or /sage:fix, /sage:architect) to start a workflow before mutating files.`

## Folded status

Ten intake został wciągnięty do
`.sage/work/20260509-runtime-process-reliability-patch/`. Patch dodał
close-cycle contract jako post-tool audit: status flip do `completed` jest
domyślnie final mutation, a późniejsze mutacje poza same-cycle artifact scope
zostają zapisane jako `post_completion_mutation` critical incident, chyba że
manifest ma jawny marker `closeout_epilogue`.
