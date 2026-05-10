---
cycle_id: "20260509-hook-routing-command-audit"
title: "Fix: kompleksowy audyt routingu i komend w hookach"
workflow: fix
phase: folded
status: completed
created: 2026-05-09
updated: 2026-05-09
owner: alexostl
needs-triage: false
priority: P1
folded_into: "20260509-runtime-workflow-enforcement-hardening"
source_threads:
  - "current"
related:
  - ".sage/work/20260509-cross-cycle-scope-workaround-fix/manifest.md"
  - ".sage/work/20260509-multi-active-cycle-model-fix/manifest.md"
  - ".sage/work/20260509-closeout-documentation-mutation-model/manifest.md"
  - ".sage/work/20260509-runtime-process-reliability-patch/manifest.md"
suggested_workflow: fix
scope:
  - ".sage/work/20260509-hook-routing-command-audit/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/hooks/**"
  - "runtime/platforms/claude-code/hooks/**"
  - "runtime/platforms/*/setup/**"
  - "core/workflows/**"
  - "core/capabilities/orchestration/**"
  - "bin/sage"
  - "runtime/cli/**"
  - "runtime/platforms/codex/harness/**"
---

# Fix: kompleksowy audyt routingu i komend w hookach

## State

**Current phase:** folded - najważniejszy błąd routingu (`sage continue` jako
nieistniejący CLI subcommand) został pokryty przez
`20260509-runtime-workflow-enforcement-hardening`.

**Resolution:** `bin/sage status` i hook recovery wording zostały zmienione na
`sage:continue` albo natural-language resume, a status/recovery ścieżki mają
regresje w Bats.

**Verification:** `.sage/work/20260509-runtime-workflow-enforcement-qa/qa-report.md`
potwierdza PASS dla `sage status` parked/intake guidance oraz no-active
implementation recovery.

**Residual:** Pełny style/content review wszystkich blocking hook messages
pozostaje osobnym review/follow-upem:
`.sage/work/20260509-blocking-hook-guidance-review/`.

## Finding

Podczas capture problemu z końcówki wątku
`codex://threads/019e0781-7a63-7761-bbce-01fbee72f470` hook zablokował edycję
intake'u i podał next legal move:

```text
run `sage status`, then explicitly `sage continue` the right cycle
```

`bin/sage status` również drukuje przy parked/intake cycles:

```text
next: sage continue
```

Jednocześnie `bin/sage continue ...` zwraca `Unknown command: continue`.
`sage:continue` istnieje jako skill/workflow, ale nie jako CLI subcommand.

To oznacza, że przynajmniej część hook/status recovery UX emituje nieprawdziwy
albo niejednoznaczny routing. Agent dostaje instrukcję, której nie może wykonać
narzędziowo, i może zacząć szukać obejść w stylu tymczasowej zmiany scope.

## Initial evidence

Szybki grep pokazał co najmniej dwa konkretne miejsca do sprawdzenia:

- `runtime/platforms/codex/hooks/pre-tool-validate.sh` - komunikat
  `Next legal move: run \`sage status\`, then explicitly \`sage continue\`...`;
- `bin/sage` - `status` pokazuje `next: sage continue` dla parked/intake.

To nie jest pełny audyt. Ten cycle ma wymusić pełny sweep wszystkich miejsc,
które emitują route/recovery/next-step instructions.

## Scope of audit

Przyszły fix ma sprawdzić co najmniej:

- Codex hook scripts: `session-init`, `pre-tool-validate`, `post-tool-check`,
  `turn-audit` oraz helpery recovery;
- Claude Code hook scripts i generated setup guidance;
- `bin/sage status`, `bin/sage doctor`, top-level help i unknown-command UX;
- `core/workflows/status.workflow.md`, `continue.workflow.md` oraz workflow
  checkpoint footers typu "type /build";
- generated Codex/Claude instructions (`AGENTS.md` / `CLAUDE.md` sources);
- harness scenarios i assertions, żeby złe komendy nie wróciły jako stringi.

## Desired behavior

Komunikaty routingu muszą odróżniać:

- **CLI commands** - realnie obsługiwane przez `bin/sage`, np. `bin/sage status`;
- **Codex skills/workflows** - np. `sage:continue`, `sage:fix`, `sage:build`;
- **slash command UX** w klientach, gdzie składnia może być `/sage:continue`
  albo inna zależnie od platformy;
- **natural-language instruction** dla agenta, gdy nie ma realnej komendy CLI.

Nie wolno sugerować `sage <subcommand>`, jeśli `bin/sage <subcommand>` nie
istnieje. Nie wolno też mieszać `/continue`, `/sage:continue`, `sage continue`
i `sage:continue` bez platformowego kontekstu.

## Acceptance direction

Przyszły plan powinien zawierać:

- inventory tabelę wszystkich routing/recovery strings z plikiem i linią;
- test, który waliduje command-like strings w hook/status output przeciwko
  realnym CLI subcommands albo jawnej allowliście skill/slash syntax;
- poprawkę dla znalezionych komunikatów, zaczynając od `sage continue`;
- real-agent albo harness scenario, w którym blocked mutation dostaje
  wykonalny next legal move;
- decyzję, czy dodać `bin/sage continue` jako alias, czy poprawić komunikaty na
  `sage:continue`/workflow activation. Domyślnie nie zakładać aliasu bez
  diagnozy.

## Boundary

Ten intake nie zatwierdza implementacji ani nie rozstrzyga, czy dodać nową
komendę CLI. Najpierw potrzebna jest diagnoza wszystkich hooków i surfaces,
które mogą prowadzić agenta zablokowanego przez Sage.
