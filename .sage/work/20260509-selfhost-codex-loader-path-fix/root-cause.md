---
cycle_id: "20260509-selfhost-codex-loader-path-fix"
title: "Root cause: Batch 4 Codex surface reachability"
workflow: fix
phase: root-cause-gate
status: in-progress
created: 2026-05-13
updated: 2026-05-13
---

# Root Cause: Batch 4 Codex surface reachability

## Problem

Batch 4 laczy cztery objawy jednej granicy: Codex ma widziec poprawna
powierzchnie Sage, ale runtime, wystawione pliki selfhost i config nie sa w
jednym stanie.

Objawy:

1. `.agents/skills/sage:sage/SKILL.md` nadal istnieje, czyli publiczny ogolny
   entrypoint jest zdublowany.
2. Selfhost `.agents/skills/sage:*/SKILL.md` nadal wskazuja na
   `sage/core/workflows/**`, mimo ze w tym repo workflowy sa w
   `core/workflows/**`.
3. `.agents/skills/sage-navigator/SKILL.md` dryfuje od
   `core/capabilities/orchestration/sage-navigator/SKILL.md` i nie zawiera
   najnowszego Alex-native operating contract.
4. Aktywna selfhost `.codex/config.toml` nadal ma `[features].codex_hooks = true`,
   mimo ze generator Stage 4 emituje juz `[features].hooks = true`.

## Przyczyna

Root cause to rozdzielony lifecycle Codex surface:

- generator Stage 7/Stage 4 ma juz czesc docelowej logiki;
- wystawione pliki selfhost (`.agents/skills/**`, `.codex/config.toml`) nie
  zostaly zregenerowane albo zsynchronizowane z ta logika;
- testy pilnuja target fixture, ale aktualny repo surface selfhost moze nadal
  byc stary;
- `sage-navigator` jest kopia deployowana na powierzchnie Codexa, wiec moze
  dryfowac, jesli Stage 7 nie traktuje go jako deterministycznego outputu.

Innymi slowy: Sage naprawil czesc fabryki, ale aktywny produkt lezacy na polce
selfhost nadal pochodzi ze starej fabryki.

## Dowody

- `runtime/platforms/codex/setup/lib/skills-deploy.sh` ma juz
  `CODEX_V1_WORKFLOWS` bez `sage`, usuwa `sage:sage`, rozpoznaje selfhost i
  deployuje `sage-navigator`.
- `runtime/platforms/codex/setup/tests/stage7-skills.bats` wymaga 15 loaderow,
  braku `sage:sage`, path-aware selfhost loaderow i zgodnego navigatora.
- Lokalny scan aktualnej powierzchni selfhost pokazal nadal istniejace
  `.agents/skills/sage:sage/SKILL.md` oraz selfhost loadery z
  `sage/core/workflows/**`.
- `diff` miedzy `core/capabilities/orchestration/sage-navigator/SKILL.md` a
  `.agents/skills/sage-navigator/SKILL.md` pokazal brak Alex-native operating
  contract w wystawionym skillu.
- `runtime/platforms/codex/setup/lib/config-toml.sh` emituje `hooks = true`,
  ale aktywna selfhost `.codex/config.toml` nadal ma `codex_hooks = true`.

## Chain

Agent Codex czyta skill surface z `.agents/skills/**` i config z
`.codex/config.toml`. Nawet jesli generator zostal poprawiony, aktywna sesja
moze dalej trafic w stare selfhost artifacts:

1. `sage:sage` zostaje pokazany jako drugi ogolny entrypoint.
2. Loader prowadzi do `sage/core/workflows/**`, ktore w selfhost nie istnieje.
3. Navigator nie zawiera najnowszych zasad routingu i komunikacji.
4. Config nadal uzywa starej flagi hooks, co moze odtworzyc warning albo drift
   przy kolejnych update'ach.

## Confidence

High. Dowody sa bezposrednie: obecny generator i testy mowia jedno, a
aktywne/wystawione selfhost outputy mowia drugie.

## Granice

- Nie mutowac `alex-os-dev` w tym batchu bez osobnej zgody.
- Nie przepisywac historycznej dokumentacji tylko dlatego, ze wspomina
  `codex_hooks`.
- Nie uznawac starego zamknietego `20260510-codex-surface-reachability-cluster-fix`
  za zamkniecie obecnego chronologicznego Batcha 4. Moze byc evidence, ale nie
  approval ani closeout.
