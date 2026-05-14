---
cycle_id: "20260514-instruction-surface-minimization-pass-fix"
title: "Fix: dodać minimization pass do instruction surfaces"
workflow: fix
phase: intake
status: intake
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
priority: P2
source: "conversation"
suggested_workflow: fix
tags:
  - needs-triage
  - minimization-pass
  - prompt-surface
  - instruction-bloat
related:
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "core/constitution/sage-process.constitution.md"
  - "core/agents/developer.persona.md"
  - "tools/sage-claude-plugin/agents/developer.md"
memory_context:
  - "3ad7713ab93947c288bb6a751ca918ca"
---

# Fix: dodać minimization pass do instruction surfaces

## State

**Current phase:** intake - capture only. Implementacja nie została rozpoczęta.

**Next step:** Wejść w osobny `/sage:fix` i zdiagnozować, gdzie minimization
pass powinien być egzekwowany: w generowanym `AGENTS.md`, constitution,
developer instruction/persona, workflow gates, testach albo mniejszym
mechanizmie runtime.

## Finding

Alex chce dopisać jawny minimization pass do powierzchni instrukcyjnych Sage:
`AGENTS.md`, constitution i/lub developer instruction. Dokładne miejsce jest
jeszcze TBD.

Istniejące self-learning `3ad7713ab93947c288bb6a751ca918ca` opisuje zasadę:
przed dodaniem nowej logiki lub instrukcji agent ma sprawdzić, czy ten sam cel
da się osiągnąć mniejszą zmianą, reuse istniejącej logiki, konsolidacją
wordingu, targeted testem albo mechanicznym guardrailem zamiast kolejnym
długim promptem.

## Desired Behavior

Przy planowaniu i implementacji zmian w Sage agent powinien wykonać krótki,
jawny minimization pass:

1. Czy ten sam efekt da się osiągnąć mniejszą zmianą?
2. Czy reguła musi trafić do always-loaded `AGENTS.md`, czy wystarczy workflow,
   test, hook message albo runtime guardrail?
3. Czy dodajemy mechaniczny guardrail, czy tylko więcej tekstu, który agent
   może zignorować?
4. Jeśli dodanie jest konieczne, jaki jest najmniejszy dodatek zamykający
   problem?

## Candidate Scope

- `runtime/platforms/codex/setup/lib/agents-md.sh` - jeśli zasada ma trafić do
  generowanego Codex `AGENTS.md`.
- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats` - jeśli generated
  guidance ma dostać test regresyjny.
- `core/constitution/sage-process.constitution.md` - jeśli zasada ma być
  platform-neutral process rule.
- `core/agents/developer.persona.md` albo
  `tools/sage-claude-plugin/agents/developer.md` - jeśli właściwym miejscem
  jest developer instruction/persona.
- Workflow gates albo hooki - jeśli diagnoza pokaże, że tekst instrukcji jest
  zbyt słabym mechanizmem.

## Boundary

Ten intake nie rozstrzyga jeszcze, do którego surface trafi reguła. Nie należy
automatycznie dokładać kolejnego długiego bloku do `AGENTS.md`; pierwszy krok
przyszłego fixa to właśnie minimization pass nad sposobem wdrożenia
minimization pass.

## Acceptance Notes

- Przyszły plan powinien wskazać najmniejszy skuteczny surface dla tej zasady.
- Plan powinien odróżnić always-loaded prompt surface od workflow docs, testów i
  runtime guardrails.
- Jeśli dotknie Codex-specific `AGENTS.md`, powinien uwzględnić obecny limit i
  semantykę ładowania Codex instructions.
