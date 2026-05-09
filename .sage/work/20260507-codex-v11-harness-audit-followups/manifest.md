---
cycle_id: "20260507-codex-v11-harness-audit-followups"
title: "Codex v1.1 harness and audit follow-ups"
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
  - ".sage/work/20260507-codex-v11-harness-audit-followups/*"
  - ".sage/decisions.md"
  - "bin/sage"
  - "tools/sage-claude-plugin/scripts/sage"
  - "runtime/platforms/codex/harness/**"
  - "runtime/platforms/codex/hooks/**"
  - "runtime/platforms/codex/setup/tests/**"
---

# Cycle: Codex v1.1 harness and audit follow-ups

## State

**Current phase:** intake — actionable follow-ups captured from the Codex
operating model v1.1 final harness run. No implementation has started.

**Next step:** Resume with `/sage:fix` or `/continue`, triage which follow-ups
belong in one fix cycle versus separate cycles, then write the proper plan
before implementation.

## Context summary

Codex operating model v1.1 reached final checkpoint with deterministic tests
green and real Codex release-blocker harness evidence complete. The final
harness also exposed audit and metric issues that should not be hidden inside
the completed architecture cycle.

## Candidate work

- Fix or tighten decisions coupling for Capture Router intake: in the M6 real
  harness, `07-capture-router-minimal-intake` created
  `.sage/work/20260507-documentation-glossary-intake/manifest.md` without a
  same-commit `.sage/decisions.md` update. Desired outcome: intake/capture
  state changes have an explicit decision/checkpoint record, or the framework
  documents a narrower exception and tests it.
- Add semantic harness assertions beyond transcript success. Desired outcome:
  each release-blocker prompt verifies target state, not only `codex exec`
  exit code `0`; examples include read-only prompt leaves no workflow state,
  intake manifest contains `needs-triage`, safe auto-fix writes audit evidence,
  and cross-repo prompt names the target repo as state owner.
- Calibrate or replace `7_l1_bypass`: final harness reported `10/10` while
  `bypass_mutation` was `0`, suggesting the metric no longer matches current
  harness commit/log behavior.
- Decide whether `pre-tool-validate.sh` LOC ceiling should be raised,
  decomposed further, or turned into a promotion/refactor signal with a new
  threshold. Final harness reported `predicate_loc` `103/85`.
- Preserve the harness convention that test runs use `codex exec
  --ignore-user-config` so user-level settings such as
  `service_tier = "flex"` do not invalidate release evidence. This is a
  test-harness isolation rule, not a general instruction for normal agents.
- Tighten the framework copy boundary against historical QA recursion. A disk
  audit found nested copies under
  `.sage/work/20260429-codex-port-rewrite/qa/run-*/target/sage/.sage/...`.
  Desired outcome: `copy_framework_distribution` and post-copy prune coverage
  explicitly prevent `.sage/work/**/qa/run-*`, nested `target/sage`, and
  historical QA outputs from entering future consumer `sage/` copies; focused
  regression coverage should prove the boundary.
- Fix Codex Sage Memory fallback behavior. Codex sessions can expose
  `sage_memory_*` only through deferred tool discovery, while generated Codex
  guidance currently treats the v1 filesystem variant as the only path when no
  local `[[mcp_servers]]` block is present. Observed on 2026-05-07: fresh
  `lrn-*.md` fallback files appeared even though `tool_search` exposed
  `mcp__sage_memory__`, `sage_memory_set_project` activated
  `/Users/alexostl/Developer/sage-selfhost`, and MCP listed 73 project
  memories from `.sage-memory/memory.db`. Desired outcome: generated Codex
  guidance tries deferred `sage_memory` tool discovery and project activation
  before markdown fallback; no-local-`[[mcp_servers]]` is not treated as proof

## Folded status

Ten intake został wciągnięty do
`.sage/work/20260509-runtime-process-reliability-patch/`. Patch dodał semantic
harness assertion dla `bug-report-no-fix`, `forbidden_changed_patterns`,
memory discovery guidance bez zakładania lokalnego `[[mcp_servers]]` oraz
coverage dla resulting repository state w aggregate signals. Szersza
historyczna copy-boundary obserwacja zostaje pokryta jako harness/distribution
regression w ramach tego samego folded scope, bez osobnego aktywnego cyklu.
  MCP is impossible; regression coverage frames `.sage-memory/*.md` as last
  resort rather than the only v1 path.

## Evidence

- Source cycle:
  `.sage/work/20260507-codex-operating-model-v11/verification-map.md`
- Real harness report:
  `/var/folders/6m/187_m0kd4w51zh6s2x95d0t40000gn/T/codex-v11-harness.XXXXXX.YGI9atJNaO/report-after-exit-fix.json`
