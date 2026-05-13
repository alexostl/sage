---
cycle_id: "20260509-cycle-workflow-entry-enforcement-fix"
title: "Fix: deklaracja workflow musi otwierac realny cykl"
workflow: fix
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-13
owner: alexostl
needs-triage: true
priority: P1
source: "conversation"
source_thread: "codex://threads/019e0e84-da08-7843-852e-7d4ad30e0ae0"
evidence_threads:
  - "codex://threads/019e21ed-db84-7a82-96d8-d0239a431a19"
suggested_workflow: fix
classification: systemic
semantic_reclassification: accepted
related:
  - ".sage/work/20260509-agent-resume-intake-cycle-fix/manifest.md"
  - ".sage/work/20260509-cycle-state-disclosure-fix/manifest.md"
  - ".sage/work/20260509-codex-task-plan-visibility-fix/manifest.md"
  - ".sage/work/20260509-fix-trigger-gate-fix/manifest.md"
  - ".sage/work/20260509-active-cycle-lease-lock/manifest.md"
  - "core/workflows/build.workflow.md"
  - "core/workflows/fix.workflow.md"
  - ".agents/skills/sage/SKILL.md"
  - ".agents/skills/sage-navigator/SKILL.md"
scope:
  - ".sage/work/20260509-cycle-workflow-entry-enforcement-fix/*"
  - ".sage/work/20260509-agent-resume-intake-cycle-fix/manifest.md"
  - ".sage/work/20260509-cycle-state-disclosure-fix/manifest.md"
  - ".sage/work/20260509-codex-task-plan-visibility-fix/manifest.md"
  - ".sage/work/20260509-fix-trigger-gate-fix/manifest.md"
  - ".sage/work/20260509-active-cycle-lease-lock/manifest.md"
  - ".sage/decisions.md"
  - "core/capabilities/orchestration/sage-navigator/SKILL.md"
  - "core/workflows/continue.workflow.md"
  - "core/workflows/fix.workflow.md"
  - "core/constitution/sage-process.constitution.md"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "runtime/platforms/codex/hooks/lib/active_init.sh"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/tests/active_init.bats"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
  - "runtime/platforms/codex/harness/prompts/04-fix-trigger.txt"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
---

# Fix: deklaracja workflow musi otwierac realny cykl

## State

**Current phase:** completed - Batch 1 został zaakceptowany przez Alexa i
zamknięty po zielonym deterministic verification oraz real-agent harness.

**Next step:** Commit i push zmian Batcha 1.

## Verification Evidence

Deterministic verification przeszło 2026-05-13:

- `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats` - 48/48
- `bats runtime/platforms/codex/harness/tests/aggregate-signals.bats` - 14/14
- `bats runtime/platforms/codex/hooks/tests/active_init.bats` - 15/15
- `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` - 67/67
- `bash -n runtime/platforms/codex/setup/lib/agents-md.sh`
- `bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh`
- `bash -n runtime/platforms/codex/hooks/lib/active_init.sh`
- `jq . runtime/platforms/codex/harness/v11-scenarios.json >/dev/null`
- `git diff --check`

Real-agent harness przeszło 2026-05-13 na `gpt-5.4 / reasoning=medium`:

- output:
  `.sage/work/20260509-cycle-workflow-entry-enforcement-fix/harness-run-20260513200647/`
- report:
  `.sage/work/20260509-cycle-workflow-entry-enforcement-fix/harness-run-20260513200647/report.json`
- `v11_release_blocker_harness.complete=true`
- `present=10`
- `missing=[]`

## Batch Scope

Ten cykl jest kotwicą dla całego Batcha 1, nie pojedynczym fixem. Batch 1
obejmuje:

- `20260509-cycle-workflow-entry-enforcement-fix`
- `20260509-agent-resume-intake-cycle-fix`
- `20260509-cycle-state-disclosure-fix`
- `20260509-codex-task-plan-visibility-fix`
- `20260509-fix-trigger-gate-fix`
- `20260509-active-cycle-lease-lock`

