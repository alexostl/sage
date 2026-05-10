---
cycle_id: "20260510-codex-surface-reachability-cluster-fix"
title: "Plan: klaster C Codex surface i reachability"
workflow: fix
phase: implementation-mode-gate
status: approved
approval: "approved-by-user"
implementation_mode: "full-autonomous-until-verification"
autonomy_grant: "approved plan snapshot as of 2026-05-10; scope limited to manifest.scope and stop conditions"
created: 2026-05-10
updated: 2026-05-10
classification: Systemic
---

# Plan: klaster C Codex surface i reachability

## Cel

Naprawić jedną wspólną powierzchnię Codex, przez którą agent dociera do Sage:
generated config, workflow loader stubs, `sage-navigator` i publiczny Sage
entrypoint. To ma być jeden patch klastra C, a nie seria samotnych intake'ów.

## Decyzje do zablokowania

1. **Public skill surface Codex jest jawna.**
   Publiczny ogólny router to `.agents/skills/sage/SKILL.md`. Workflow-specific
   wejścia zostają jako `sage:build`, `sage:fix`, `sage:qa` itd. Redundantny
   `sage:sage` nie powinien być generowany.

2. **Workflow loaders są path-aware.**
   Target repo z vendored frameworkiem dostaje ścieżki
   `sage/core/workflows/<workflow>.workflow.md`. Selfhost/framework repo dostaje
   ścieżki `core/workflows/<workflow>.workflow.md`.

3. **`sage-navigator` ma deterministyczny deployment.**
   Stage 7 ma wystawiać aktualny `sage-navigator` z source-of-truth
   `core/capabilities/orchestration/sage-navigator/SKILL.md`, zamiast zostawiać
   starą kopię w `.agents/skills/`.

4. **Codex hooks config wymaga cleanupu generatora, nie diagnozy live GUI.**
   Aktualny globalny `~/.codex/config.toml` ma już `hooks = true`, więc brak
   ostrzeżenia w GUI jest spodziewany. Problem w klastrze C dotyczy tracked
   source: generator Sage i testy Stage 4 nadal emitują oraz wymagają
   `codex_hooks = true`, więc kolejny `sage update` może odtworzyć stary klucz w
   target repo.

5. **Cross-repo follow-up zostaje handoffem, nie mutacją.**
   W tym cyklu nie mutujemy `alex-os-dev`. Jeśli po patchu Sage trzeba będzie
   zmienić alex-os global config/status skills, efektem fixa ma być osobny
   plik handoffu z listą rekomendowanych zmian i evidence, bez dotykania tamtego
   repo.

## Scope

### Artefakty Sage

- `.sage/work/20260510-codex-surface-reachability-cluster-fix/*`
- `.sage/work/20260509-selfhost-codex-loader-path-fix/manifest.md`
- `.sage/work/20260509-selfhost-codex-loader-path-fix/root-cause.md`
- `.sage/work/20260509-codex-hooks-feature-flag-migration-fix/manifest.md`
- `.sage/work/20260509-sage-navigator-skill-drift-fix/manifest.md`
- `.sage/work/20260509-duplicate-sage-entrypoint-fix/manifest.md`
- `.sage/decisions.md`
- `.codex/config.toml`

### Runtime, generator i testy

- `runtime/platforms/codex/setup/lib/skills-deploy.sh`
- `runtime/platforms/codex/setup/lib/config-toml.sh`
- `runtime/platforms/codex/setup/generate-codex.sh`
- `runtime/mcp/json_to_toml.py`
- `runtime/mcp/tests/run-regression.sh`
- `runtime/platforms/codex/setup/tests/stage4-config-toml.bats`
- `runtime/platforms/codex/setup/tests/stage7-skills.bats`
- `runtime/platforms/codex/setup/tests/stage10-tighten.bats`

### Wystawione skille selfhost

- `.agents/skills/sage/SKILL.md`
- `.agents/skills/sage-navigator/SKILL.md`
- `.agents/skills/sage:*/SKILL.md`

## Tasks

### 1. Testy Stage 7 dla public skill surface

**Najpierw testy, potem kod.**

