---
cycle_id: "20260509-cycle-state-disclosure-fix"
title: "Fix: jawne komunikowanie wejścia i wyjścia z cyklu Sage"
workflow: fix
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-13
owner: alexostl
needs-triage: false
priority: P2
source: "conversation"
suggested_workflow: fix
folded_into: "20260509-cycle-workflow-entry-enforcement-fix"
related:
  - ".sage/work/20260509-agent-resume-intake-cycle-fix/manifest.md"
  - ".sage/work/20260509-blocking-hook-guidance-review/manifest.md"
  - ".sage/work/20260509-sage-methodology-activation-review/manifest.md"
  - "core/capabilities/orchestration/sage-navigator/SKILL.md"
  - "core/workflows/continue.workflow.md"
  - "core/workflows/close.workflow.md"
---

# Fix: jawne komunikowanie wejścia i wyjścia z cyklu Sage

## State

**Current phase:** completed - skonsumowane przez Batch 1 anchor cycle
`20260509-cycle-workflow-entry-enforcement-fix`.

**Next step:** Brak osobnej implementacji w tym cyklu. Dalsze zmiany wymagają
nowego intake albo osobnej decyzji o scope.

## Batch 1 Resolution

Ten intake został domknięty bookkeeping-only po zweryfikowanej implementacji
Batcha 1. Wymóg jawnego komunikowania state transition po zmianie
`status`/`phase` został zaadresowany w anchor cycle przez kontrakt
manifest-first entry/resume oraz generated Codex operating contract.

## Finding

Alex wskazał potrzebę, żeby agent bardziej jawnie opisywał stan workflow, w
którym się znajduje, szczególnie przy granicach cyklu Sage:

- kiedy agent wchodzi w cykl, powinien powiedzieć to użytkownikowi po fakcie;
- kiedy agent wychodzi z cyklu, powinien powiedzieć to użytkownikowi po fakcie;
- komunikat nie ma być deklaracją intencji typu "zamierzam wejść w cykl";
- komunikat ma opisywać stan już wykonany, np. po zmianie frontmatter albo po
  formalnym closeout/pause/exit.

## Root problem

Obecne komunikaty agenta mogą mieszać trzy różne rzeczy:

- zamiar działania ("wejdę w cykl", "zamknę cykl");
- faktyczny stan rozmowy;
- faktyczny stan artefaktów Sage (`manifest.md`, phase/status, closeout).

Użytkownik chce, żeby granice cyklu były komunikowane jako potwierdzenie
dokonanego state transition. To zmniejsza niepewność, czy agent tylko opisuje
plan, czy naprawdę wszedł/opuścił formalny workflow.

## Desired behavior

Przykładowy invariant komunikacyjny:

1. Agent wykonuje formalne wejście/resume/bootstrap cyklu Sage.
2. Dopiero po tej mutacji mówi użytkownikowi, że jest już w cyklu, wraz z
   nazwą albo `cycle_id`.
3. Agent wykonuje formalne wyjście/pauzę/zamknięcie cyklu.
4. Dopiero po tej mutacji mówi użytkownikowi, że wyszedł z cyklu albo zostawił
   go w konkretnym stanie (`paused`, `completed`, `intake`).

## Candidate scope

- Dodać zasadę do always-loaded Codex/Claude operating contract albo do
  odpowiedniego workflow (`sage-navigator`, `sage:continue`, `close`,
  checkpoint/closeout guidance).
- Ustalić standard krótkiego komunikatu po wejściu i po wyjściu z cyklu.
- Dodać harness/real-agent regression, jeśli istnieje testowa powierzchnia
  weryfikująca komunikaty agenta przy state transitions.
- Sprawdzić, czy to powinno zostać połączone z cyklem formalnego resume
  intake/paused cycle, czy pozostać osobnym ergonomics fixem.

## Boundary

Ten cycle nie zmienia jeszcze mechaniki aktywowania, pauzowania ani zamykania
cykli. Dotyczy wyłącznie jawnego komunikowania stanu po faktycznym transition.
