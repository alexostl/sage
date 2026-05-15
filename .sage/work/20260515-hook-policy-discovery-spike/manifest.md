---
cycle_id: 20260515-hook-policy-discovery-spike
workflow: architect
phase: closeout
status: completed
priority: P0
created: 2026-05-15
completed: 2026-05-15
owner: codex
source_cycle: 20260515-codex-hook-policy-consolidation
source_commit: 9df7ba5f8cb210485feda66785c1fd61abb8c31f
implementation_approval:
  mode: approved
  approved_by: alexostl
  approved_at: "2026-05-15"
  gate: milestone-0-2
  artifact: ".sage/work/20260515-hook-policy-discovery-spike/plan.md"
  scope: manifest
scope:
  - .sage/work/20260515-hook-policy-discovery-spike/**
  - .sage/decisions.md
  - runtime/platforms/codex/harness/**
  - runtime/platforms/codex/hooks/**
---

# Hook Policy Discovery Spike

## Context

Ten cykl jest kontynuacją błędnie domkniętego Milestone 0 z
`20260515-codex-hook-policy-consolidation`. Commit `9df7ba5` zamknął patch
prerequisite RealHarness/runtime/status/decisions, ale nie zamknął pełnego
Discovery Spike. Alex wyraźnie skorygował ten stan i polecił wznowić cykl.

Bezpośrednie wznowienie starego manifestu zostało zablokowane przez obecny hook
`completed cycle mutation`, mimo jawnej decyzji użytkownika. Ten recovery wrapper
jest legalnym miejscem dalszej pracy nad Milestone 0 bez mutowania zamkniętego
cyklu.

## Current Phase

`discovery-spike`: przygotować i wykonać realistyczne scenariusze RealHarness
zaczerpnięte z prawdziwych problemów hooków, porównać tryby `hooks-on`,
`hooks-off` i docelowo `audit-only`, a potem wrócić do architektury enforcement.

## Source Artifacts

- `.sage/work/20260515-codex-hook-policy-consolidation/plan-milestone-0-discovery-spike.md`
- `.sage/work/20260515-codex-hook-policy-consolidation/discovery-spike-execution-plan.md`
- `.sage/work/20260515-codex-hook-policy-consolidation/discovery-spike-report.md`
- `.sage/work/20260515-codex-hook-policy-consolidation/targeted-realharness-report.md`

## Next Step

Milestone 0.2 został wykonany. Run 02 report:

- `.sage/work/20260515-hook-policy-discovery-spike/discovery-spike-run-02-report.md`

Plan architektury `Minimization Path` jest gotowy i wymaga checkpoint approval:

- `.sage/work/20260515-hook-policy-discovery-spike/minimization-path-architecture-plan.md`

Alex zatwierdził `[A] Approve first fix`. Wdrażany jest wyłącznie pierwszy
candidate: local-only/gitignored artifact jako wąskie `allow` albo `audit` bez
manifest bloatu, przy zachowaniu hard blocków dla source/runtime/test mutation
poza workflow.

Pierwszy fix został wdrożony i zweryfikowany:

- `.sage/work/20260515-hook-policy-discovery-spike/local-ignored-artifact-fix-report.md`

Następny krok: zdecydować, czy zamykamy ten milestone/commitujemy, czy najpierw
robimy osobny mały follow-up dla audit noise `claim_no_op` na ignored local-only
plikach.

Target architecture brief jest gotowy:

- `.sage/work/20260515-hook-policy-discovery-spike/target-architecture-brief.md`

Brief opisuje status hooków po Milestone 0.2, target policy outcomes
`block/allow/capture/recover/audit` oraz proponowaną kolejność kolejnych
minimalnych milestone’ów.

Alex zaakceptował target architecture brief jako kierunek. Closeout pierwszego
fixu został zakończony:

- `.sage/work/20260515-hook-policy-discovery-spike/closeout.md`

Następny legalny ruch to osobny cykl/follow-up dla `0.3 Audit Noise
Calibration` albo osobna decyzja o rozpoczęciu `0.4 Capture Ownership
Calibration`.

## Initial Working Hypothesis

Nie wygląda to jak jeden mały fix. Dotychczasowe symptomy wskazują raczej na
problem modelu polityk: hook miesza capture-only/documentation writes,
workflow-state enforcement, repo ownership i ochronę completed cycles w jednym
twardym mechanizmie. Discovery Spike ma oddzielić przypadki, gdzie potrzebny
jest punktowy patch, od miejsc wymagających przeprojektowania policy layer.

## Guiding Principle

Alex zatwierdził kierunek przeprojektowania tylko pod warunkiem zasady
`Minimization Path`: zdejmujemy z hooków odpowiedzialność tylko tam, gdzie
pomiar pokaże realny zysk usability i brak utraty bezpieczeństwa. Plan musi
zostać dobrze sprawdzony przed wdrożeniem, a każde uproszczenie ma mieć jasny
cel: mniej bloatu, mniej fałszywych blokad, mniej recovery loops, bez otwierania
drogi do source/runtime/test mutation poza workflow.
