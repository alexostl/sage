---
cycle_id: "20260509-target-repo-ownership-harness-fix"
title: "Fix: transcript assertion for target repo ownership"
workflow: fix
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-14
owner: alexostl
source_cycle: "20260509-runtime-process-dummy-qa"
needs-triage: true
priority: P2
folded_into: "20260510-language-invariant-workflow-matching-fix"
scope:
  - ".sage/work/20260509-target-repo-ownership-harness-fix/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/harness/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/lib/config-toml.sh"
  - "runtime/platforms/codex/setup/tests/**"
---

# Fix: transcript assertion for target repo ownership

## State

**Current phase:** completed — folded into Batch 5 anchor
`20260510-language-invariant-workflow-matching-fix`.

**Result:** Batch 5 potwierdził i zachował RealHarness assertion dla forbidden
parent/framework repo `.sage/**` transcript paths. Scenario
`11-bug-report-no-fix` nadal failuje, jeśli transcript wspomina parent repo
state write.

## Finding

Scenariusz `11-bug-report-no-fix` zakończył się poprawnym final state w target
repo, ale transkrypt pokazał transient repo-ownership drift: agent najpierw
próbował utworzyć intake manifest i decision w nadrzędnym
`/Users/alexostl/Developer/sage-selfhost`, potem sam wykrył błąd i przeniósł
stan do targetu.

## Candidate scope

- Dodać transcript-level assertion na forbidden absolute paths parent repo.
- Wzmocnić target repo ownership wording w generated Codex guidance, jeśli
  test pokaże, że instrukcja jest zbyt słaba.
- Zostawić `bug-report-no-fix` final-state assertion jako osobny pass, ale
  dodać warning/fail dla transient parent writes.

## Evidence

- QA report:
  `.sage/work/20260509-runtime-process-dummy-qa/qa-report.md`
- Transcript:
  `.sage/work/20260509-runtime-process-dummy-qa/run-20260509153121/transcripts/11-bug-report-no-fix.jsonl`
