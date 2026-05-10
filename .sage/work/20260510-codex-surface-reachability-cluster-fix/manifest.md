---
cycle_id: "20260510-codex-surface-reachability-cluster-fix"
title: "Fix: klaster powierzchni Codex, configu i reachability skilli"
workflow: fix
status: completed
phase: closed
approval: "approved-by-user"
implementation_mode: "full-autonomous-until-verification"
autonomy_grant: "approved plan snapshot as of 2026-05-10; scope limited to manifest.scope and plan stop conditions"
semantic_reclassification: accepted
classification: Systemic
source_cluster: "20260509-open-work-cluster-map"
created: 2026-05-10
updated: 2026-05-10
source_intakes:
  - "20260509-selfhost-codex-loader-path-fix"
  - "20260509-codex-hooks-feature-flag-migration-fix"
  - "20260509-sage-navigator-skill-drift-fix"
  - "20260509-duplicate-sage-entrypoint-fix"
scope:
  - ".sage/work/20260510-codex-surface-reachability-cluster-fix/*"
  - ".sage/work/20260509-selfhost-codex-loader-path-fix/manifest.md"
  - ".sage/work/20260509-selfhost-codex-loader-path-fix/root-cause.md"
  - ".sage/work/20260509-codex-hooks-feature-flag-migration-fix/manifest.md"
  - ".sage/work/20260509-sage-navigator-skill-drift-fix/manifest.md"
  - ".sage/work/20260509-duplicate-sage-entrypoint-fix/manifest.md"
  - ".sage/decisions.md"
  - ".codex/config.toml"
  - "runtime/platforms/codex/setup/lib/skills-deploy.sh"
  - "runtime/platforms/codex/setup/lib/config-toml.sh"
  - "runtime/platforms/codex/setup/generate-codex.sh"
  - "runtime/mcp/json_to_toml.py"
  - "runtime/mcp/tests/run-regression.sh"
  - "runtime/platforms/codex/setup/tests/stage4-config-toml.bats"
  - "runtime/platforms/codex/setup/tests/stage7-skills.bats"
  - "runtime/platforms/codex/setup/tests/stage10-tighten.bats"
  - ".agents/skills/sage/SKILL.md"
  - ".agents/skills/sage-navigator/SKILL.md"
  - ".agents/skills/sage:*/SKILL.md"
---

# Cykl: klaster powierzchni Codex, configu i reachability skilli

## Stan

**Obecna faza:** closed — implementacja klastra C, deterministic verification i
focused fix RealHarness BUG-QA-1 są zakończone. Dokumentacja cyklu jest w
`manifest.md`, `plan.md`, `root-cause.md`, `qa-report.md` i
`alex-os-dev-handoff.md`.

**Zamknięcie:** Alex zaakceptował scenario 06 z rerunu RealHarness jako
non-blocking harness rubric mismatch dla tego cyklu. Scenario 08, które było
blokującym BUG-QA-1 dla Cluster C, zostało naprawione i potwierdzone rerunem.

**Semantic reclassification:** zaakceptowane dla zatwierdzonego scope, bo patch
celowo dotyka testów, generatorów, tracked configu i wystawionych skilli
selfhost.

## Kontekst

Ten cykl realizuje klaster C z
`.sage/work/20260509-open-work-cluster-map/cluster-map.md`, czyli jeden większy
patch dla powierzchni, przez którą Codex dociera do Sage:

- selfhost/target loader paths;
- migracja flagi Codex hooks z `codex_hooks` na `hooks`;
- świeżość i reachability `sage-navigator`;
- publiczny skill surface i redundantny `sage:sage`.

## Granica

To jest umbrella fix dla klastra C, nie samotny intake. Kolejność diagnozy może
zacząć się od loaderów, ale plan ma objąć cały reachability/config surface.

Cross-repo follow-upy w `alex-os-dev` są poza zakresem implementacji tego cyklu,
chyba że Alex da osobną zgodę na konkretną zmianę w tamtym repo.

## Verification

Przeszły:

- `bats runtime/platforms/codex/setup/tests/stage4-config-toml.bats`
- `bats runtime/platforms/codex/setup/tests/stage7-skills.bats`
- `bats runtime/platforms/codex/setup/tests/stage10-tighten.bats`
- `bash runtime/mcp/tests/run-regression.sh`
- targeted checks dla braku aktywnego `codex_hooks = true`, braku
  `.agents/skills/sage:sage/SKILL.md`, istniejących selfhost loader paths,
  zgodności `sage-navigator` z core source i `git diff --check`.

## RealHarness QA

**Report:** `.sage/work/20260510-codex-surface-reachability-cluster-fix/qa-report.md`

**Raw artifacts:** `/Users/alexostl/tmp/codex-realharness-cluster-c-20260510132601/out`

**Profile:** `gpt-5.4`, `model_reasoning_effort=low`, no explicit
`service_tier=flex`, isolated `CODEX_HOME`, TMP output.

**Result:** process exit 0 and all 11 scenario exit files are 0, but
`v11_release_blocker_harness.complete=false` because scenario
`08-safe-autofix-metadata` is missing audit kind `safe_auto_fix`.

**Recommendation:** do not call the RealHarness release-blocker green until
BUG-QA-1 is fixed and RealHarness is rerun.

## Focused QA fix i final handoff verification

BUG-QA-1 został domknięty w cyklu
`20260510-realharness-safe-autofix-audit-fix`. Rerun RealHarness:

```text
/Users/alexostl/tmp/codex-realharness-cluster-c-rerun-20260510142503
```

potwierdził, że scenario `08-safe-autofix-metadata` wystawia teraz
`auto_fixes: [{ "kind": "safe_auto_fix" }]`. Pełny
`v11_release_blocker_harness.complete` nadal był `false` przez scenario
`06-action-creates-or-resumes-manifest`, ale Alex zaakceptował to jako
non-blocking mismatch rubryki dla tego fixa.

Przed lokalnym handoffem ponownie przeszły:

- `bats runtime/platforms/codex/setup/tests/stage4-config-toml.bats`
- `bats runtime/platforms/codex/setup/tests/stage7-skills.bats`
- `bats runtime/platforms/codex/setup/tests/stage10-tighten.bats`
- `bash runtime/mcp/tests/run-regression.sh`
- `bats runtime/platforms/codex/harness/tests/run-harness-log-parser.bats`
- `bats runtime/platforms/codex/harness/tests/aggregate-signals.bats`
- `bash -n runtime/platforms/codex/harness/run-harness.sh runtime/platforms/codex/harness/lib/log-parser.sh`
- `git diff --check`
