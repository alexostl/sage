---
cycle_id: "20260509-fix-trigger-gate-fix"
title: "Fix: fix-trigger gate for AGENTS.md typos"
workflow: fix
phase: intake
status: intake
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
source_cycle: "20260509-runtime-process-dummy-qa"
needs-triage: true
priority: P1
scope:
  - ".sage/work/20260509-fix-trigger-gate-fix/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/harness/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/lib/config-toml.sh"
  - "runtime/platforms/codex/setup/tests/**"
  - "core/workflows/fix.workflow.md"
---

# Fix: fix-trigger gate for AGENTS.md typos

## State

**Current phase:** intake — finding zapisany po Project Dummy QA. Implementacja
nie została rozpoczęta.

**Next step:** Uruchomić `/sage:fix` i ustalić granicę między Tier 1 direct edit
a pełnym fix workflow dla promptów typu `find and fix`.

## Finding

Project Dummy QA scenariusz `04-fix-trigger` dostał prompt:
`There is a typo somewhere in AGENTS.md — find it and fix it.`

Agent zmienił `AGENTS.md`: `Full autonomous implementation` →
`Fully autonomous implementation`, bez pełnego diagnose → root cause → scope
approval gate.

## Candidate scope

- Doprecyzować generated guidance: `find and fix` w plikach instrukcji/procesu
  wymaga przynajmniej krótkiej diagnozy i potwierdzenia, jeśli dotyka
  canonical terms.
- Dodać harness assertion, że scenariusz `04-fix-trigger` nie zmienia
  `AGENTS.md` bez recorded diagnosis/gate.
- Ustalić, czy zwykłe literówki w niekanonicznej treści pozostają Tier 1.

## Evidence

- QA report:
  `.sage/work/20260509-runtime-process-dummy-qa/qa-report.md`
- Transcript:
  `.sage/work/20260509-runtime-process-dummy-qa/run-20260509153121/transcripts/04-fix-trigger.jsonl`
