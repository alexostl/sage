---
cycle_id: "20260511-surgical-config-workflow-threshold-fix"
title: "Plan: pojedyncza zmiana config nie powinna wymuszac Sage workflow"
workflow: fix
phase: fix-scope-gate
status: completed
created: 2026-05-13
updated: 2026-05-13
classification: moderate
root_cause_approved: true
approved: 2026-05-13
approval_path: full-autonomous
completed: 2026-05-13
---

# Plan: pojedyncza zmiana config nie powinna wymuszac Sage workflow

## Scope Classification

**Moderate.**

Sama zmiana kodu hooka moze byc mala, ale poprawka musi dotknac predicate
runtime, regresji Bats i generated guidance/testow. To przekracza 1-2 pliki i
zmienia zachowanie guardrailow.

## Approved Root Cause

`PreToolUse` blokuje pojedyncza zmiane config, gdy `resolve_cycle_for_patch`
zwraca `none`, komunikatem `no active implementation cycle`, bez rozroznienia
lightweight single-file config edit od realnej implementacji wymagajacej cyklu.

## Target Behavior

Pojedynczy config-only patch moze przejsc bez aktywnego cyklu, jesli spelnia
caly strukturalny allowlist:

- dotyka dokladnie jednego top-level pliku pod `config/`, bez podkatalogow;
- sciezka ma rozszerzenie `.toml`, `.json`, `.yaml` albo `.yml`;
- jest `Add` albo `Update`, nie `Delete`;
- nie dotyka `.sage/**`, `.codex/**`, `.claude/**`, `runtime/**`, `src/**`,
  `tests/**`, `bin/**`, `scripts/**`, lockfile ani instruction file;
- nazwa pliku nie pasuje do znanych powierzchni wysokiego ryzyka:
  `*hook*`, `*agent*`, `*instruction*`, `*policy*`, `*permission*`,
  `*secret*`, `*credential*`, `*token*`, `*key*`, `*auth*`, `*mcp*`,
  `*plugin*`, `*skill*`;
- hook nadal zapisuje mutation log entry z pustym `cycle_id` albo jawnym
  lightweight markerem, zeby Stop/turn-audit mial slad.

Wszystko inne zostaje po staremu: brak aktywnego cyklu nadal blokuje source,
runtime, testy, instruction files, wiele plikow, podkatalogi `config/**`,
delete i out-of-scope work.

To jest structural safety gate, nie semantyczny parser configu. Agent nadal ma
obowiazek nazwac ryzyko w rozmowie, a przy niepewnosci wejsc w workflow.

## Tasks

### T1 — Reproducing Regression First

**Files:**
- `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`

**Change:**
Dodac test odtwarzajacy watek `019e185a`: istnieja parked paused/intake cycles,
patch dotyka jednego pliku `config/codex-config.toml`, oczekiwany wynik to exit
`0`, a mutation log zawiera `config/codex-config.toml`.

Dodac kontrolne testy, ze nadal blokujemy:

- dwa pliki config bez aktywnego cyklu;
- `.codex/config.toml` bez aktywnego cyklu;
- `Delete File: config/codex-config.toml` bez aktywnego cyklu;
- `config/hooks.toml`, `config/secrets.json` albo podobny denylisted basename;
- `config/nested/app.toml`;
- `src/**` przy parked cycles bez aktywnego cyklu.

Dodac odpowiedniki dla `file_change` payload:

- pozytywny: jeden dozwolony `config/*.toml` update;
- negatywny: denylisted albo multi-file config change.

### T2 — Runtime Predicate

**Files:**
- `runtime/platforms/codex/hooks/pre-tool-validate.sh`

**Change:**
Dodac maly helper predicate, np. `is_lightweight_config_only_patch`, po zebraniu
`claimed_paths` i `claimed_ops`, przed twarda sciezka `resolution_kind=none`.
Helper ma uzywac tego samego allowlistu dla `apply_patch`, `Edit`/`Write` i
`file_change`, bo wszystkie zasilaja `claimed_paths` / `claimed_ops`.

Zachowanie:

- jesli `resolution_kind=none` i predicate zwraca true, ustawic `cycle_id=""`
  albo jawny marker lightweight i przejsc do wspolnego mutation log append;
- jesli predicate false, zachowac obecny komunikat `no active implementation
  cycle`;
- nie zmieniac `parked-capture`, active scope, same-turn bootstrap ani
  Moderate+ artifact-order invariant.

### T3 — Resolver Helper Only If Needed

**Files:**
- `runtime/platforms/codex/hooks/lib/active_init.sh`
- `runtime/platforms/codex/hooks/tests/active_init.bats`

**Change:**
Preferowany wariant: nie zmieniac resolvera. Jesli implementacja pokaze, ze
predicate musi byc wspoldzielony albo lepiej przynalezy do resolvera, dodac
minimalny helper/test w `active_init`. Nie zmieniac semantyki parked cycles:
paused/intake nadal nie sa implementation-active.

### T4 — Generated Guidance Calibration

**Files:**
- `core/constitution/sage-process.constitution.md`
- `runtime/platforms/codex/setup/lib/agents-md.sh`
- `runtime/platforms/codex/setup/lib/config-toml.sh`
- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
- `runtime/platforms/codex/setup/tests/stage4-config-toml.bats`

**Change:**
Doprecyzowac guidance, zeby nie mowila bezwarunkowo, ze kazda zmiana config
wymaga workflow. Nowy kontrakt:

- source/runtime/test/instruction behavior changes wymagaja workflow;
- config changes sa kalibrowane normalnie: single-file config-only patch
  spelniajacy structural allowlist moze byc Lightweight/Surgical, ale multi-file,
  denylisted names, podkatalogi, generated instruction/hook/security surfaces
  albo niepewnosc semantyczna wracaja do workflow.

Zaktualizowac testy generated `AGENTS.md` i `developer_instructions`, zeby
pilnowaly nowego brzmienia.

## Verification

```bash
bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
bats runtime/platforms/codex/hooks/tests/active_init.bats
bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats
bats runtime/platforms/codex/setup/tests/stage4-config-toml.bats
bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh
bash -n runtime/platforms/codex/hooks/lib/active_init.sh
git diff --check
```

## Rollback

Odwracalny patch:

- cofnac helper/predicate w `pre-tool-validate.sh`;
- usunac dodane testy;
- przywrocic poprzednie guidance stringi i odpowiadajace testy.

Nie ma migracji danych ani zmian w user repo. Deploy do targetow nastapi dopiero
przez pozniejszy `bin/sage update` / sync flow, poza tym planem.

## Non-Goals

- Nie naprawiac broad generated mutations po `alex-os:sync`.
- Nie zmieniac zasad dla `.codex/config.toml`, `.sage/config.yaml`,
  `AGENTS.md`, hookow, skryptow, lockfile albo source/runtime/test files.
- Nie parsowac semantyki configu ani nie probowac rozpoznawac wartosci
  permission/security po tresci pliku.
- Nie auto-aktywowac paused/intake cycles dla implementacji.
- Nie usuwac same-turn self-created artifact guard.
