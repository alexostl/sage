---
cycle_id: "20260510-local-cluster-c-integration"
title: "Plan integracji lokalnej worktree Cluster C"
workflow: fix
phase: merge-resolution
status: approved
created: 2026-05-10
updated: 2026-05-10
owner: alexostl
approval: approved
---

# Plan integracji lokalnej worktree Cluster C

## Cel

Zintegrowac lokalnie branch `codex/cluster-c-realharness-fix` z `selfhost`
bez GitHub PR, zachowujac dokumentacje Sage i zmiany runtime, ale bez
przywracania starych runtime outputow z `.sage/work`.

## Kroki

1. Rozwiazac konflikty merge w `.sage/decisions.md`, manifeście follow-upu
   mutation enforcement, `run-harness.sh` i `stage4-config-toml.bats`.
2. Zachowac oba bloki decyzji, bo `.sage/decisions.md` jest append-only logiem.
3. Przyjac wydzielony parser logow Cluster C jako zrodlo prawdy dla harnessu.
4. Zachowac ostrzejsze testy braku `codex_hooks` w generated config.
5. Uruchomic targeted verification dla plikow dotknietych przez Cluster C.
6. Sprawdzic staged diff pod katem przypadkowych runtime outputow i transkryptow.
7. Zamknac lokalny cykl integracyjny, wykonac merge commit i wypchnac `selfhost`
   do `origin/selfhost`.
