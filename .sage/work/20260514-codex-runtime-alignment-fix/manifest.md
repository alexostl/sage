---
cycle_id: "20260514-codex-runtime-alignment-fix"
title: "Fix: alignment Codex runtime config i hooks"
workflow: fix
phase: intake
status: intake
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
needs-triage: true
priority: P1
source: "conversation"
suggested_workflow: fix
related:
  - ".codex/config.toml"
  - ".codex/hooks.json"
  - ".codex/hooks/**"
  - "runtime/platforms/codex/setup/lib/config-toml.sh"
  - "runtime/platforms/codex/setup/lib/hooks-deploy.sh"
  - "runtime/platforms/codex/setup/tests/stage4-config-toml.bats"
  - "runtime/platforms/codex/setup/tests/stage5-6-hooks.bats"
  - "runtime/platforms/codex/setup/tests/stage10-tighten.bats"
  - "runtime/platforms/codex/hooks/**"
  - "runtime/platforms/codex/README.md"
  - "runtime/platforms/codex/harness/README.md"
  - "runtime/platforms/codex/harness/run-harness.sh"
scope:
  - ".sage/work/20260514-codex-runtime-alignment-fix/*"
  - ".sage/decisions.md"
  - ".codex/config.toml"
  - ".codex/hooks.json"
  - ".codex/hooks/**"
  - "runtime/platforms/codex/setup/lib/config-toml.sh"
  - "runtime/platforms/codex/setup/lib/hooks-deploy.sh"
  - "runtime/platforms/codex/setup/tests/stage4-config-toml.bats"
  - "runtime/platforms/codex/setup/tests/stage5-6-hooks.bats"
  - "runtime/platforms/codex/setup/tests/stage10-tighten.bats"
  - "runtime/platforms/codex/hooks/**"
  - "runtime/platforms/codex/README.md"
  - "runtime/platforms/codex/harness/README.md"
  - "runtime/platforms/codex/harness/run-harness.sh"
---

# Fix: alignment Codex runtime config i hooks

## State

**Current phase:** intake. To jest jedna inicjatywa dla pozostalych problemow
alignmentu Codex runtime/config po audycie Batchy 1-5.

**Out of scope:** worktree cleanup i stare worktree configi sa naprawiane w
osobnym watku. Ten fix nie ma sprzatac historycznych worktree ani harness
outputs, chyba ze root cause pokaze, ze biezacy generator/testy nadal je
traktuja jako aktywne surface.

## Problem

Po sprawdzeniu Batchy 1-5 wzgledem aktualnego Codex Desktop runtime pojawily
sie trzy realne problemy do zamkniecia jednym fixem:

1. **Effective config check:** glowne configi maja juz `[features].hooks =
   true`, ale nie mamy jednego testu/diagnostyki, ktory pokazuje co Codex
   faktycznie laduje dla biezacego projektu i aktywnych config layers.
2. **Hook command path stability:** repo-local hook commands sa generowane jako
   relatywne `.codex/hooks/...`, a Codex uruchamia hooks z session `cwd`.
   Start z podkatalogu moze wiec ominac albo zepsuc hook command.
3. **Active hooks registry sync:** aktywny selfhost `.codex/hooks.json` moze
   dryfowac od generatora, szczegolnie dla matcherow `Bash` oraz
   `Edit|Write`. Potrzebny jest jawny check albo regeneracja surface.
4. **Deployed hook script drift:** audyt logow z 2026-05-14 pokazal, ze
   zrodlowe hooki w `runtime/platforms/codex/hooks/` zawieraja poprawki Batcha
   5 (`.sage/decisions.md` nie jest frontmatter artifact, dirty baseline,
   dedupe `phase_jump_observed`, `capture_documentation_mutation`), ale aktywne
   `.codex/hooks/*.sh` w selfhost byly starsze. W praktyce runtime dalej
   emitowal stare false positives mimo naprawionego source.

## Desired behavior

- Sage potrafi szybko powiedziec, czy biezacy projekt Codex ma aktywny
  `[features].hooks = true` i nie laduje deprecated `codex_hooks` z aktywnej
  warstwy configu.
- Generated repo-local hooks dzialaja niezaleznie od tego, czy Codex zostal
  uruchomiony z repo root czy z podkatalogu.
- `.codex/hooks.json` dla aktywnego selfhost/project surface jest zgodny z
  generatorem albo test jasno wykrywa drift.
- Aktywne `.codex/hooks/*.sh` sa zsynchronizowane z source hooks albo
  diagnostyka jasno pokazuje drift przed interpretacja `.sage/.mcp-incidents.log`.

## Candidate scope

- Dodac albo rozszerzyc deterministic tests dla:
  - braku aktywnego `codex_hooks = true` w generated config;
  - obecnosci `hooks = true`;
  - stable hook command paths wzgledem git root;
  - zgodnosci generated `.codex/hooks.json` z oczekiwanymi matcherami.
- Poprawic `runtime/platforms/codex/setup/lib/hooks-deploy.sh`, jesli root
  cause potwierdzi, ze relatywne command paths sa realnym ryzykiem.
- Poprawic selfhost `.codex/hooks.json` albo dodac safe sync/check, jesli jest
  to aktywna powierzchnia, ktora powinna byc zgodna z generatorem.
- Dodac check porownujacy aktywne `.codex/hooks/*.sh` z source hooks albo
  upewnic sie, ze `bin/sage update` regeneruje je deterministycznie.
- Zaktualizowac README/harness notes tak, zeby nie odwracaly decyzji:
  Desktop/project config uzywa `hooks = true`; ewentualny legacy
  `--enable codex_hooks` moze zostac tylko jako wyraznie opisany CLI/harness
  compatibility shim, jesli nadal jest wymagany.

## Stop conditions

- Jesli Codex Desktop/CLI effective config nie da sie odczytac deterministycznie
  z repo, nie zgadywac. Zapisac limitation i wymagac manualnego runtime probe.
- Jesli fix zacznie obejmowac worktree cleanup, splitowac do watku worktree,
  ktory juz istnieje.
