---
cycle_id: "20260509-codex-hooks-feature-flag-migration-fix"
title: "Fix: migracja flagi Codex hooks z codex_hooks na hooks"
workflow: fix
phase: completed
status: completed
created: 2026-05-09
updated: 2026-05-13
owner: alexostl
priority: P1
needs-triage: true
folded_into: "20260509-selfhost-codex-loader-path-fix"
source: "conversation"
suggested_workflow: fix
related:
  - "runtime/platforms/codex/setup/lib/config-toml.sh"
  - "runtime/platforms/codex/setup/generate-codex.sh"
  - "runtime/mcp/json_to_toml.py"
  - "/Users/alexostl/Developer/alex-os-dev/config/codex-config.toml"
  - "/Users/alexostl/Developer/alex-os-dev/skills/alex-os:devinit/SKILL.md"
  - "/Users/alexostl/Developer/alex-os-dev/skills/alex-os:config-status/config-status.sh"
---

# Fix: migracja flagi Codex hooks z codex_hooks na hooks

## State

**Current phase:** completed - folded into Batch 4 anchor
`20260509-selfhost-codex-loader-path-fix`.

**Next step:** Brak osobnej implementacji. Batch 4 anchor synchronizuje aktywny
selfhost `.codex/config.toml` do `[features].hooks = true`.

## Finding

Codex runtime zgłosił ostrzeżenie:

```text
[features].codex_hooks is deprecated. Use [features].hooks instead.

Enable it with --enable hooks or [features].hooks in config.toml.
```

Lokalny przegląd pokazał drift:

- `~/.codex/config.toml` nie ustawia aktywnie ani `codex_hooks = true`, ani
  `hooks = true`; ma tylko `[features].memories = false`;
- Sage generator nadal emituje `codex_hooks = true` w managed blocku
  `.codex/config.toml`;
- `runtime/mcp/json_to_toml.py` nadal dokumentuje i rozpoznaje
  `codex_hooks`;
- outputy/statusy `generate-codex.sh` nadal mówią o `codex_hooks=true`;
- alex-os source of truth i skille administracyjne nadal odnoszą się do
  `codex_hooks`.

Oficjalne docs MCP i `codex features list` w `codex-cli 0.126.0-alpha.15`
wciąż pokazywały `codex_hooks` jako stable, więc implementacja musi traktować
runtime warning jako ważny sygnał, ale powinna najpierw zweryfikować zachowanie
lokalnej binarki i config parsera.

## Desired Behavior

Sage Codex setup powinien generować aktualny klucz:

```toml
[features]
hooks = true
```

oraz nie powinien odtwarzać przestarzałego `codex_hooks = true` przy
`sage update`, `generate-codex.sh`, syncu dogfood hooków ani konwersji MCP
JSON -> TOML.

## Candidate Scope

- `runtime/platforms/codex/setup/lib/config-toml.sh`
- `runtime/platforms/codex/setup/generate-codex.sh`
- `runtime/mcp/json_to_toml.py`
- testy setupu Codex, jeśli asercje literalnie sprawdzają `codex_hooks`
- dokumentacja runtime Codex, jeśli zawiera literalne przykłady starej flagi

## Cross-Repo Follow-Up

`alex-os-dev` może wymagać osobnego patcha, bo zarządza globalnym
`~/.codex/config.toml` i ma własne skille `alex-os:devinit`,
`alex-os:sync`, `alex-os:config-status`.

Jeśli fix w Sage SelfHost zmienia tylko projektowe `.codex/config.toml`
generowane przez `sage update`, alex-os nadal może przywracać globalny config
bez `hooks = true` albo raportować hooki starą nazwą.

## Boundary

Ten intake nie zatwierdza jeszcze implementacji. Nie należy masowo migrować
wszystkich historycznych wzmianek w dokumentacji, jeśli nie są wykonywalnym
źródłem configu albo testem regresji.
