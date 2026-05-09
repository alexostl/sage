---
cycle_id: "20260509-hook-cycle-selection-capture"
title: "Codex hook cycle selection and new-cycle bootstrap blocking"
workflow: fix
phase: folded
status: completed
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
needs-triage: true
folded_into: "20260509-runtime-process-reliability-patch"
related:
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/lib/active_init.sh"
  - "runtime/platforms/codex/hooks/lib/bootstrap_check.sh"
  - ".sage/work/20260508-agent-knowledge-architecture/manifest.md"
  - ".sage/work/20260509-pdf-ocr-skill/manifest.md"
---

# Cycle: Codex hook cycle selection and new-cycle bootstrap blocking

## State

**Current phase:** intake — capture only. No implementation has started.

**Next step:** Fold this into the runtime/process reliability patch. This is a
hook-behavior finding, not approval to patch hooks immediately.

## Finding — Active-cycle selection blocks legal new-cycle bootstrap

Alex reported a Codex/Sage thread where the user asked to continue rebuilding
the PDF skill as a new Sage Build task. The agent attempted to create:

- `.sage-memory/self-learning.md`
- `.sage/work/20260509-pdf-ocr-skill/manifest.md`
- `.sage/work/20260509-pdf-ocr-skill/spec.md`

The hook blocked the patch:

```text
Sage: BLOCKING outside cycle scope:
.sage-memory/self-learning.md
.sage/work/20260509-pdf-ocr-skill/manifest.md
.sage/work/20260509-pdf-ocr-skill/spec.md.
Active cycle: 20260508-agent-knowledge-architecture.
```

## Why this matters

The hook picked the newest existing `status: in-progress` cycle globally
(`20260508-agent-knowledge-architecture`) and treated its scope as the only
allowed write surface. That made a user-requested new workflow bootstrap look
like an out-of-scope mutation.

This is likely wrong for independent new work. A new worktree alone would not
solve it if `.sage/work/` is copied with active manifests, because
`active_init_path` reads state from the current worktree's `.sage/work`.

## Desired behavior

The hook should choose the relevant cycle from the patch intent before falling
back to newest active cycle:

- If a patch creates a new `.sage/work/<new-cycle>/manifest.md`, allow a
  narrow bootstrap path for that new cycle, even when another cycle is
  `in-progress`, as long as the patch only touches the new cycle bootstrap,
  `.sage/decisions.md`, and narrowly allowed learning/capture files.
- If a patch touches files under `.sage/work/<cycle>/`, prefer that cycle as
  the candidate context instead of blindly selecting the newest active cycle.
- If a patch touches implementation files, require an active/approved manifest
  whose scope includes those paths.
- If multiple cycles match, block and ask for explicit user-visible selection.

## Implementation note

The minimal suspected fix is to give `bootstrap_cycle_id` / path-intent
detection precedence before `active_init_path`, or to replace global
`active_init_path` selection with a candidate-cycle resolver that considers the
claimed patch paths first.

## Folded status

Ten intake został wciągnięty do
`.sage/work/20260509-runtime-process-reliability-patch/`. Patch dodał
`resolve_cycle_for_patch`, testy dla path-intent, bootstrap przy innym active
cycle, ambiguous multi-cycle block i parked-capture semantics.

## Related open question

This finding is separate from final status audit, but both point to the same
design gap: hook state should be derived from the actual attempted Sage
transition, not only from the newest active manifest on disk.
