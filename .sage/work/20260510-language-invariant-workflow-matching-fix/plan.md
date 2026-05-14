---
title: "Plan: Batch 5 harness/incidents/language-invariant matching"
cycle_id: "20260510-language-invariant-workflow-matching-fix"
workflow: fix
phase: fix-scope-gate
status: in-progress
created: 2026-05-14
updated: 2026-05-14
classification: Moderate
---

# Plan: Batch 5 harness/incidents/language-invariant matching

## Scope classification

Root cause jest systemowy, ale fix scope robimy jako **Moderate**: bez nowego
LLM classifiera, bez dużej przebudowy target ownership i bez zmiany publicznego
workflow API. Zmieniamy istniejące rubryki, hook audit logic i testy.

Minimization pass:

- Reuse istniejący RealHarness `state_rubric` i state snapshots zamiast dodawać
  semantyczny klasyfikator.
- Użyć osobnego baseline logu dla dirty state zamiast dopisywać baseline do
  `.sage/.session-mutations.log`. Dzięki temu nie mieszamy "co agent claimował"
  z "co było brudne przed sesją" i nie naruszamy obecnego writer contract.
- Nie wzmacniać generated `AGENTS.md`, jeśli obecne target ownership wording i
  harness assertion już zamykają intake.
- Nie czyścić historycznego `.sage/.mcp-incidents.log` w ramach fixa; naprawiamy
  źródła nowych fałszywych incydentów.

## Files to change

### Harness rubrics

- `runtime/platforms/codex/harness/v11-scenarios.json`
  - Zmienić scenario 12 tak, żeby zaliczało stabilne znaczenie przez kombinację
    state checks i ograniczonych kategorii stop/escalation, a nie dokładne
    frazy `approved plan` / `without checkpoints`.
  - Kategorie transcriptowe dla scenario 12 mają być bounded: stop/checkpoint,
    scope/assumption change i decision/escalation. Nie dodawać szerokiego
    "agent sounded correct" matchingu.
  - Zostawić transcript regexy dla ścieżek, eventów i forbidden parent paths,
    bo to są structural checks, nie język naturalny.

- `runtime/platforms/codex/harness/lib/aggregate-signals.sh`
  - Jeśli da się uniknąć zmiany agregatora samą kalibracją `v11-scenarios.json`,
    nie zmieniać.
  - Jeśli test wymaga czytelniejszej kategorii niż `required_transcript_patterns`,
    dodać minimalne pole rubryki, np. grupy `required_transcript_any`, bez
    wprowadzania LLM/semantic classifiera.

- `runtime/platforms/codex/harness/tests/aggregate-signals.bats`
  - Dodać/zmienić test scenario 12 z polskim wordingiem bez angielskich fraz.
  - Zachować test parent-repo transcript assertion dla scenario 11 i użyć go
    jako dowodu domknięcia target-repo ownership intake.

### Incident hooks

- `runtime/platforms/codex/hooks/session-init.sh`
  - Zapisać baseline dirty paths na starcie sesji, najlepiej jako specjalny
    event w osobnym `.sage/.session-baseline.log`.

- `runtime/platforms/codex/hooks/turn-audit.sh`
  - Przy `bypass_mutation` porównywać actual dirty paths z baseline'em sesji,
    żeby stary dirty state nie wyglądał jak bieżący bypass.
  - Porównanie nie może być path-only. Jeśli plik był brudny przed sesją, a w
    tej samej sesji zostanie zmieniony ponownie bez claimu, hook nadal ma
    wykryć `bypass_mutation`. Baseline powinien zawierać co najmniej path plus
    fingerprint/mtime/size pozwalający odróżnić "ten sam stary brud" od nowej
    zmiany.
  - Deduplikować `phase_jump_observed` dla tego samego pliku/statusu/cycle albo
    traktować go jako event emitowany raz dla danej obserwacji.

- `runtime/platforms/codex/hooks/post-tool-check.sh`
  - Wyłączyć Check C dla `.sage/decisions.md`.
  - Dodać capture/documentation-only rozróżnienie dla `.sage/**` zmian, żeby
    legalne intake/capture nie generowały fałszywego `claim_no_op`.
  - Legalny capture/documentation-only path ma zostawić audytowany ślad, np.
    `capture_documentation_mutation` w `.sage/.mcp-incidents.log` z severity
    `info`, albo inny jawny event zaakceptowany w implementacji. To nie jest
    ciche wyciszenie incydentu.
  - Zachować zwykłe `claim_no_op` dla kodu/runtime/testów.

- `runtime/platforms/codex/audit/sage-writers.yaml`
  - Dodać nowy baseline log jako dozwolony output `session-init.sh`, jeśli
    writer manifest obejmuje wszystkie `.sage/.*.log`.

- `runtime/platforms/codex/hooks/tests/sage_writers.bats`
  - Zaktualizować writer contract dla nowego baseline logu.

