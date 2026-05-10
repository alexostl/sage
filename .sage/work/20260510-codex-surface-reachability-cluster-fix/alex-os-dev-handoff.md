---
cycle_id: "20260510-codex-surface-reachability-cluster-fix"
title: "Handoff: potencjalne follow-upy do alex-os-dev"
workflow: fix
phase: plan-gate
status: ready-for-follow-up
created: 2026-05-10
updated: 2026-05-10
---

# Handoff: potencjalne follow-upy do alex-os-dev

## Cel

Ten plik ma zebrać po zakończeniu klastra C konkretne follow-upy dla
`alex-os-dev`, bez mutowania tamtego repo w tym cyklu.

## Dlaczego istnieje

Klaster C dotyka powierzchni Codex w Sage SelfHost: generated project config,
loader stubs, `sage-navigator` i publiczny skill surface. `alex-os-dev` zarządza
częścią globalnego configu Codex i ma własne skille administracyjne, więc może
wymagać analogicznego patcha, ale tylko po osobnej zgodzie Alexa.

## Evidence po implementacji Sage SelfHost

- Globalny `~/.codex/config.toml` miał już `hooks = true`, więc brak
  ostrzeżenia w GUI nie dowodził, że generator Sage był czysty.
- Projektowy generated `.codex/config.toml` w `sage-selfhost` przed patchem
  zawierał aktywne `codex_hooks = true`; po regeneracji Stage 4 zawiera
  `hooks = true`.
- Generator i testy Sage SelfHost zostały zmigrowane tak, żeby aktywny managed
  block, summary Stage 10 i scaffold MCP używały `hooks`, a nie
  `codex_hooks`.
- Przed patchem tracked generator emitował albo testował `codex_hooks` w:
  - `runtime/platforms/codex/setup/lib/config-toml.sh`;
  - `runtime/platforms/codex/setup/tests/stage4-config-toml.bats`;
  - `runtime/platforms/codex/setup/generate-codex.sh`;
  - `runtime/mcp/json_to_toml.py`.
- Stage 7 w Sage SelfHost teraz wystawia publiczny router `sage`, usuwa
  redundantne `sage:sage`, kopiuje świeży `sage-navigator` z core source i
  renderuje selfhost loader paths do istniejących `core/workflows/**`.

## Co zmieniło się w Sage SelfHost

- `runtime/platforms/codex/setup/lib/config-toml.sh` emituje
  `[features].hooks = true` w managed blocku.
- `runtime/platforms/codex/setup/generate-codex.sh` raportuje `hooks=true`
  w Stage 10 summary.
- `runtime/mcp/json_to_toml.py` nie sugeruje już `codex_hooks` w scaffoldzie.
- `runtime/platforms/codex/setup/lib/skills-deploy.sh` rozróżnia selfhost i
  target repo przy ścieżkach loaderów oraz nie generuje `sage:sage`.
- `.codex/config.toml` i `.agents/skills/*` w tym repo zostały zregenerowane
  przez Sage SelfHost, nie przez sync `alex-os-dev`.

## Kandydaci do sprawdzenia w `alex-os-dev`

Nie edytować tych plików w tym cyklu. To jest lista do osobnej decyzji:

- `config/codex-config.toml`;
- `skills/alex-os:devinit/SKILL.md`;
- `skills/alex-os:sync/SKILL.md`;
- `skills/alex-os:config-status/config-status.sh`;
- ewentualne testy albo dokumenty, które literalnie raportują `codex_hooks`.

## Rekomendowany następny krok

Osobna sesja albo osobny approval powinny zrobić tylko read-first review
`alex-os-dev`:

- sprawdzić, czy `config/codex-config.toml` nadal zapisuje albo pomija
  `[features].hooks = true`;
- sprawdzić, czy `alex-os:config-status` raportuje nową flagę jako aktywną,
  a stare `codex_hooks` tylko jako legacy/drift;
- jeśli literalne `codex_hooks` występuje tylko w cleanupie legacy, zostawić je
  z komentarzem, zamiast robić masową migrację historycznych wzmianek;
- jeśli `alex-os-dev` faktycznie emituje aktywne `codex_hooks = true`, zrobić
  osobny mały patch w tamtym repo z własnym testem/status checkiem.

Ten handoff nie jest zgodą na cross-repo mutation. W tym cyklu nie wykonano
żadnych zmian w `/Users/alexostl/Developer/alex-os-dev`.