Zmienić `stage7-skills.bats`, żeby opisywał docelową powierzchnię:

- target repo generuje workflow loaders bez `sage:sage`;
- liczba workflow loaders spada z 16 do 15;
- `sage` pozostaje osobnym publicznym routerem, nie workflow loaderem;
- publiczny router `sage` ma reachable/path-aware reference do
  `sage-navigator` zarówno w selfhost, jak i target repo;
- `sage-navigator` jest wystawiony i zawiera aktualny Alex-native operating
  contract z core source;
- target repo loader wskazuje na `sage/core/workflows/...`;
- selfhost target loader wskazuje na `core/workflows/...`;
- re-run pozostaje idempotentny.

**Expected failing tests przed implementacją:** count nadal wynosi 16,
`sage:sage` istnieje, selfhost path wskazuje na brakujące `sage/core/...`, a
`sage-navigator` driftuje.

### 2. Testy Stage 4 i MCP helper dla hooks feature flag

Zmienić `stage4-config-toml.bats`, żeby wymagał:

- `[features].hooks = true` w managed block;
- brak aktywnego `codex_hooks = true`;
- legacy postlude cleanup usuwa samotny stary `[features] codex_hooks = true`;
- user-owned feature flags nadal nie są kasowane po cichu.

Dodać albo zaktualizować test dla `runtime/mcp/json_to_toml.py`, jeśli istnieje
lokalny test harness dla MCP TOML translatora. Jeśli nie ma gotowego testu,
plan implementacji ma ograniczyć zmianę do komentarza/example scaffold i
zweryfikować przez targeted `rg`.

### 3. Implementacja public skill surface w Stage 7

W `skills-deploy.sh`:

- usunąć `sage` z `CODEX_V1_WORKFLOWS`;
- dodać jawny deploy public routera `sage`, jeśli generator ma go utrzymywać,
  albo zachować istniejący ręczny skill bez nadpisywania, jeśli taki jest
  obecny;
- dodać deterministyczny deployment `sage-navigator` z core source;
- dodać helper rozpoznający selfhost target przez realpath targetu i
  `SAGE_FRAMEWORK`;
- renderować workflow loader source path jako `core/workflows/...` dla selfhost
  i `sage/core/workflows/...` dla target repo.
- renderować albo aktualizować reference z publicznego routera `sage` do
  `sage-navigator` tak, żeby wskazywał na istniejący plik w selfhost i target
  repo.

Preferowany wariant: Stage 7 zarządza `sage-navigator`, a `sage` pozostaje
świadomie utrzymanym publicznym routerem, ale Stage 7 może aktualizować jego
path reference, jeśli to najwęższy sposób domknięcia reachability. Jeśli
implementacja pokaże, że `sage` musi być w pełni generowany, plan wymaga
krótkiej rewizji przed kodem.

### 4. Cleanup generatora hooks feature flag

W `config-toml.sh` i `generate-codex.sh`:

- zmienić managed block z `codex_hooks = true` na `hooks = true`;
- zaktualizować summary output, żeby mówił `hooks=true`;
- cleanup starego postlude `[features]` ma usuwać legacy `codex_hooks = true`,
  ale nie user-owned keys.

W `runtime/mcp/json_to_toml.py`:

- usunąć albo zaktualizować example scaffold, który sugeruje `codex_hooks`;
- dodać test/regresję w `runtime/mcp/tests/run-regression.sh` albo innym pliku
  w `runtime/mcp/tests/`, który pilnuje, że scaffold nie sugeruje już
  `codex_hooks`;
- nie przepisywać historycznej dokumentacji, jeśli nie jest wykonywalnym
  generatorem ani testem.

W Stage 10:

- dodać regresję w `stage10-tighten.bats`, że summary nie raportuje
  `codex_hooks=true`;
- zaktualizować `generate-codex.sh`, żeby summary raportowało `hooks=true`.

Weryfikacja ma jasno rozdzielić:

- live/global config: `~/.codex/config.toml` może już mieć `hooks = true`;
- generated project config: `.codex/config.toml` i generator Sage nie mogą po
  patchu odtwarzać aktywnego `codex_hooks = true`.
