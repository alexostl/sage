---
title: "QA Report: Alex-native operating model"
workflow: architect
phase: review
status: completed
created: 2026-05-08
updated: 2026-05-08
cycle_id: "20260508-alex-native-operating-model"
---

# QA Report: Alex-native operating model

## Verdict

PASS techniczny, ale cykl pozostaje niedomkniety produktowo do czasu pierwszych
testow realnej pracy. Kontrakt Alex-native jest zapisany w core, przyszlych
templates oraz w kompaktowych powierzchniach runtime dla Codex i Claude Code.
Zmiana pozostaje prospektywna: nie migruje historycznych `.sage/work` ani
`.sage/docs`.

## Dogfood: Conversation Contract

**PASS — Polish artifact language.** Shared-text test sprawdza konstytucje,
navigator, workflowy, capability prompts i templates pod katem zasady:
nowe artefakty `.sage` po polsku, Sage terms i nazwy artefaktow bez zmian.

**PASS — Junior Dev Vibecoder style.** Core constitution i navigator wymagaja
okolo 20-30% wiecej kontekstu, jednego pytania naraz, sprawdzania repo przed
pytaniem oraz krotkich checkpoint summaries.

**PASS — Artifact links instead of assumed reading.** Core workflowy wymagaja
1-3 klikalnych linkow do najwazniejszych sekcji artefaktow na checkpointach.

**PASS — Autonomy stop conditions.** Build workflow i build-loop rozrozniaja
autonomiczna kontynuacje po `spec` i po `plan`; zatrzymuja sie przy scope
expansion, decyzjach architektonicznych, destrukcyjnych akcjach, ambiguous
ownership i waznych pytaniach.

**PASS — Port parity for supported self-host surfaces.** Codex `AGENTS.md`
i Claude `CLAUDE.md`/build/architect command preambles maja kompaktowy
Alex-native operating contract.

## Evidence

- `bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats` — PASS
- `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats` — PASS
- `bats runtime/platforms/codex/setup/tests` — PASS, 179 tests
- `bats runtime/platforms/claude-code/setup/tests` — PASS, 2 tests
- `bats runtime/platforms/codex/hooks/tests` — PASS, 115 tests
- `git diff --check` — PASS

## Follow-up

Open until real-use validation:

- Czy `developer_instructions` in `.codex/config.toml` tez powinien dostac
  kompaktowy Alex-native contract.
- Czy `AGENTS.md` i `CLAUDE.md` powinny byc szerzej po polsku, czy tylko
  zawierac runtime contract, a dokumenty `.sage` pozostaja glowna warstwa
  polskiego jezyka.
- Czy styl faktycznie trafia w "20-30%" wiecej kontekstu podczas normalnej
  pracy, bez robienia z Sage zbyt gadatliwego procesu.