`20260510-mutation-intent-preflight-gap` pozostaje powiązanym problemem, ale
należy do Batcha 2 i nie jest częścią implementacyjnego scope tego cyklu bez
osobnej decyzji o rozszerzeniu.

## Finding

Alex wskazal, ze gdy agent mowi w odpowiedzi, ze zadanie pasuje np. do
`build workflow` i jest tego pewien, sama deklaracja w tekscie nie wystarcza.
Agent powinien realnie wejsc w workflow: otworzyc cykl, ustawic jego stan w
artefaktach Sage i dopiero potem kontynuowac prace zgodnie z bramkami tego
workflow.

## Root Problem

Obecny kontrakt moze pozwalac agentowi wykonac poprawna klasyfikacje
konwersacyjna bez odpowiadajacej jej mutacji stanu. W praktyce powstaje
rozjazd:

- rozmowa mowi "wchodzimy w build/fix/review";
- `.sage/work/.../manifest.md` nie istnieje albo nadal jest w stanie intake;
- hooki i kolejne agenty nie widza formalnie aktywnego workflow;
- checkpointy, scope, plan/spec gates i resume behavior staja sie zalezne od
  pamieci rozmowy zamiast od stanu na dysku.

## Why It Matters

Sage ma byc systemem operacyjnym workflow, nie tylko slownikiem etykiet. Jesli
agent trafnie wybiera workflow, ale nie otwiera cyklu, to:

- build/fix gates moga zostac pominiete mimo poprawnej deklaracji;
- runtime nie ma czego egzekwowac;
- uzytkownik widzi pewnosc agenta, ale projekt nie dostaje trwalego stanu;
- po kompakcji albo nowej sesji nastepny agent moze zaczac od zera.

## Candidate Scope

- Doprecyzowac w routerze/navigatorze Sage: pewna klasyfikacja Standard+
  wymaga natychmiastowego formalnego entry do workflow, nie tylko komunikatu.
- Zaktualizowac generated Codex `AGENTS.md` albo odpowiedni always-loaded
  kontrakt, jesli invariant musi byc widoczny przed aktywacja skilla.
- Dodac guidance dla przypadkow:
  - nowy task pasuje do build/fix/review -> utworz nowy cykl;
  - task wskazuje istniejacy intake/paused cycle -> formalnie wznow cykl;
  - agent nie jest pewien workflow -> zadaj krotkie pytanie albo pokaz opcje,
    bez falszywej deklaracji wejscia.
- Dodac regresje/harness:
  - prompt: "to brzmi jak build, zrobmy to";
  - expected: agent tworzy `manifest.md`/cykl przed spec/plan/code;
  - forbidden: sama odpowiedz tekstowa "wchodze w build workflow" bez stanu
    cyklu na dysku.
- Sprawdzic overlap z `agent-resume-intake-cycle-fix`, bo ten intake dotyczy
  wznowienia wskazanego cyklu, a tutaj chodzi szerzej o entry po klasyfikacji
  workflow.

## Additional evidence: lightweight entry drift

Thread `codex://threads/019e21ed-db84-7a82-96d8-d0239a431a19` adds a narrower
variant: the task may have been small enough for lightweight handling, but the
agent still entered workflow state reactively, only after `PreToolUse` blocked
the first patch. It then created a minimal manifest with the wrong field
(`scope_files` instead of `scope`) and needed another block before repairing the
cycle shape.

This evidence should not be read as "every lightweight build needs full
`spec.md` and `plan.md`." The useful requirement is lower-level: if the agent
decides that a task needs a cycle, even a lightweight one, it must create a
hook-readable cycle state before implementation and validate that scope is
expressed in the fields the runtime actually enforces.

## Boundary

Ten intake nie autoryzuje jeszcze implementacji ani zmiany runtime. To
capture-only follow-up dla wymogu: deklaracja workflow musi byc spelniona
stanem Sage na dysku.