- tracked selfhost `.codex/config.toml` też ma zostać zregenerowany albo
  zaktualizowany w tym cyklu, żeby repo nie zostawiało starego aktywnego klucza.

### 5. Regeneracja selfhost skilli

Po implementacji uruchomić Stage 7 przeciwko selfhost targetowi tak, żeby:

- `.agents/skills/sage:*/SKILL.md` wskazywały na istniejące `core/workflows/**`;
- `.agents/skills/sage:sage/` zniknęło albo nie było odtwarzane;
- `.agents/skills/sage-navigator/SKILL.md` odpowiadało core source.

Nie uruchamiać żadnego syncu ani generatora w `alex-os-dev`.

### 6. Status intake'ów źródłowych

Po verified implementation oznaczyć jako folded/covered:

- `20260509-selfhost-codex-loader-path-fix`;
- `20260509-codex-hooks-feature-flag-migration-fix`;
- `20260509-sage-navigator-skill-drift-fix`;
- `20260509-duplicate-sage-entrypoint-fix`.

### 7. Handoff do `alex-os-dev`

Utworzyć i uzupełnić
`.sage/work/20260510-codex-surface-reachability-cluster-fix/alex-os-dev-handoff.md`.
Plik ma zawierać:

- które zmiany z Sage SelfHost mogą wymagać analogicznego patcha w
  `alex-os-dev`;
- które pliki w `alex-os-dev` są kandydatami do sprawdzenia, bez ich edycji;
- evidence z tego cyklu, zwłaszcza różnicę między globalnym `hooks = true` a
  starym generated `codex_hooks = true`;
- rekomendację następnego kroku dla osobnej sesji albo osobnego approval.

Ten handoff jest deliverable tego fixa, ale implementacja cross-repo nie jest.

## Verification

Minimalny zestaw przed completion checkpoint:

- `bats runtime/platforms/codex/setup/tests/stage4-config-toml.bats`
- `bats runtime/platforms/codex/setup/tests/stage7-skills.bats`
- `bats runtime/platforms/codex/setup/tests/stage10-tighten.bats`
- `bash runtime/mcp/tests/run-regression.sh`
- targeted `rg`:
  - brak aktywnego `codex_hooks = true` w wykonywalnych generatorach/testach;
  - brak aktywnego `codex_hooks = true` w tracked `.codex/config.toml`;
  - brak `.agents/skills/sage:sage/SKILL.md` po regeneracji selfhost;
  - `.agents/skills/sage/SKILL.md` ma path-aware, istniejący reference do
    `sage-navigator`;
  - wszystkie selfhost `.agents/skills/sage:*` loader paths wskazują na
    istniejące workflow files;
  - `sage-navigator` source i exposed skill są zgodne albo ich różnica jest
    celowo wyjaśniona.
- `sed -n '1,220p' .sage/work/20260510-codex-surface-reachability-cluster-fix/alex-os-dev-handoff.md`
  żeby potwierdzić, że handoff istnieje i ma konkretne next steps.
- `git diff --check`

Jeśli dostępny test suite Codex setup ma agregator, uruchomić też targeted
setup suite dla Stage 4/7 zamiast tylko pojedynczych plików.

## Stop conditions

Zatrzymać się po decyzję, jeśli:

- `sage:sage` okazuje się publicznie wspieranym explicit skill name;
- `sage` router też musi zostać generowany, a nie ręcznie utrzymany;
- aktualny Codex Desktop/CLI pokaże sprzeczny kontrakt dla `hooks` vs
  `codex_hooks`;
- patch wymaga zmian w `alex-os-dev`;
- implementacja wymaga nowych plików poza scope.

## Checkpoint

Plan zatwierdzony przez Alexa. Implementacja może iść jednym z dwóch trybów:

- **[C] Checkpointed implementation** — wrócić po checkpoint po testach Stage 7,
  po testach Stage 4 i przed regeneracją selfhost skilli.
- **[F] Full autonomous implementation** — wykonać cały zatwierdzony scope bez
  checkpointów pośrednich aż do verification/close, ale zatrzymać się przy
  którymkolwiek stop condition.
