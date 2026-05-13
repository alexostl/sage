---
cycle_id: "20260509-agent-resume-intake-cycle-fix"
title: "Fix: agent nie wykonuje formalnego resume intake cycle"
workflow: fix
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-13
owner: alexostl
needs-triage: false
priority: P1
source: "conversation"
suggested_workflow: fix
folded_into: "20260509-cycle-workflow-entry-enforcement-fix"
related:
  - ".sage/work/20260509-sage-methodology-activation-review/manifest.md"
  - ".sage/work/20260509-sage-methodology-activation-review/review-report.md"
  - ".sage/work/20260509-hook-routing-command-audit/manifest.md"
  - ".sage/work/20260509-multi-active-cycle-model-fix/manifest.md"
  - "core/workflows/continue.workflow.md"
  - ".agents/skills/sage:continue/SKILL.md"
  - ".codex/hooks/pre-tool-validate.sh"
  - ".codex/hooks/lib/active_init.sh"
---

# Fix: agent nie wykonuje formalnego resume intake cycle

## State

**Current phase:** completed - skonsumowane przez Batch 1 anchor cycle
`20260509-cycle-workflow-entry-enforcement-fix`.

**Next step:** Brak osobnej implementacji w tym cyklu. Dalsze zmiany wymagają
nowego intake albo osobnej decyzji o scope.

## Batch 1 Resolution

Ten intake został domknięty bookkeeping-only po zweryfikowanej implementacji
Batcha 1. Wymóg formalnego resume `intake`/`paused` cycle został zaadresowany w
anchor cycle przez zmiany w `continue.workflow.md`, `sage-navigator`,
generated `AGENTS.md` oraz real-agent harness evidence dla scenariusza `06`.

## Finding

Podczas kontynuacji cyklu
`.sage/work/20260509-sage-methodology-activation-review/` użytkownik powiedział:

> "Zróbmy kontynuację tego cyklu review."

Agent poprawnie zrozumiał merytoryczną intencję, ale nie wykonał formalnej
mutacji stanu cyklu przed utworzeniem artefaktu. Cykl nadal miał:

```yaml
phase: intake
status: intake
```

Następnie agent próbował utworzyć `review-report.md`. PreToolUse zablokował
zapis, bo z perspektywy runtime nie było aktywnego cyklu. Dopiero po dalszej
dyskusji i jawnej prośbie użytkownika agent wykonał ręczny bootstrap
frontmatter do aktywnego stanu, zapisał raport i zostawił cykl jako
`status: paused`.

## Root problem

Główny błąd operacyjny: agent potraktował "kontynuujmy cykl" jako rozmowną
zgodę na analizę, a nie jako wymagany state transition w artefakcie.

Poprawna ścieżka powinna być:

1. Użytkownik wskazuje konkretny intake/paused cycle do kontynuacji.
2. Agent aktualizuje jego `manifest.md` do aktywnego stanu, np.
   `status: in-progress` i właściwa `phase`.
3. Dopiero potem tworzy albo modyfikuje artefakty tego cyklu.
4. Po checkpointcie zostawia cykl jako `paused`, `completed` albo
   `in-progress`, zależnie od decyzji użytkownika.

## Why it matters

Bez tego agent wpada w martwy punkt:

- hook widzi tylko frontmatter i słusznie blokuje `status: intake`;
- rozmowa zawiera zgodę użytkownika, ale nie jest stanem workflow;
- agent zaczyna interpretować hook jako przeszkodę, zamiast zauważyć brak
  formalnego resume.

To sprzyja obejściom, np. ręcznemu bootstrapowi albo tymczasowemu manipulowaniu
scope innego cyklu.

## Candidate scope

- Zaktualizować instrukcje `sage:continue`, `sage-navigator` i/lub workflow
  routing tak, żeby "kontynuujmy cykl X" wymagało najpierw formalnego resume
  `manifest.md`.
- Dodać guidance do generated Codex `AGENTS.md`, jeśli to tam powinien mieszkać
  always-loaded invariant.
- Dodać real-agent/harness regression:
  - given: istnieje intake review cycle;
  - prompt: "kontynuujmy ten cykl review";
  - expected: agent najpierw zmienia manifest na aktywny stan;
  - expected: dopiero potem tworzy `review-report.md`;
  - forbidden: próba utworzenia artefaktu while `status: intake`.
- Doprecyzować, czy `status: in-progress` jest właściwy dla aktywnego review,
  czy potrzebny jest bardziej precyzyjny status/phase model.
- Przemyśleć osobno closeout: czy formalne wznowienie `paused/intake`
  cycle jest zawsze konieczne do zamknięcia, czy closeout może być
  metadanychową state transition bez pełnego resume do `in-progress`.

## Boundary

Ten cycle nie naprawia jeszcze komunikatów hooków ani nie dodaje `bin/sage
continue`. To jest osobno pokryte przez
`.sage/work/20260509-hook-routing-command-audit/`. Ten cycle dotyczy zachowania
agenta: musi zauważyć i wykonać formalne resume, gdy użytkownik kontynuuje
konkretny intake/paused cycle.
