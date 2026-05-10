---
cycle_id: "20260510-sage-git-tracking-policy"
title: "Polityka Git dla artefaktow Sage i worktree"
workflow: fix
phase: completed
status: completed
created: 2026-05-10
updated: 2026-05-10
owner: alexostl
priority: high
semantic_reclassification: accepted
plan_approval: approved
scope:
  - ".sage/work/20260510-sage-git-tracking-policy/*"
  - ".sage/decisions.md"
  - ".gitignore"
  - ".sage/work/20260508-alex-native-operating-model/*"
  - ".sage/work/20260509-runtime-process-dummy-qa/*"
  - "runtime/platforms/codex/harness/lib/aggregate-signals.sh"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - "runtime/platforms/codex/setup/lib/hooks-deploy.sh"
  - "runtime/platforms/codex/setup/tests/stage5-6-hooks.bats"
---

# Polityka Git dla artefaktow Sage i worktree

## State

**Current phase:** completed - Alex zatwierdzil uproszczona polityke:
`.sage/docs` i `.sage/work` sa traktowane jako dokumentacja projektowa
wchodzaca do PR, a `.sage-memory` i lokalne logi/runtime state zostaja poza Git.

**Next step:** Brak w tym cyklu. Polityka zostala wdrozona i wypchnieta do
`origin/selfhost`; dalsze worktree sa integrowane lokalnie w osobnych cyklach
handoff/integration.

**Merge resolution addendum:** Podczas integrowania `origin/selfhost` z branchem
Klastra B scope tymczasowo obejmuje pliki runtime/harness z konfliktami merge.
Cel nie jest nowy feature work, tylko zachowanie obu stron: baseline policy z
`origin/selfhost` oraz zmian Klastra B w jednym poprawnym merge commit.

## Problem

Repo bylo w stanie posrednim: `.gitignore` ignorowal cale `.sage/`, ale czesc
plikow `.sage` byla juz sledzona w indeksie. Przy wielu worktrees powoduje to
ryzyko, ze PR przeniesie kod bez aktualnej dokumentacji pracy.

## Zakres

- Uproscic `.gitignore`: nie ignorowac calego `.sage/`.
- Ignorowac tylko lokalne/runtime elementy Sage: `.sage-memory/`, logi,
  pending/cursor state i `.DS_Store`.
- Pozostawic `.sage/docs` i `.sage/work` jako naturalnie sledzone przez Git.
- Usunac z indeksu stare transkrypty/run artefakty, ktore zostaly juz usuniete z
  drzewa roboczego.
