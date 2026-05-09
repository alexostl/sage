---
cycle_id: "20260507-hook-hardblock-confirmation-capture"
title: "Capture hook hard-block soft-confirmation UX"
workflow: review
phase: folded
status: completed
created: 2026-05-07
updated: 2026-05-09
owner: alexostl
needs_triage: true
folded_into: "20260509-runtime-process-reliability-patch"
scope:
  - ".sage/work/20260507-hook-hardblock-confirmation-capture/*"
  - ".sage/work/20260507-codex-upstream-pr-prep/manifest.md"
---

# Cycle: Capture Hook Hard-Block Soft-Confirmation UX

## State

**Current phase:** intake - captured an observed Codex/Sage hook UX edge case
as material for a future review or patch. No hook behavior was changed.

## Finding

**Problem:** A hard `PreToolUse` scope/active-cycle block can leave the agent
unable to perform a user-requested capture even when the user explicitly wants
the action and the intended destination is known.

**Observed behavior:** While trying to move actionable review pointers into the
right intake manifest, the hook repeatedly reported an active cycle/scope that
did not match the agent's repo-local state check. The agent had to inspect hook
behavior and use repo-local patch execution to complete a documentation-only
capture.

**Why it matters:** The guardrail protects scope discipline, but in this edge
case it creates a brittle operator experience: the agent gets stuck debugging
the guardrail instead of asking the user for explicit confirmation and then
following a clear audited recovery route.

**Open question:** Which blocks should remain fail-closed, and which should
downgrade to a strong confirmation-required warning for documentation/intake
captures or user-approved scope redirection?

**Suggested review:** Evaluate `runtime/platforms/codex/hooks/pre-tool-validate.sh`,
active-cycle detection, and generated recovery guidance. Design a soft-confirm
path that tells the agent to stop, explain the mismatch to the user, ask for
confirmation, and then record the override/audit evidence before proceeding.

## Folded status

Ten intake został wciągnięty do
`.sage/work/20260509-runtime-process-reliability-patch/`. Patch nie dodaje
szerokiego soft-confirm override, tylko bezpieczniejszą wąską ścieżkę:
parked/intake capture jest dopuszczony tylko dla same-cycle `.sage/work`,
`.sage/decisions.md` i `.sage-memory/*.md`, a implementation paths nadal są
blokowane przez approved manifest scope.
