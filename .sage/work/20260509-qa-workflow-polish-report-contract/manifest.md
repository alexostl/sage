---
cycle_id: "20260509-qa-workflow-polish-report-contract"
title: "Fix: QA workflow powinien wymuszać polską prozę raportów"
workflow: fix
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-14
owner: alexostl
priority: P2
needs-triage: false
source: "conversation"
suggested_workflow: fix
folded_into: "20260509-alex-readable-change-explanations-fix"
batch: 7
related:
  - "core/workflows/qa.workflow.md"
  - "develop/templates/qa-report-template.md"
  - ".sage/work/20260509-runtime-workflow-enforcement-qa/qa-report.md"
---

# Fix: QA workflow powinien wymuszać polską prozę raportów

## State

**Current phase:** completed - folded into Batch 7
`20260509-alex-readable-change-explanations-fix`.

**Next step:** Brak osobnego fixa. Batch 7 doprecyzował `qa.workflow.md`,
`develop/templates/qa-report-template.md`, analogiczny `design-review` surface
oraz testy regresyjne.

## Resolution

Ten intake został zamknięty w Batchu 7. Implementacja dodała zasadę, że report
template daje strukturę, a natural-language report prose podąża za project
language contract. W Alex-native selfhost oznacza to polską plain technical
prose, przy zachowaniu raw evidence, command names, ścieżek i identyfikatorów.

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