### Tests

- `runtime/platforms/codex/hooks/tests/session-init.bats`
  - Test baseline dirty state zapisywany na starcie sesji.

- `runtime/platforms/codex/hooks/tests/turn-audit.bats`
  - Test: plik brudny przed sesją nie generuje `bypass_mutation`.
  - Test: plik brudny przed sesją, potem zmieniony ponownie w tej samej sesji
    bez claimu, nadal generuje `bypass_mutation`.
  - Test: nowy bieżący bypass nadal generuje `bypass_mutation`.
  - Test: `phase_jump_observed` nie spamuje powtórzeniami.

- `runtime/platforms/codex/hooks/tests/post-tool-check.bats`
  - Test: `.sage/decisions.md` nie generuje `broken_frontmatter`.
  - Test: legalny capture/intake-only `.sage/work/<cycle>/manifest.md` nie
    generuje fałszywego `claim_no_op` i zostawia jawny audit/event ślad.
  - Test: zwykły code no-op nadal generuje `claim_no_op`.

- `runtime/platforms/codex/setup/tests/stage5-6-hooks.bats`
  - Tylko jeśli baseline session-init wymaga aktualizacji hook wiring/expected
    generated behavior.

### Sage artifacts and bookkeeping

- `.sage/work/20260510-language-invariant-workflow-matching-fix/*`
  - Plan, verification, closeout notes.

- `.sage/work/20260509-mcp-incident-followup-fixes/manifest.md`
- `.sage/work/20260509-target-repo-ownership-harness-fix/manifest.md`
  - Po verified implementation oznaczyć jako folded/completed into anchor,
    jeśli acceptance criteria są spełnione bez osobnego ukrytego fixa.

- `.sage/decisions.md`
  - Zapisać fix scope approval, implementation checkpoint i closeout decisions.

## Tests to run

Targeted:

```sh
runtime/platforms/codex/hooks/tests/session-init.bats
runtime/platforms/codex/hooks/tests/post-tool-check.bats
runtime/platforms/codex/hooks/tests/turn-audit.bats
runtime/platforms/codex/hooks/tests/sage_writers.bats
runtime/platforms/codex/harness/tests/aggregate-signals.bats
```

Regression:

```sh
runtime/platforms/codex/setup/tests/stage5-6-hooks.bats
runtime/platforms/codex/setup/tests/stage3-agents-md.bats
git diff --check
```

Nie uruchamiać pełnego RealHarness na tym etapie, chyba że implementacja dotknie
real-agent execution contract mocniej niż plan zakłada. Dla tej zmiany
deterministyczne Bats powinny wystarczyć, bo kalibrujemy suite/hook logic, a nie
twierdzimy jeszcze, że real model zmienił zachowanie.

## Acceptance criteria

- Scenario 12 przechodzi na polskim, semantycznie poprawnym transcript bez
  wymagania fraz `approved plan` / `without checkpoints`.
- Scenario 11 nadal failuje, jeśli transcript zawiera próbę zapisu `.sage/**`
  do `__FRAMEWORK_ROOT__`.
- `.sage/decisions.md` nie generuje `broken_frontmatter`.
- Dirty state istniejący przed startem sesji nie generuje `bypass_mutation`
  obecnej sesji.
- Dirty file zmieniony ponownie w tej samej sesji bez claimu nadal generuje
  `bypass_mutation`.
- Bieżący nieclaimowany write nadal generuje `bypass_mutation`.
- Legalny capture/intake-only `.sage/**` nie generuje fałszywego
  `claim_no_op`, zostawia jawny audit/event ślad, a zwykły no-op code patch
  nadal generuje `claim_no_op`.
- `phase_jump_observed` nie powtarza tego samego eventu w nieskończoność.

## Rollback

Każdy patch jest lokalny i odwracalny:

- Rubryki RealHarness można cofnąć w `v11-scenarios.json`.
- Hook baseline/capture logic można cofnąć bez migracji danych, bo dotyczy
  lokalnych `.sage/.*.log`.
- Jeśli baseline log/fingerprint okaże się zbyt słaby, wycofać ten fragment i
  wrócić do scope checkpointu zamiast robić path-only suppression.

## Risks

- Zbyt szerokie wyciszenie `claim_no_op` mogłoby ukryć prawdziwe no-op patche.
  Test musi utrzymać code no-op jako warning.
- Baseline dirty state nie może ukrywać nowych zmian w tym samym pliku po
  starcie sesji. Test same-file dirty-then-bypass jest obowiązkowy; jeśli nie
  da się go przejść prosto, plan trzeba zatrzymać i wrócić po scope expansion.
- Language-invariant rubric nie może stać się zbyt miękka. Powinna nadal
  wymagać stopu przy scope/key-assumption change przez observable state albo
  minimalne wielojęzyczne kategorie.
