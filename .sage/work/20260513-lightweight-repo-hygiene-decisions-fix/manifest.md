---
cycle_id: "20260513-lightweight-repo-hygiene-decisions-fix"
title: "Fix: lightweight repo hygiene should use decisions without manifest"
workflow: fix
phase: intake
status: intake
created: 2026-05-13
updated: 2026-05-13
owner: alexostl
priority: P2
tags:
  - repo-hygiene
  - closeout
  - workflow-threshold
  - decisions
  - gitignore
batch: "Batch 3 - Closeout, handoff i dokumentacja po końcu cyklu"
related:
  - ".sage/work/20260510-closeout-ordering-workflow-hook-fix/manifest.md"
  - ".sage/work/20260513-post-closeout-git-next-step-build/manifest.md"
  - ".sage/work/20260511-surgical-config-workflow-threshold-fix/manifest.md"
---

# Fix: lightweight repo hygiene should use decisions without manifest

## State

**Current phase:** intake - capture only. Implementacja nie została rozpoczęta.

**Next step:** W ramach Batcha 3 doprecyzować kontrakt: kiedy pojedyncza
oczywista zmiana repo hygiene, np. `.gitignore`, może zostać zapisana jako
krótki wpis w `.sage/decisions.md` bez tworzenia manifestu.

## Finding

Po Batchu 1 pojawiła się mała zmiana `.gitignore`: ignorowanie lokalnych
artefaktów `harness-run-*`. Merytorycznie była to repo hygiene poza zamkniętym
cyklem, ale hook wymusił mikro-manifest, bo `.gitignore` jest repo-control
file.

Alex doprecyzował preferowany model: takie oczywiste zmiany powinny być poza
dużym cyklem i zwykle bez osobnego manifestu, ale z widocznym wpisem w
`.sage/decisions.md`.

## Desired Behavior

Lightweight repo hygiene może przejść jako `decisions-only`, jeżeli:

- dotyka jednego niskiego ryzyka pliku repo hygiene, np. `.gitignore`;
- nie zmienia runtime, hooków, workflowów, testów, builda ani product behavior;
- nie obejmuje secrets, release packaging ani bezpieczeństwa;
- ma krótki wpis w `.sage/decisions.md` wyjaśniający powód i granicę;
- nie jest dopisywana do zamkniętego cyklu jako ukryty scope expansion.

Manifest nadal jest wymagany, gdy zmiana repo-control jest częścią większego
fixa/toolingu, dotyka ryzykownych zasad albo obejmuje kilka plików.

## Batch Routing

Ten intake należy do Batcha 3, bo dotyczy granicy po closeoucie: co agent może
jeszcze zrobić jako repo handoff/hygiene, jak to zakomunikować i jak uniknąć
epilogów dopisywanych do zamkniętego cyklu.
