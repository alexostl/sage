---
title: "Fix: agent should recover after hook blocks instead of stopping"
status: intake
phase: intake
priority: high
created: 2026-05-09
updated: 2026-05-09
scope:
  - "AGENTS.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - ".sage/work/20260509-agent-resume-intake-cycle-fix/manifest.md"
  - ".sage/work/20260509-blocking-hook-guidance-review/manifest.md"
  - ".sage/decisions.md"
---

# Intake

## Problem

During this conversation, a PreToolUse hook blocked an attempted capture because
the patch shape was not legal. The agent reported the block and stopped instead
of correcting the action.

The expected behavior after a hook block is:

1. read the hook message as recovery guidance;
2. identify the next legal move named by the hook;
3. adjust the action shape, for example split the patch, resume the relevant
   cycle, or create a valid minimal intake;
4. retry through the legal path unless the hook indicates a hard stop that
   requires user choice.

## Why It Matters

Hook blocks are part of the runtime control loop, not an endpoint. If the agent
stops after a recoverable block, Sage loses the benefit of actionable hook
guidance and leaves the user to manually debug process mechanics.

This is especially important for capture-only actions. The first failed attempt
here tried to create a new intake plus `.sage/.auto-fixes.log`, which violated
the bootstrap shape. The correct recovery was to split the write into legal
patches: one new intake manifest plus `.sage/decisions.md` at a time.

## Candidate Fix

Add an explicit recovery contract for hook blocks:

- project instructions should say recoverable hook blocks must be acted on;
- hook messages should distinguish recoverable next steps from hard stops;
- tests should cover that minimal-intake bootstrap guidance is clear enough for
  an agent to correct the patch shape;
- if needed, merge or cross-link this with the existing resume-intake and
  blocking-hook-guidance follow-ups.

## Acceptance

- A recoverable hook block does not become a final answer by default.
- Agent guidance says to retry with a corrected legal action shape when the hook
  gives a next legal move.
- Hard stops still stop for user input when they involve scope expansion,
  destructive actions, conflicting instructions, or architecture decisions.
