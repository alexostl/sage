---
cycle_id: "20260509-selfhost-codex-loader-path-fix"
title: "Plan: Batch 4 Codex surface reachability"
workflow: fix
phase: fix-scope-gate
status: in-progress
classification: Moderate
created: 2026-05-13
updated: 2026-05-13
---

# Plan: Batch 4 Codex surface reachability

## Cel

Doprowadzic aktywna powierzchnie Codex selfhost do kontraktu, ktory generator i
testy juz opisuja: jeden publiczny `sage` router, brak `sage:sage`, selfhost
loadery wskazujace na `core/workflows/**`, swiezy `sage-navigator` i
`hooks = true` w selfhost config.

## Minimization pass

Nie dodajemy nowego runtime modelu, jesli obecny generator juz go zawiera.
Najmniejszy poprawny patch to:

- potwierdzic, ze Stage 7/Stage 4/MCP tests juz bronia docelowego kontraktu;
- zregenerowac albo punktowo zsynchronizowac aktywne selfhost outputy;
- rozszerzyc scope tylko o pliki realnie potrzebne do tej synchronizacji i
  weryfikacji;
- nie przepisywac historycznej dokumentacji ani `alex-os-dev`.

## Klasyfikacja

Moderate, bo patch dotyka kilku powierzchni (`.agents/skills`, `.codex/config`,
generator/test verification), ale nie wymaga nowej architektury ani zmiany API.

## Scope

### Artefakty Sage

- `.sage/work/20260509-selfhost-codex-loader-path-fix/*`
- `.sage/work/20260509-duplicate-sage-entrypoint-fix/manifest.md`
- `.sage/work/20260509-sage-navigator-skill-drift-fix/manifest.md`
- `.sage/work/20260509-codex-hooks-feature-flag-migration-fix/manifest.md`
- `.sage/decisions.md`

### Generator i testy

- `runtime/platforms/codex/setup/lib/skills-deploy.sh`
- `runtime/platforms/codex/setup/tests/stage7-skills.bats`
- `runtime/platforms/codex/setup/lib/config-toml.sh`
- `runtime/platforms/codex/setup/tests/stage4-config-toml.bats`
- `runtime/platforms/codex/setup/generate-codex.sh`
- `runtime/platforms/codex/setup/tests/stage10-tighten.bats`
- `runtime/mcp/json_to_toml.py`
- `runtime/mcp/tests/run-regression.sh`

### Aktywna selfhost surface

- `.agents/skills/sage/SKILL.md`
- `.agents/skills/sage-navigator/SKILL.md`
- `.agents/skills/sage:*/SKILL.md`
- `.agents/skills/sage:sage/`
- `.codex/config.toml`

## Tasks

### 1. Potwierdzic generator contract

Sprawdzic i, tylko jesli potrzebne, poprawic:

- Stage 7 generuje 15 workflow loaderow, bez `sage:sage`;
- target repo loadery wskazuja na `sage/core/workflows/**`;
- selfhost loadery wskazuja na `core/workflows/**`;
- `sage-navigator` jest deployowany z core source;
- Stage 4 emituje `[features].hooks = true` i usuwa samotny legacy
  `codex_hooks = true`;
- MCP scaffold nie sugeruje juz `codex_hooks`.

### 2. Zsynchronizowac selfhost outputy

Uruchomic najwezszym sposobem generator dla selfhost albo punktowo doprowadzic
outputy do tego samego wyniku:

- usunac `.agents/skills/sage:sage/`;
- przepisac `.agents/skills/sage:*/SKILL.md` na `core/workflows/**`;
- zsynchronizowac `.agents/skills/sage-navigator/SKILL.md` z
  `core/capabilities/orchestration/sage-navigator/SKILL.md`;
- poprawic `.agents/skills/sage/SKILL.md`, zeby navigator reference wskazywal
  na istniejacy selfhost path;
- zaktualizowac `.codex/config.toml` do `hooks = true`.

### 3. Status source intake'ow

Po verified implementation oznaczyc jako completed/folded into Batch 4 anchor:

- `20260509-duplicate-sage-entrypoint-fix`;
- `20260509-sage-navigator-skill-drift-fix`;
- `20260509-codex-hooks-feature-flag-migration-fix`.

`20260509-selfhost-codex-loader-path-fix` pozostaje anchor cycle.

### 4. Handoff boundary

Jesli w trakcie wyjdzie, ze `alex-os-dev` nadal wymaga analogicznej zmiany,
zapisac to jako decyzje albo intake/handoff, ale nie mutowac tamtego repo w tym
batchu.

## Verification

Przed completion checkpoint uruchomic:

- `bats runtime/platforms/codex/setup/tests/stage7-skills.bats`
- `bats runtime/platforms/codex/setup/tests/stage4-config-toml.bats`
- `bats runtime/platforms/codex/setup/tests/stage10-tighten.bats`
- `bash runtime/mcp/tests/run-regression.sh`
- targeted checks:
  - brak `.agents/skills/sage:sage/SKILL.md`;
  - wszystkie selfhost `.agents/skills/sage:*/SKILL.md` wskazuja na
    istniejace `core/workflows/**`;
  - `.agents/skills/sage-navigator/SKILL.md` jest zgodny z core source;
  - `.agents/skills/sage/SKILL.md` wskazuje na selfhost
    `core/capabilities/orchestration/sage-navigator/SKILL.md`;
  - `.codex/config.toml` ma `hooks = true` i nie ma aktywnego
    `codex_hooks = true`;
  - `git diff --check`.

## Ryzyko

- Regeneracja `.agents/skills/**` moze nadpisac reczne poprawki, jesli generator
  nie zachowuje ich swiadomie. Mitigacja: najpierw diff, potem targeted checks.
- `.codex/config.toml` jest aktywna powierzchnia lokalna, wiec zmiana moze
  wplynac na kolejne sesje Codex. Mitigacja: Stage 4 tests i TOML parse.
- Jesli generator source nie jest jednak kompletny, implementacja wymaga scope
  expansion tylko dla konkretnych brakujacych plikow.

## Rollback

Poniewaz zmiany sa tekstowe i lokalne:

- dla artefaktow Sage: cofnac zmiany w aktualnym cyklu przed closeoutem;
- dla `.agents/skills/**` i `.codex/config.toml`: ponownie uruchomic stary
  generator albo przywrocic pliki z git/worktree diff;
- dla generatora/testow: revert punktowych zmian z tego planu.

## Stop conditions

Zatrzymac sie po decyzje, jesli:

- `sage:sage` okaze sie publicznie wymaganym entrypointem;
- selfhost generator chce dotknac plikow poza scope;
- `hooks` vs `codex_hooks` pokaze sprzeczny runtime contract;
- naprawa wymaga mutacji `alex-os-dev`.
