---
status: completed
updated: 2026-05-15
---

# Plan

## Cel

Naprawić extractor preamble używany przez Codex skill loader, żeby workflow
descriptions nie zwracały technicznego nagłówka `## Artifact Language Contract`,
tylko właściwy krótki opis workflowu.

## Zakres

- `runtime/platforms/codex/setup/lib/extract-preamble.sh`
- `runtime/platforms/codex/setup/tests/preamble-extraction.bats`

## Kroki

1. Zmienić extractor tak, żeby po H1 pomijał opcjonalny blok
   `## Artifact Language Contract` i jego pierwszy paragraf boilerplate.
2. Dodać/regresyjnie utrzymać test, że `build.workflow.md` zwraca
   `Feature development guided by Sage.`.
3. Uruchomić focused test `preamble-extraction.bats`, potem ogólne smoke testy
   setup/hooks/harness bez RealHarness.

## Ryzyko

Niskie. Zmiana dotyka tylko generowania krótkich opisów skill loadera. Nie
zmienia samych workflowów ani runtime hook policy.
