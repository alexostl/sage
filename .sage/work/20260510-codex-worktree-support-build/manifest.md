---
cycle_id: "20260510-codex-worktree-support-build"
title: "Build: obsluga worktree w porcie Codexa"
workflow: build
phase: intake
status: intake
created: 2026-05-10
updated: 2026-05-10
owner: alexostl
priority: high
scope:
  - ".sage/work/20260510-codex-worktree-support-build/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/**"
  - "core/workflows/**"
  - "bin/sage"
  - ".gitignore"
depends_on:
  - "20260510-sage-git-tracking-policy"
related:
  - "20260510-local-cluster-c-integration"
  - "20260510-local-cluster-d-integration"
  - "20260510-mutation-intent-preflight-gap"
excluded:
  - "SageMemory path/resolver repair"
  - ".sage-memory merge/import"
  - "cross-repo edits in alex-os-dev without explicit approval"
---

# Build: obsluga worktree w porcie Codexa

## State

**Current phase:** intake - wymagania Alexa zostaly zapisane jako input do
przyszlego cyklu build. Nie otwieramy jeszcze pelnego build-loop ani nie
implementujemy zmian.

**Next step:** Przy wejsciu w build przygotowac `spec.md`, ktory rozdzieli
role: agent w worktree, agent integrujacy w glownym repo, polityka Git/Sage
artifacts, inicjalizacja nowych worktree i automatyzacja merge workflow.

## Problem

Port Codexa zaczal realnie pracowac na wielu worktrees, ale Sage nie ma jeszcze
spojnego kontraktu dla takiej pracy. Czesciowo naprawiona zostala polityka
sledzenia `.sage` w Git, a lokalne integracje Klastrow C/D pokazaly dzialajacy
manualny rytual. Brakuje jednak funkcji i workflow, ktore prowadza agentow przez
ten model bez recznego wklejania procedury za kazdym razem.

## Cel

Wbudowac w port Codexa worktree-aware workflow dla pracy lokalnej:

- worktree agent konczy cykl commitem i handoffem;
- integrator laczy branch worktree lokalnie do `selfhost`;
- `origin/selfhost` pozostaje jedynym zrodlem prawdy;
- GitHub nie jest domyslnym etapem integracji klastrow roboczych;
- dokumentacja Sage idzie razem z kodem, a runtime junk zostaje poza Git;
- procedura jest dostepna jako natywny Sage/Codex workflow, nie jako ad hoc
  instrukcja od uzytkownika.

## Wymagania

### 1. Polityka Git i `.gitignore`

Uznac zakonczony cykl `20260510-sage-git-tracking-policy` za baseline:

- do Git wchodza `.sage/docs`, `.sage/work`, `.sage/decisions.md`, kod, testy,
  sensowne handoffy i QA reports;
- poza Git zostaja `.sage-memory`, logi, transcripty, runtime outputs,
  katalogi `run-*`, `target*`, `dummy-*`, pliki `.jsonl`, `.stderr`, `.exit`,
  `.state.json`, `.DS_Store`;
- przyszly build moze dodac walidatory/hooki, ktore wykrywaja runtime junk
  przed commitem/merge, ale nie powinien cofac gotowej polityki `.gitignore`.

### 2. Agent w worktree

Na koncu cyklu agent pracujacy w worktree powinien:

- zamknac aktywny proces Sage: manifest/plan/qa-report/handoff, statusy,
  wpisy w `.sage/decisions.md`;
- upewnic sie, ze pracuje na branchu `codex/<krotka-nazwa>` albo opisac
  nietypowy baseline/startowy commit w handoffie;
- posprzatac diff: commitowac kod, testy i dokumentacje Sage; nie commitowac
  runtime outputow, transcriptow, `.sage-memory` ani `.DS_Store`;
- odpalic sensowne testy dla swojego zakresu;
- zrobic lokalny commit na branchu worktree;
- przygotowac handoff: branch, commit SHA, zmiany, testy, ryzyka, nietypowy
  baseline.

### 3. Agent integrujacy w glownym repo

Integrator pracuje w glownym checkoutcie na `selfhost` i:

- synchronizuje lokalna prawde: `git fetch origin` oraz
  `git merge --ff-only origin/selfhost`;
- sprawdza branch worktree: istnienie, diff wzgledem `selfhost`, brak runtime
  junku;
- wykonuje lokalny merge: `git merge --no-ff --no-commit <branch-worktree>`;
- rozwiazuje konflikty:
  - `.sage/decisions.md` jako append-only union,
  - `.sage/work` jako merytoryczna unia dokumentow,
  - kod/testy zgodnie z aktualnym `selfhost` i intencja worktree;
- uruchamia targeted QA dla dotknietych obszarow;
- przy zmianach Codex/Sage runtime odpala takze setup/hooks/harness smoke;
- nie odpala pelnego RealHarness bez osobnej decyzji;
- robi merge commit na `selfhost`, pushuje `git push origin selfhost` i
  raportuje SHA, testy, konflikty, rozstrzygniecia oraz gotowosc repo na
  kolejny merge.

### 4. Inicjalizacja nowych worktree

Przyszly build powinien sprawdzic i zaprojektowac natywna konfiguracje/skrypty
inicjujace nowe worktree dla Codexa:

- branch naming: `codex/<krotka-nazwa>`;
- start z aktualnego `origin/selfhost`, chyba ze user jawnie wybierze inny
  baseline;
- poprawna polityka `.gitignore` i Sage artifacts od pierwszego commita;
- minimalny handoff template dostepny w worktree;
- jasna relacja do istniejacego zewnetrznego intake w `alex-os-dev`
  `20260510-new-worktree-initialization-script` bez edycji tamtego repo w tym
  cyklu.

### 5. Automatyzacja workflow Sage

Sage powinno miec procedure, ktora agent moze wywolac lub ktora jest naturalnie
podsuwana w closeout/integration:

- `worktree closeout` albo rownowazny krok dla agenta w worktree;
- `worktree integrate` albo rownowazny krok dla integratora w glownym repo;
- walidacja staged/merge diff pod katem runtime junku;
- template handoffu;
- raport koncowy integracji;
- recovery guidance dla konfliktow i nieczystych branchy.

## Boundary

SageMemory zostaje poza tym cyklem. Nie projektujemy tutaj naprawy
`.sage-memory`, resolvera memory ani importu/merge baz memory z worktree.

Nie kasujemy zakonczonego cyklu `20260510-sage-git-tracking-policy`; jest
zaleznoscia i baseline dla tego builda. Ewentualne przeniesienie lub polaczenie
zewnetrznego intake `alex-os-dev` wymaga osobnej zgody, bo to inny repo scope.

## Done When

- Spec opisuje worktree-aware storage/merge contract dla portu Codexa.
- Plan wskazuje konkretne pliki i testy do implementacji.
- Workflow prowadzi osobno agenta worktree i integratora.
- `.gitignore`/Sage artifact policy jest walidowana, nie tylko opisana.
- Lokalna integracja worktree do `selfhost` nie wymaga recznego wklejania
  procedury uzytkownika.
