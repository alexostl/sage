---
cycle_id: "20260514-instruction-surface-minimization-pass-fix"
title: "Fix: review dobrych praktyk i minimization pass dla instruction surfaces"
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
  - engineering-practices
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

# Fix: review dobrych praktyk i minimization pass dla instruction surfaces

## State

**Current phase:** intake - capture only. Implementacja nie została rozpoczęta.

**Next step:** Wejść w osobny `/sage:fix` i najpierw zrobić inventory obecnych
dobrych praktyk programowania oraz instruction surfaces. Dopiero potem
zdiagnozować, gdzie minimization pass powinien być egzekwowany: w generowanym
`AGENTS.md`, constitution, developer instruction/persona, workflow gates,
testach albo mniejszym mechanizmie runtime.

## Finding

Alex chce dopisać jawny minimization pass do powierzchni instrukcyjnych Sage:
`AGENTS.md`, constitution i/lub developer instruction. Dokładne miejsce jest
jeszcze TBD.

Alex chce też rozszerzyć ten fix o szerszy review dobrych praktyk programowania,
które Sage już ma w instrukcjach i workflowach. Pytanie nie brzmi tylko "gdzie
dodać minimization pass", ale też "czy obecny zestaw engineering principles jest
wystarczający, czy brakuje jeszcze jednej/dwóch małych zasad, które realnie
poprawią jakość pracy bez dokładania prompt bloatu".

Istniejące self-learning `3ad7713ab93947c288bb6a751ca918ca` opisuje zasadę:
przed dodaniem nowej logiki lub instrukcji agent ma sprawdzić, czy ten sam cel
da się osiągnąć mniejszą zmianą, reuse istniejącej logiki, konsolidacją
wordingu, targeted testem albo mechanicznym guardrailem zamiast kolejnym
długim promptem.

## Review Questions

Przyszły fix ma najpierw odpowiedzieć na kilka pytań:

1. Jakie dobre praktyki programowania Sage już ma w always-loaded i workflow
   surfaces?
2. Czy te praktyki są spójne między platformami (`Codex`, `Claude Code`,
   `Antigravity`) i czy nie dublują się w kilku miejscach innymi słowami?
3. Czy obecne zasady są wystarczająco operacyjne, czy są tylko ogólnymi hasłami
   typu "Tests before code" bez przełożenia na plan/test/review gates?
4. Czy oprócz minimization pass brakuje jeszcze krytycznej zasady, np. wokół
   prostoty, coupling/cohesion, observability, failure modes, migration safety,
   interface contracts, dependency discipline albo test design?
5. Jeśli czegoś brakuje, czy powinno to trafić do always-loaded instruction,
   workflow docs, tests, hook/recovery message, czy do pamięci/self-learning?

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

Jeśli review dobrych praktyk pokaże realną lukę, przyszły fix może zaproponować
dodatkową zasadę obok minimization pass, ale tylko po tym samym filtrze:
czy zasada jest konkretna, testowalna albo egzekwowalna, i czy jej wartość jest
większa niż koszt kolejnego fragmentu instrukcji.

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
- platform generators dla Claude Code / Antigravity, jeśli review pokaże
  niespójność obecnych engineering principles między runtime surfaces.
- istniejące workflow docs (`build`, `fix`, `review`, `qa`) - jeśli dobra
  praktyka powinna działać jako workflow gate zamiast always-loaded prompt.
- Workflow gates albo hooki - jeśli diagnoza pokaże, że tekst instrukcji jest
  zbyt słabym mechanizmem.

## Boundary

Ten intake nie rozstrzyga jeszcze, do którego surface trafi reguła ani czy poza
minimization pass trzeba dodać inną zasadę. Nie należy automatycznie dokładać
kolejnego długiego bloku do `AGENTS.md`; pierwszy krok przyszłego fixa to review
obecnych praktyk i minimization pass nad sposobem wdrożenia minimization pass.

## Acceptance Notes

- Przyszły plan powinien wskazać najmniejszy skuteczny surface dla tej zasady.
- Przyszły plan powinien zawierać krótkie inventory obecnych dobrych praktyk
  programowania w Sage i ocenić, czy są luki warte wdrożenia.
- Plan powinien odróżnić always-loaded prompt surface od workflow docs, testów i
  runtime guardrails.
- Plan powinien unikać "best practices checklist bloat": każda dodatkowa zasada
  poza minimization pass musi mieć konkretny failure mode, miejsce wdrożenia i
  minimalny test albo inny mechanizm weryfikacji.
- Jeśli dotknie Codex-specific `AGENTS.md`, powinien uwzględnić obecny limit i
  semantykę ładowania Codex instructions.
