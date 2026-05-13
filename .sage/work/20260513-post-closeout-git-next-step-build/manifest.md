---
cycle_id: "20260513-post-closeout-git-next-step-build"
title: "Build: agent pyta po closeout o stage, commit i push"
workflow: build
phase: completed
status: completed
created: 2026-05-13
updated: 2026-05-13
owner: alexostl
priority: P2
folded_into: "20260509-closeout-documentation-mutation-model"
source: "User requested this as a future initiative, not as memory"
tags:
  - closeout
  - git
  - commit
  - push
batch: "Batch 3 - Closeout, handoff i dokumentacja po końcu cyklu"
related:
  - ".sage/work/20260509-closeout-documentation-mutation-model/manifest.md"
  - ".sage/work/20260510-closeout-ordering-workflow-hook-fix/manifest.md"
  - ".sage/work/20260510-post-closeout-handoff-doc-mutation-fix/manifest.md"
  - ".sage/work/20260509-open-work-cluster-map/cluster-map.md"
scope:
  - ".sage/work/20260513-post-closeout-git-next-step-build/*"
---

# Build: agent pyta po closeout o stage, commit i push

## Folded Into Batch 3

Ten intake został skonsumowany przez anchor cycle
`20260509-closeout-documentation-mutation-model`. Historyczne wording
`stage/commit/push` jest superseded: Batch 3 implementuje `stage/commit` i
pytanie o handoff bez domyślnego `push`.

## Problem

Po zamknięciu cyklu Sage agent potrafi zakończyć odpowiedź bez jasnego
następnego kroku git. W efekcie Alex musi dopytać, czy był stage, commit i
push, albo pamiętać o tym ręcznie.

## Desired Outcome

Po finalnym closeout cyklu agent powinien jasno powiedzieć, czy stage, commit i
push były wykonane, oraz zapytać, czy ma teraz wykonać git handoff dla zmian
tego cyklu.

## Scope Idea

Do ustalenia w formalnym build/fix:

- gdzie najlepiej dodać guidance: workflow closeout, generated AGENTS.md,
  status/continue, czy osobny closeout helper;
- jak odróżnić pliki bieżącego cyklu od wcześniejszych niepowiązanych zmian w
  dirty working tree;
- czy pytanie ma obejmować tylko `stage + commit`, czy także `push`, gdy branch
  ma remote;
- jakie testy/harness mają potwierdzać zachowanie.

## Boundary

To jest intake/capture-only. Nie wdrażamy teraz zachowania w runtime ani
workflowach.

## Batch Attachment

Ten intake należy do Batch 3: `Closeout, handoff i dokumentacja po końcu
cyklu`. Dotyczy końcowego kroku po closeoucie: agent ma jasno powiedzieć, czy
stage/commit/push zostały wykonane, i zapytać o git handoff dla zmian bieżącego
cyklu.
