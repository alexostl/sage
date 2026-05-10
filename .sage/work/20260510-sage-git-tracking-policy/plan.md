---
title: "Plan: Polityka Git dla artefaktow Sage i worktree"
workflow: fix
phase: plan-approved
status: approved
created: 2026-05-10
updated: 2026-05-10
cycle_id: "20260510-sage-git-tracking-policy"
---

# Plan: Polityka Git dla artefaktow Sage i worktree

## Cel

Przygotowac repo do zdrowego merge'u dokumentacji z wielu worktrees: dokumenty
Sage maja isc z PR, a lokalny runtime nie ma byc maskowany w `.sage/work`.

## Kroki

- [ ] Zmienic `.gitignore` wedlug zatwierdzonej uproszczonej polityki.
- [ ] Sprawdzic `git status --ignored`, czy nowe dokumenty `.sage/work` i
  `.sage/docs` sa widoczne.
- [ ] Zdjac z indeksu usuniete runtime pliki
  `.sage/work/20260509-runtime-process-dummy-qa/run-*`.
- [ ] Podac instrukcje dla pozostalych worktrees: wciagnac commit bazowy,
  dodac ich dokumentacje Sage, potem PR/merge.

## Zatwierdzona polityka

- Trackowane domyslnie: `.sage/docs/**`, `.sage/work/**`, `.sage/gates/**`,
  `.sage/scripts/**`, konfiguracja Sage w `.sage/*.yaml` / `.sage/*.md`.
- Ignorowane: `.sage-memory/`, lokalne logi i pliki stanu hookow.
- Runtime i sandboxi nie powinny powstawac w `.sage/work`; jesli powstana,
  Git ma je pokazac jako problem zamiast ukrywac przez `.gitignore`.

