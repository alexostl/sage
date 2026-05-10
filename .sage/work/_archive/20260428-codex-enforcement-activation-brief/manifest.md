---
title: Manifest — Codex enforcement activation
workflow: architect
status: archived
current_phase: design
created: 2026-04-28
updated: 2026-04-30
closed: 2026-04-29
archived: 2026-04-30
superseded_by: .sage/work/20260429-codex-port-rewrite/
owner: alexostl
artifacts:
  - brief.md
---

## Closure note (2026-04-29)

Cykl zamknięty jako superseded. Powód:

- Commit `a6f1391` revertuje aktywację enforcementu (M1+M2+M3) jako
  empirical dead end — anchor regex+UserPromptSubmit nie wystarcza
  do twardego gatingu mutacji.
- Cykl `20260429-codex-port-rewrite` (architect, in-progress) podejmuje
  ten sam problem od fundamentów — ADR-1/2/3 pinują nową kotwicę
  `PreToolUse(apply_patch)` na Codex ≥ 0.126, walidowaną przez PoC C1.
- Pytania projektowe Q1–Q7 z tego briefu są pochłonięte przez ADR-y
  Batch 1/2/3 nowego cyklu.

Nie wskrzeszać. Materiał diagnostyczny (analizy enforcement surface)
pozostaje read-only referencją dla nowego cyklu.

# Manifest — Codex enforcement activation

## Context summary

Brief autorstwa poprzedniej sesji udokumentował kontrakt-mismatch pomiędzy
tym, co `sage update` obiecuje, a co faktycznie aktywuje w consumer repo
(np. `alex-os-dev`). Trzy stany traktowane jako jeden:

1. Pliki frameworka aktualne na dysku.
2. Wygenerowane powierzchnie Codex aktualne (`AGENTS.md`, `.agents/skills/`,
   `.codex/config.toml`).
3. Runtime enforcement aktywny w sesji Codex + git clone (`.codex/hooks.json`
   z UserPromptSubmit/PreToolUse/PostToolUse, `core.hooksPath` z `.githooks`).

Drugi mismatch: `deploy_direct_skills: false` opisany jako "kosmetyczne
ukrycie z GUI", w rzeczywistości redukuje natywną dostępność direct-skilli
w Codexie.

## Phase trail

- 2026-04-28 — Brief napisany, status `in-review` (poprzednia sesja).
- 2026-04-29 — Manifest backfillowany; przystępuję do elicitation gate
  i przejścia w design phase.
- 2026-04-29 — Elicitation gate [A]. Cztery osie decyzji ustalone:
  1=1C (jeden klucz), 2=self-host agresywne defaulty, 3=3a+3c hybrid
  (warning + `--force-githooks`), 4=4B z fallbackiem 4A (RTFM-first).
  Wchodzimy w PLAN phase.

## Handoff (current)

Następny krok: elicitation gate [A]/[R]/[N]. Po `[A]` przechodzę
do PLAN phase (Step 3 architect workflow): trade-off tables dla 4
otwartych decyzji projektowych, ADR-y do `.sage/docs/`, spec do
`.sage/work/`. Decyzje wymagające odpowiedzi w design phase:

- Q1/Q2/Q3 — polityka aktywacji hooków (Option A vs B vs C z briefu).
- Q4 — semantyka custom `core.hooksPath` w status output.
- Q5/Q6 — narrow palette: zostawić jako behawioralna redukcja, czy
  szukać true display-only mechanizmu (Codex docs RTFM wymagany).
- Q7 — `sage status` komenda raportująca enforcement state.

## Out of scope (pamięć z poprzednich cykli)

- L3 phase tracker pozostaje zaparkowany. Nie wskrzeszać.
- `alex-os-dev` bez writów, tylko read-only inspection.
- Self-host defaults nie wyciekają na `codex-port` ani upstream bez
  explicit branch-policy decision.
