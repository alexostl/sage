---
cycle_id: "20260515-cross-repo-sagedocs-permission-fix"
title: "Fix: cross-repo writes only for SageDocs without explicit approval"
workflow: fix
phase: intake
status: intake
created: 2026-05-15
updated: 2026-05-15
owner: alexostl
needs-triage: true
priority: P1
source: "conversation"
suggested_workflow: fix
related:
  - "20260509-mutation-enforcement-target-safety-fix"
  - "20260509-target-repo-ownership-harness-fix"
  - "20260515-hook-policy-discovery-spike"
scope:
  - ".sage/work/20260515-cross-repo-sagedocs-permission-fix/*"
  - ".sage/decisions.md"
  - "AGENTS.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
---

# Fix: cross-repo writes only for SageDocs without explicit approval

## State

**Current phase:** intake. To jest capture-only wpis do przyszłej diagnozy i
planu. Nie zmienia jeszcze instrukcji agenta ani hooków.

## Problem

Obecny kontrakt target repo ownership mówi agentowi, że nie wolno pisać
`.sage/**` poza target repo, a globalna korekta mówi, żeby pytać przed
mutowaniem innych repozytoriów. Brakuje jednak precyzyjnego carve-outu dla
pracy dokumentacyjnej: gdy zadanie naprawdę dotyczy wiedzy projektowej w innym
repozytorium, agent powinien mieć wąskie prawo do edycji tylko SageDocs, a nie
całego `.sage/**` ani plików source/runtime/config danego repo.

## Desired behavior

- Agent może bez dodatkowej zgody zmieniać w innym repozytorium tylko pliki
  SageDocs, czyli docelowo wąsko zdefiniowane ścieżki typu `.sage/docs/**`,
  gdy zadanie jest dokumentacyjne albo capture-only i repo docelowe jest
  jednoznaczne.
- Agent nie może bez jawnej zgody zmieniać w innym repozytorium `.sage/work/**`,
  `.sage/decisions.md`, `.sage-memory/**`, source/runtime/test/config,
  instruction surfaces, hooks, generated files ani Git state.
- Jeśli potrzebna jest mutacja inna niż SageDocs w obcym repo, agent ma przed
  tool call zatrzymać się i zapytać użytkownika o zgodę, pokazując repo,
  ścieżki i intencję zmiany.
- Instrukcja ma rozróżnić “SageDocs jako dokumentacja projektowa” od “Sage
  workflow state”; to drugie dalej należy do target repo i nie powinno być
  edytowane z obcej sesji bez osobnego przełączenia targetu albo zgody.

## Candidate scope

- Doprecyzować `Target Repo Ownership` w generated `AGENTS.md` i source
  generatorze Codexa.
- Dodać regresję w stage3 dla tekstu instrukcji.
- Sprawdzić, czy hook powinien traktować cross-repo `.sage/docs/**` inaczej niż
  cross-repo `.sage/work/**` albo source/config paths.
- Zgrać tę zasadę z aktywnym Discovery Spike, bo to zahacza o model
  cross-repo documentation writes i minimalizację false positive hooków.

## Out of scope for intake

- Brak implementacji w tej turze.
- Brak edycji innych repozytoriów w tej turze.
- Brak automatycznego rozszerzania tej reguły na `.sage/work/**` albo
  `.sage/decisions.md`.
