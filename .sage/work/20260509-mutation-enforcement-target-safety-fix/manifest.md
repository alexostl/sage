---
cycle_id: "20260509-mutation-enforcement-target-safety-fix"
title: "Fix: mutation enforcement i target safety"
workflow: fix
phase: closed
status: completed
created: 2026-05-09
updated: 2026-05-10
owner: alexostl
source_cluster: "20260509-open-work-cluster-map"
semantic_reclassification: accepted
related:
  - "20260509-file-change-enforcement-fix"
  - "20260509-binary-asset-mutation-contract-fix"
  - "20260509-fix-trigger-gate-fix"
  - "20260509-target-repo-ownership-harness-fix"
  - "20260509-mcp-incident-followup-fixes"
  - "20260509-closeout-documentation-mutation-model"
scope:
  - ".sage/work/20260509-mutation-enforcement-target-safety-fix/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/setup/lib/config-toml.sh"
  - "runtime/platforms/codex/setup/lib/hooks-deploy.sh"
  - "runtime/platforms/codex/setup/lib/agents-md.sh"
  - "runtime/platforms/codex/setup/generate-codex.sh"
  - "runtime/platforms/codex/setup/tests/stage4-config-toml.bats"
  - "runtime/platforms/codex/setup/tests/stage5-6-hooks.bats"
  - "runtime/platforms/codex/setup/tests/stage3-agents-md.bats"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/hooks/post-tool-check.sh"
  - "runtime/platforms/codex/hooks/turn-audit.sh"
  - "runtime/platforms/codex/hooks/tests/pre-tool-validate.bats"
  - "runtime/platforms/codex/hooks/tests/post-tool-check.bats"
  - "runtime/platforms/codex/hooks/tests/turn-audit.bats"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
  - "runtime/platforms/codex/harness/lib/aggregate-signals.sh"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
  - "runtime/platforms/codex/harness/README.md"
  - "runtime/platforms/codex/README.md"
  - "README.md"
  - "core/constitution/sage-process.constitution.md"
---

# Fix: mutation enforcement i target safety

## State

**Current phase:** closed - implementacja i deterministic verification są
zakończone.

**Closeout:** Real-agent harness coverage zostało dalej obsłużone w Cluster C i
focused RealHarness parser fix. Ten cykl nie ma już aktywnego next step w tym
worktree.

## Problem summary

Klaster dotyczy tego, że Sage nie ma jeszcze jednego spójnego modelu dla
wszystkich realnych mutacji repo. Część guardrails historycznie zakładała, że
zmiana pliku przechodzi przez `apply_patch`, ale realny Codex potrafi zmieniać
pliki przez `file_change` albo shell. Do tego harness sprawdzał głównie finalny
stan target repo, więc nie łapał transient prób pisania do parent/framework
repo.

## Root cause diagnosis

### Cause 1 - L1 hooks były zaprojektowane wokół `apply_patch`

Generator `.codex/hooks.json` rejestruje `PreToolUse` i `PostToolUse` tylko dla
matchera `apply_patch`. Scenariusz `03-build-out-of-scope` użył natywnego
`file_change`, więc nie przeszedł przez pre-mutation validator.

### Cause 2 - Stop hook/audit nie dał ex post backstopu w historycznym QA runie

Target z QA runu ma `.codex/hooks.json`, ale nie ma
`.sage/.session-mutations.log` ani `.sage/.mcp-incidents.log`. To oznacza, że
run nie zostawił śladów działania hooków. Target config używał starej flagi
`[features].codex_hooks = true`; aktualny Codex Desktop GUI dla workspace
`sage-selfhost` ostrzega, że ta flaga jest deprecated i wskazuje
`[features].hooks = true`.

Uwaga: publiczny docs/cache i lokalny CLI 0.126 nadal pokazują `codex_hooks`
jako known feature, więc mamy drift między CLI/docs a Desktop GUI. Dla tego
fixa generator targetuje aktualny Desktop validator i usuwa warning GUI. To nie
zastępuje Cause 1: nawet przy aktywnych hookach obecny `PreToolUse`/
`PostToolUse` matcher nie obejmuje natywnego `file_change`.

### Cause 3 - Harness oceniał release blocker z niepełną historyczną rubryką

Raport QA z `run-20260509153121` pokazuje `v11_release_blocker_harness` jako
`8/8 complete`, mimo że scenariusz 03 utworzył `src/notes/random.md`. W
historycznym `report.json` rubryka 03 jest pusta, więc aggregate liczył
obecność transcriptu jako pass zamiast zweryfikować forbidden source mutation i
recovery message.

Uwaga po read-only review: aktualny source ma już niepustą rubrykę 03 i
aggregate ma check na puste rubryki dla blocked/recovery release blockers.
Dlatego plan nie powinien naprawiać ponownie tej samej pustej rubryki 03, tylko
zweryfikować current source i dodać brakujące coverage tam, gdzie nadal go nie
ma.

