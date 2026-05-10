---
cycle_id: "20260509-qa-workflow-polish-report-contract"
title: "Fix: QA workflow powinien wymuszać polską prozę raportów"
workflow: fix
phase: intake
status: intake
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
priority: P2
needs-triage: true
source: "conversation"
suggested_workflow: fix
related:
  - "core/workflows/qa.workflow.md"
  - "develop/templates/qa-report-template.md"
  - ".sage/work/20260509-runtime-workflow-enforcement-qa/qa-report.md"
---

# Fix: QA workflow powinien wymuszać polską prozę raportów

## State

**Current phase:** intake - capture only. Implementacja nie została rozpoczęta.

**Next step:** Wejść w osobny `/sage:fix` i doprecyzować `qa.workflow.md`, że
raporty QA jako nowe artefakty `.sage` mają mieć prozę po polsku w projektach
Alex-native, przy zachowaniu kanonicznych nazw technicznych i raw outputów.

## Finding

Po `/sage:qa` dla `20260509-runtime-workflow-enforcement-hardening` raport
został napisany po angielsku, bo agent zbyt literalnie użył angielskiego
`develop/templates/qa-report-template.md`.

To narusza lokalny kontrakt: nowe artefakty `.sage` powinny mieć prozę po
polsku, a po angielsku mogą zostać frontmatter keys, command names, workflow
names, ścieżki, identyfikatory techniczne i surowe outputy testów.

## Desired Behavior

`core/workflows/qa.workflow.md` powinien explicite mówić:

- QA report prose follows the project language contract;
- w tym repo nowe raporty QA piszemy po polsku;
- raw evidence, komendy, ścieżki i outputy testów zostają verbatim;
- globalny angielski template jest szkieletem struktury, nie językiem
  docelowym raportu.

## Candidate Scope

- `core/workflows/qa.workflow.md`
- opcjonalnie mała wzmianka w `develop/templates/qa-report-template.md`, jeśli
  diagnoza uzna, że sam workflow nie wystarczy

## Boundary

Ten intake obejmuje tylko punkt 1: doprecyzowanie workflow. Nie zakłada jeszcze
polskiego template'u ani testu regresyjnego.
