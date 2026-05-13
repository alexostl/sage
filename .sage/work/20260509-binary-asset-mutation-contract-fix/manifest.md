---
cycle_id: "20260509-binary-asset-mutation-contract-fix"
title: "Fix: kontrakt mutacji binarnych assetów poza apply_patch"
workflow: fix
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-13
owner: alexostl
needs-triage: true
priority: P2
folded_into: "20260510-mutation-intent-preflight-gap"
source_thread: "codex://threads/019e0c28-b19f-74f0-85ac-be37e18e4437"
related:
  - "20260509-file-change-enforcement-fix"
  - "20260509-runtime-workflow-enforcement-hardening"
scope:
  - ".sage/work/20260509-binary-asset-mutation-contract-fix/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/hooks/**"
  - "runtime/platforms/codex/harness/**"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/**"
---

# Fix: kontrakt mutacji binarnych assetów poza apply_patch

## State

**Current phase:** completed — finding skonsumowany przez anchor cycle
`20260510-mutation-intent-preflight-gap`.

**Next step:** Brak osobnej implementacji w tym cyklu; patrz anchor cycle i
jego `verification.md`.

## Finding

`apply_patch` jest właściwą ścieżką dla plików tekstowych, ale zatrzymuje się
na binarnych assetach, np. `pdf.png`, bo nie może ich odczytać jako UTF-8.
Agent może wtedy wykonać technicznie poprawną operację, taką jak `rm` dla
legacy obrazka, ale obecny model zasad i audytu może potraktować to jak
podejrzane obejście `apply_patch`.

## Desired behavior

- Pliki tekstowe nadal powinny być zmieniane przez `apply_patch`.
- Pliki binarne, których `apply_patch` nie obsługuje, powinny mieć jawnie
  dozwoloną ścieżkę mutacji: np. `rm`, `cp`, generator assetu albo narzędzie
  eksportujące plik.
- Taka mutacja powinna być legalna tylko wtedy, gdy ścieżka jest w
  zatwierdzonym zakresie cyklu albo w wąskim intake/capture scope.
- Agent powinien nazwać operację jako binary asset mutation, żeby nie wyglądała
  jak ukryty shell bypass.
- Hooki, turn audit i harness powinny rozróżniać zatwierdzoną mutację binarną
  od niekontrolowanego pisania plików poza `apply_patch`.

## Candidate scope

- Doprecyzować generated `AGENTS.md` / kontrakt Codex: tekst przez
  `apply_patch`, binarki przez jawny binary mutation path.
- Ustalić, gdzie powstaje ślad audytowy dla legalnych mutacji binarnych
  wykonanych poza `apply_patch`.
- Dodać regresję dla usunięcia binarnego legacy assetu, np. `pdf.png`, bez
  fałszywego `bypass_mutation`.
- Spiąć tę zmianę z szerszym tematem real-agent `file_change` enforcement, żeby
  wyjątek dla binarek nie stał się furtką do zwykłych zmian tekstowych poza
  `apply_patch`.

## Evidence

Alex zgłosił przypadek z wątku:
`codex://threads/019e0c28-b19f-74f0-85ac-be37e18e4437`

Problem: patch zatrzymał się na binarnym `pdf.png`, więc tekstowe pliki trzeba
było obsłużyć przez `apply_patch`, a binarny asset usunąć osobno przez `rm` jako
zatwierdzoną operację migracji legacy skilla.
