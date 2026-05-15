---
cycle_id: "20260515-sage-state-two-git-build"
title: "Build: osobny Git dla Sage state"
workflow: build
phase: intake
status: intake
created: 2026-05-15
updated: 2026-05-15
owner: alexostl
needs-triage: true
priority: low
source: "conversation"
suggested_workflow: build
related:
  - "20260510-sage-git-tracking-policy"
  - "20260510-codex-worktree-support-build"
  - "alex-os-dev devinit"
scope:
  - ".sage/work/20260515-sage-state-two-git-build/*"
  - ".sage/decisions.md"
  - ".gitignore"
  - "runtime/platforms/*/setup/**"
  - "runtime/platforms/*/hooks/**"
  - "runtime/platforms/*/harness/**"
  - "core/workflows/**"
  - "bin/sage"
---

# Build: osobny Git dla Sage state

## State

**Current phase:** intake. To jest niskopriorytetowy build do przyszlego
zaprojektowania i wdrozenia. Nie przygotowujemy jeszcze handoffow, nie
wdrazamy mechanizmu i nie zmieniamy `alex-os-dev` w tym cyklu.

**Recommended direction:** rozdzielic historie produktu i historie Sage state
na dwa tory Git:

- glowny Git repozytorium sledzi kod, testy, konfiguracje i normalna
  dokumentacje projektu;
- `.sage/` jest ignorowane przez glowny Git;
- `.sage/` ma wlasny Git / lokalny storage history, z merge obslugiwanym przez
  Git, a nie przez reczne skladanie plikow;
- push produktu nie moze przypadkiem wypchnac `.sage`;
- praca w wielu worktrees nadal musi miec merge historii Sage, ale w osobnym
  torze.

## Problem

Dotychczasowa polityka `20260510-sage-git-tracking-policy` uznala `.sage/docs`,
`.sage/work` i `.sage/decisions.md` za dokumentacje projektowa wchodzaca do
glownego Gita. To upraszczalo merge miedzy worktrees, ale miesza operacyjny
stan agenta z historia produktu i zmusza agenta do rozdzielania zmian Sage od
zmian source przy commitach/pushach.

Rozwazana alternatywa `.sage/` ignorowane per worktree bez wlasnego Gita jest
odrzucona: przy scalaniu worktrees robilaby reczny, trudniejszy od Gita merge
plikow dokumentacyjnych i grozilaby utrata historii pracy.

## Desired behavior

- Agent przy commicie/pushu produktu nie analizuje, ktore pliki `.sage` pasuja
  do ktorej zmiany source.
- Historia Sage istnieje i jest scalalna miedzy worktrees, ale nie jest czescia
  historii produktu.
- Dwa alternatywne worktrees moga miec osobne branche/attempty Sage state, a
  pozniejsza integracja uzywa zwyklych mechanizmow Gita dla konfliktow.
- `sage status`, `sage doctor`, setup/init i closeout jasno pokazuja oba tory:
  product Git oraz Sage-state Git.
- `alex-os-dev` dostaje osobny handoff/plan dopiero po ustaleniu kontraktu w
  Sage SelfHost.

## Candidate scope

- Zaprojektowac storage contract dla `.sage/` jako osobnego Gita:
  - gdzie fizycznie mieszka repo Sage state;
  - jak mapowac product branch/worktree na Sage branch/attempt;
  - jak robic snapshot, merge, restore i recovery;
  - jak uniknac przypadkowego remote pushu Sage state.
- Zmienic init/update/gitignore policy tak, zeby nowe dev projekty nie
  traktowaly `.sage/` jako czesci product history.
- Dodac diagnostyke dla rozjazdu product Git vs Sage-state Git.
- Przemyslec migracje istniejacych repozytoriow:
  - `sage-selfhost` jako source-of-truth mechanizmu;
  - `alex-os-dev` jako konsument/devinit dogfood;
  - bez cross-repo writes bez osobnej zgody Alexa.
- Zaktualizowac `20260510-codex-worktree-support-build` albo zastapic jego
  zalozenia, bo obecnie zalezy od starej polityki commitowania `.sage` w
  glownym Gicie.

## Out of scope for intake

- Brak wdrozenia w tej turze.
- Brak handoffu do `alex-os-dev` w tej turze.
- Brak edycji `alex-os-dev` w tej turze.
- Brak migracji aktualnych `.sage` artifacts w tej turze.

## Notes from discussion

Senior-developer framing: nie mieszac operational state z product history.
Jesli historia i merge Sage state sa potrzebne, drugi Git jest lepszy niz
ignorowane per-worktree pliki bez historii. Aktualna ocena rozmowy: dwa Gity sa
lepsze od obecnego modelu pod wzgledem czystosci product history, push safety i
prostoty mentalnej agenta, ale wymagaja dobrego toolingu, inaczej przewaga
spada.
