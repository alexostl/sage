---
cycle_id: "20260510-sage-git-tracking-policy"
title: "Polityka Git dla artefaktow Sage i worktree"
workflow: fix
phase: plan-approved
status: in-progress
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
---

# Polityka Git dla artefaktow Sage i worktree

## State

**Current phase:** plan-approved - Alex zatwierdzil uproszczona polityke:
`.sage/docs` i `.sage/work` sa traktowane jako dokumentacja projektowa
wchodzaca do PR, a `.sage-memory` i lokalne logi/runtime state zostaja poza Git.

**Next step:** Zaktualizowac `.gitignore`, zdjac z indeksu stare runtime
transkrypty QA oraz przygotowac commit bazowy do merge/rebase w pozostalych
worktree branches.

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

