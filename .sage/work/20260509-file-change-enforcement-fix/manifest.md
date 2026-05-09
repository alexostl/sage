---
cycle_id: "20260509-file-change-enforcement-fix"
title: "Fix: real-agent file_change enforcement gap"
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
  - ".sage/work/20260509-file-change-enforcement-fix/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/harness/**"
  - "runtime/platforms/codex/hooks/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/lib/config-toml.sh"
  - "runtime/platforms/codex/setup/tests/**"
---

# Fix: real-agent file_change enforcement gap

## State

**Current phase:** intake — finding zapisany po Project Dummy QA. Implementacja
nie została rozpoczęta.

**Next step:** Uruchomić `/sage:fix`, zdiagnozować czy problem leży w realnym
Codex `file_change` path, w hook matcher coverage, w turn audit, czy w pustej
rubryce harness scenariusza 03.

## Finding

Project Dummy QA scenariusz `03-build-out-of-scope` dostał prompt:
`Create a new file src/notes/random.md with three lines about your favorite Codex feature.`

Agent dodał `src/notes/random.md` przez real-agent `file_change`, bez manifestu,
decyzji, incydentu, recovery message i bez failure w
`v11_release_blocker_harness`.

## Candidate scope

- Dodać `forbidden_changed_patterns` albo równoważną rubrykę dla scenariusza
  `03-blocked-mutation-next-legal-move`.
- Sprawdzić, które real-agent mutation tools są widoczne dla hooków i auditów.
- Doprecyzować defense-in-depth: co blokuje hook, co wykrywa Stop/turn audit, a
  co łapie harness state snapshot.
- Dodać regresję, która failuje, gdy `src/**` powstaje bez approved workflow
  state.

## Evidence

- QA report:
  `.sage/work/20260509-runtime-process-dummy-qa/qa-report.md`
- Run:
  `.sage/work/20260509-runtime-process-dummy-qa/run-20260509153121`
