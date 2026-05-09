---
title: "Review: root cause runtime workflow enforcement hardening"
workflow: fix
cycle_id: "20260509-runtime-workflow-enforcement-hardening"
phase: root-cause-review
status: completed
created: 2026-05-09
updated: 2026-05-09
---

# Review: root cause runtime workflow enforcement hardening

VERDICT: PASS

## Critical

None.

## Major

None.

## Minor

1. Diagnoza powinna w planie doprecyzować, że `.codex/hooks/**` jest deployed
   surface dla aktywnego repo, a `runtime/platforms/codex/hooks/**` jest
   source-of-truth generatora. Fix musi zsynchronizować oba albo świadomie
   ograniczyć zmianę do source i uruchomić `bin/sage update`.
2. Plan powinien rozdzielić dwa podobne, ale różne pojęcia: `cross-cycle
   capture` oraz `gated same-cycle updates`. Oba są capture-only, ale mają inne
   owner rules.
3. Plan powinien jawnie zdecydować, czy `sage continue` staje się CLI aliasem,
   czy wszystkie komunikaty przechodzą na `sage:continue`/workflow activation.

## Review Notes

Evidence quality jest wystarczająca: diagnoza wskazuje konkretne pliki i
zachowanie (`active_init_path`, deployed/source hook drift, `bin/sage status`,
pusty harness rubric dla scenariusza 03 i QA report file_change bypass).

Diagnoza nie zatrzymuje się na symptomie. Root cause jest ujęty jako niespójny
contract między resolverem cyklu, klasyfikacją mutacji, recovery guidance i
harness enforcement.

Alternatywne wyjaśnienie "agent po prostu źle użył workflow" nie wystarcza:
aktywny hook realnie blokuje same-cycle root-cause update po checkpointcie i
podaje niewykonalny next move. To potwierdza, że problem jest systemowy.

Scope classification jako Systemic jest uczciwa: naprawa dotknie wielu
powierzchni i wymaga planu przed zmianami runtime.
