---
cycle_id: "20260507-sage-wiki-upstream-update"
title: "Review findings: Sage Wiki workflow and bootstrap UX"
type: review-findings
status: captured
created: 2026-05-07
---

# Review Findings: Sage Wiki Workflow And Bootstrap UX

## Finding 1 - Operator action escape hatch during active workflow

**Problem:** During an active Sage Wiki workflow in `alex-os-dev`, the user
asked for installation of a newer `sage-wiki` from upstream `main`. The agent
performed the install immediately, effectively stepping outside the formal
workflow/checkpoint path.

**Observed behavior:** The action may be legitimate as operator
action/runtime maintenance, but the agent did not first make an explicit
state transition, pause, or checkpoint update for the active workflow.

**Why it matters:** Users need a clear "do this now" path for urgent runtime
maintenance inside a long-running analysis, without teaching agents that an
active Sage workflow can be silently bypassed whenever a direct command appears.

**Open question:** Should Sage define a formal operator-action lane inside the
current cycle, or should agents first record/pause/update cycle state before
executing mid-workflow maintenance?

**Suggested review:** Inspect Sage routing guidance, workflow state
transitions, and Codex hook UX for direct action mandates that arrive during
active workflows. Look for the smallest explicit checkpoint or state note that
preserves user agency while keeping the active workflow honest.

## Finding 2 - Legal analyze bootstrap path is not obvious

**Problem:** The Sage `PreToolUse` hook correctly blocked an analysis artifact
write because there was no active cycle. The agent then had to inspect hook
behavior and bootstrap a minimal cycle before saving the approved analysis.

**Observed behavior:** The guardrail behaved defensibly, but the legal
`/analyze` workflow did not make the first manifest/bootstrap route obvious
before the first durable write.

**Why it matters:** A correct block can still be a UX bug if legal workflow
entry requires reverse-engineering hook internals. Agents may stall, broaden
exceptions too far, or create inconsistent bootstrap patterns.

**Open question:** Should `/analyze` create a minimal active manifest as part
of entry, should the hook present a deterministic recovery path, or should both
be true?

**Suggested review:** Compare `core/workflows/analyze.workflow.md`, generated
Codex workflow guidance, and `runtime/platforms/codex/hooks` bootstrap checks.
Define the intended legal sequence and add regression coverage for first-write
analysis artifact creation.