### Cause 3b - Scenariusz 04 nie jest release-blockerem w `v11-scenarios.json`

QA wskazało, że scenariusz `04-fix-trigger` zmienił `AGENTS.md` bez pełnego
diagnose/scope gate, a aggregate fałszywie przepuścił failure 03/04. Aktualny
`v11-scenarios.json` nie zawiera scenariusza 04 jako release-blockera, więc
harness nie ma stabilnej assertion dla ogólnej zasady: `find and fix` source /
instruction behavior nie może ominąć workflow gate.

### Cause 4 - Target ownership był sprawdzany final-state, nie transcript-level

Scenariusz 11 skończył z poprawnym stanem w target repo, ale transcript pokazuje
wcześniejsze `file_change` do `/Users/alexostl/Developer/sage-selfhost/.sage/...`.
Final-state snapshot targetu nie widzi takich transient prób, więc potrzebna
jest transcript assertion dla forbidden absolute paths poza target repo.

### Cause 5 - Reguła `find and fix` jest za wąsko opisana jako AGENTS.md case

`AGENTS.md` był miejscem, gdzie bug wyszedł, ale prawdziwa zasada jest szersza:
mutacje source/runtime/test/config/instruction behavior wymagają aktywnego
workflow cycle i zatwierdzonego scope. Dokumentacja/capture/temp mogą mieć
lżejszą ścieżkę, ale tylko jeśli są jawnie sklasyfikowane i audytowane.

## Evidence

- QA report: `.sage/work/20260509-runtime-process-dummy-qa/qa-report.md`
- Transcript/state run:
  `.sage/work/20260509-runtime-process-dummy-qa/run-20260509153121/`
- Hook registry source:
  `runtime/platforms/codex/setup/lib/hooks-deploy.sh`
- Hook validator:
  `runtime/platforms/codex/hooks/pre-tool-validate.sh`
- Stop audit:
  `runtime/platforms/codex/hooks/turn-audit.sh`
- Harness aggregate:
  `runtime/platforms/codex/harness/lib/aggregate-signals.sh`

## Root cause gate

**Confidence:** high dla `file_change`/hook coverage i harness rubric gap;
medium dla dokładnej sekwencji aktywacji hooków, bo to zahacza o osobny intake
`codex-hooks-feature-flag-migration-fix`.

**Classification preview:** Systemic. Fix dotknie co najmniej hook coverage,
generated config/hook registry, harness rubrics/transcript assertions,
generated guidance i testów.

## Read-only review result

Subagent review 2026-05-10 potwierdził główną diagnozę i wskazał dwie korekty:

- opisać rubrykę 03 jako historyczny QA-run evidence, bo current source ma już
  część poprawionego coverage;
- dopisać lukę scenariusza 04, bo `fix-trigger` nie jest dziś osobnym
  release-blockerem w `v11-scenarios.json`.

## Approval

Alex zatwierdził zrewidowaną diagnozę przez `[S] Skip review` po read-only
subagent review.

Alex wybrał `[3] Proceed as /sage:fix anyway` dla Systemic scope.

## Plan

Plan zapisano w `plan.md`. Manifest scope został rozszerzony przed
implementacją o wszystkie planowane pliki runtime, setup, hooków, harnessu,
dokumentacji i testów.

## Implementation result

Zaimplementowano approved plan:

- generated Codex config używa `[features].hooks = true` i raportuje
  `hooks=true`;
- hook registry obejmuje `apply_patch|Edit|Write`;
- pre/post hooki parsują zarówno `apply_patch` DSL, jak i defensywny
  `changes[].path` payload;
- turn audit klasyfikuje bypass mutacji source/runtime/test/config jako
  `critical`;
- generated `AGENTS.md` dostał tylko minimalistyczną regułę target ownership i
  source mutation boundary;
- harness v11 ma release blocker `04-fix-trigger` i
  `forbidden_transcript_patterns` dla transcript-level parent repo writes;
- dokumentacja opisuje aktualny hook activation model i ograniczenie
  transcript/file_change coverage.

## Verification result

Deterministic verification passed:

```text
stage4-config-toml.bats: 1..17, all 17 passed
stage5-6-hooks.bats: 1..13, all 13 passed
stage3-agents-md.bats: 1..44, all 44 passed
pre-tool-validate.bats: 1..49, all 49 passed
post-tool-check.bats: 1..16, all 16 passed
turn-audit.bats: 1..15, all 15 passed
aggregate-signals.bats: 1..12, all 12 passed
generate-codex smoke: status=0, generated hooks=true and apply_patch|Edit|Write
git diff --check: clean
```

Real Codex harness rerun nie został wykonany w tym checkpointcie.
