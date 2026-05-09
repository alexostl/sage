---
cycle_id: "20260509-runtime-process-dummy-qa"
title: "QA: Project Dummy po patchu runtime/process"
workflow: qa
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
source_cycle: "20260509-runtime-process-reliability-patch"
target: "/Users/alexostl/Developer/dummy-project"
model: "gpt-5.4"
reasoning_effort: "low"
scope:
  - ".sage/work/20260509-runtime-process-dummy-qa/*"
  - ".sage/decisions.md"
---

# QA: Project Dummy po patchu runtime/process

## State

**Current phase:** run — uruchamiamy real-agent testy na izolowanych kopiach
Project Dummy po patchu runtime/process.

**Target:** `/Users/alexostl/Developer/dummy-project`.

**Model profile:** `gpt-5.4`, `model_reasoning_effort=low`.

## Zakres testu

Test ma powtórzyć poprzedni styl walidacji Project Dummy: nie zmieniać
prawdziwego target repo, tylko uruchamiać realne sesje `codex exec` na
izolowanym targetcie i zebrać transkrypty, state snapshots oraz raport.

Szczególnie sprawdzamy:

- czy `sage status` jest po polsku i nie mutuje repo;
- czy samo zgłoszenie błędu nie wywołuje spontanicznego patchowania;
- czy build/fix/architect/analyze routing nadal działa po zmianach guidance;
- czy harness raportuje release-blocker state dla scenariuszy v1.1.

## Wynik

Raport zapisany w `qa-report.md`.

Werdykt: **QA FAIL dla release claimu runtime/process**. Release-blocker
aggregate jest kompletny (`8/8`), ale to właśnie część problemu: zielona metryka
przepuściła realne failure'y. `bug-report-no-fix` nie patchuje implementacji,
ale scenariusz 03 dodał `src/notes/random.md` bez workflow state, a scenariusz
04 zmienił `AGENTS.md` bez fix diagnosis gate.
