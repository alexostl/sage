---
cycle_id: "20260514-claude-parity-decision-lifecycle-fix"
title: "Fix: Claude parity for Codex decision lifecycle"
workflow: fix
phase: intake
status: intake
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
needs-triage: true
priority: P2
source: "side conversation"
suggested_workflow: fix
related:
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/manifest.md"
  - "runtime/platforms/claude-code/setup/generate-claude-code.sh"
  - "runtime/platforms/claude-code/**"
  - "tools/sage-claude-plugin/**"
scope:
  - ".sage/work/20260514-claude-parity-decision-lifecycle-fix/*"
---

# Fix: Claude parity for Codex decision lifecycle

## State

**Current phase:** intake. Implementacja nie została rozpoczęta.

**Next step:** Parked. Wrócić do tego dopiero wtedy, gdy Alex będzie chciał
realnie używać Sage SelfHost w Claude Code albo Claude plugin surfaces.

## Finding

Milestone 1 dla `20260514-doc-lifecycle-bookkeeping-architecture` został
świadomie zawężony do Codex core. To oznacza, że Claude Code może nadal mieć
stare generated instruction surfaces dotyczące `.sage/decisions.md`, archive
rotation i process/checkpoint logging.

## Desired behavior

- Claude Code generated instructions mają być spójne z Codex decision lifecycle:
  `decisions.md` jako decision log, nie process log.
- Claude-specific surfaces nie powinny wymuszać global decision entry dla
  review verdicts, intermediate checkpoints, process-only frontmatter flips ani
  pure bookkeeping.
- Claude parity nie powinna rozszerzać ani blokować bieżącego cyklu Architect.
  To nie jest następny krok po Milestone 1, tylko niezależny przyszły fix.

## Candidate scope

- `runtime/platforms/claude-code/setup/generate-claude-code.sh`
- `runtime/platforms/claude-code/**`
- `tools/sage-claude-plugin/**`
- Claude-specific tests / generated output assertions.

## Boundary

Nie implementować w bieżącym cyklu Architect i nie traktować jako następny krok
po Milestone 1. Ten intake czeka niezależnie do momentu, w którym Claude Code
parity stanie się praktycznie potrzebne.
