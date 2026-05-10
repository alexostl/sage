---
cycle_id: "20260507-qa-matrioszka-cleanup"
title: "QA matrioszka cleanup"
workflow: fix
phase: complete
status: completed
created: 2026-05-07
updated: 2026-05-07
owner: alexostl
scope:
  - ".sage/work/20260507-qa-matrioszka-cleanup/*"
  - ".sage/work/20260507-codex-v11-harness-audit-followups/manifest.md"
  - ".sage/work/20260429-codex-port-rewrite/qa/**"
  - ".sage/decisions.md"
---

# Cycle: QA matrioszka cleanup

## State

**Current phase:** complete — generated QA run artifacts were removed after
explicit user approval, and the prevention fix was captured in the existing
open follow-up set.

## Scope

- Remove generated `.sage/work/20260429-codex-port-rewrite/qa/run-*` outputs.
- Preserve hand-authored QA runner/source files.
- Add the framework-copy regression follow-up to
  `20260507-codex-v11-harness-audit-followups`.

## Verification

- `find .sage/work/20260429-codex-port-rewrite/qa -maxdepth 1 -type d -name 'run-*' | wc -l` -> `0`
- `find .sage/work/20260429-codex-port-rewrite/qa -type d -name target | wc -l` -> `0`
- `du -sh . .sage .git .sage/work/20260429-codex-port-rewrite/qa` -> repo
  `50M`, `.sage` `2.6M`, `.git` `7.1M`, QA folder `8.0K`
