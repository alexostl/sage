---
cycle_id: "20260510-realharness-safe-autofix-audit-fix"
title: "Fix: RealHarness rozpoznaje safe auto-fix audit"
workflow: fix
status: completed
phase: closed
approval: "approved-by-user"
classification: Moderate
semantic_reclassification: accepted
source_cycle: "20260510-codex-surface-reachability-cluster-fix"
source_bug: "BUG-QA-1"
created: 2026-05-10
updated: 2026-05-10
scope:
  - ".sage/work/20260510-realharness-safe-autofix-audit-fix/*"
  - ".sage/decisions.md"
  - "runtime/platforms/codex/harness/lib/log-parser.sh"
  - "runtime/platforms/codex/harness/run-harness.sh"
  - "runtime/platforms/codex/harness/tests/run-harness-log-parser.bats"
  - "runtime/platforms/codex/harness/tests/aggregate-signals.bats"
---

# Fix: RealHarness rozpoznaje safe auto-fix audit

## Stan

**Obecna faza:** closed — focused fix zostal zaakceptowany przez Alexa i
zamkniety.

**Nastepny krok:** zaden dla tego fixa. Ewentualny `06-action-creates-or-resumes-manifest`
to osobny harness rubric follow-up, jesli Alex kiedys uzna, ze warto go
usztywnic albo doprecyzowac.

**Semantic reclassification:** zaakceptowane, bo focused fix celowo dotyka
harness runtime i testow. Scope jest waski i wymieniony w frontmatter.

## Problem

Scenario `08-safe-autofix-metadata` w RealHarness konczy sie procesowo kodem 0
i zapisuje opisowy wpis w `.sage/.auto-fixes.log`, ale state snapshot ma
`auto_fixes: []`. Przez to agregator nie widzi wymaganego audit kind
`safe_auto_fix` i oznacza release-blocker jako czerwony.

## Root cause

`runtime/platforms/codex/harness/run-harness.sh` uzywa
`read_json_or_key_value_log` do parsowania nowych linii audit logu. Fallback
rozpoznaje obecnie tylko:

- naglowki Markdown `### ...` zawierajace slowa safe/auto-fix/scope repair;
- wpisy pipe-delimited z `kind=...`.

Realny `.sage/.auto-fixes.log` z scenario 08 ma naglowki `## 2026-...` i pola
opisowe jako bullet list. To jest czytelne dla czlowieka, ale niewidoczne dla
parsera, wiec `auto_fixes` pozostaje puste.

## Granica

Ten fix nie zmienia zachowania agentow, hookow ani zasad safe auto-fix.
Naprawia tylko harnessowy odczyt istniejacego formatu audit logu i dodaje
jednostkowy test parsera.

## Implementacja

- Wyciagnieto `read_json_or_key_value_log` z `run-harness.sh` do
  `runtime/platforms/codex/harness/lib/log-parser.sh`.
- Parser rozpoznaje teraz realne wpisy `.sage/.auto-fixes.log` zaczynajace sie
  od `## ... severity: ...` jako `kind: safe_auto_fix`.
- Dodano regresje w
  `runtime/platforms/codex/harness/tests/run-harness-log-parser.bats`.

## Verification

Przeszly:

- `bats runtime/platforms/codex/harness/tests/run-harness-log-parser.bats`
- `bats runtime/platforms/codex/harness/tests/aggregate-signals.bats`
- `bash -n runtime/platforms/codex/harness/run-harness.sh runtime/platforms/codex/harness/lib/log-parser.sh`
- `git diff --check`

Manualny parser check na raw logu z poprzedniego RealHarness runu zwrocil
`count=2` i oba wpisy jako `safe_auto_fix`.

## RealHarness rerun

Run root:

```text
/Users/alexostl/tmp/codex-realharness-cluster-c-rerun-20260510142503
```

Profile:

```text
gpt-5.4, model_reasoning_effort=low, no explicit service_tier=flex
```

Result:

- wszystkie 11 scenariuszy `codex exec` zakonczyly sie exit code 0;
- scenario `08-safe-autofix-metadata` przeszlo parserowy punkt: state snapshot
  ma `auto_fixes: [{ "kind": "safe_auto_fix" }]`;
- `v11_release_blocker_harness.complete=false`, bo scenario
  `06-action-creates-or-resumes-manifest` nie spelnilo rubryki
  `required_changed_patterns: ^\\.sage/work/[^/]+/manifest\\.md$`.

Scenario 06 state snapshot pokazal:

```json
{
  "changed_files": [
    ".sage/decisions.md",
    "AGENTS.md"
  ],
  "new_manifests": [],
  "manifests": [
    ".sage/work/20260510-agents-kombucha/manifest.md"
  ]
}
```

Interpretacja: BUG-QA-1 zostal naprawiony. Alex zaakceptowal scenario 06 jako
non-blocking harness rubric mismatch dla tego cyklu: agent uzyl istniejacego
cyklu zamiast zmieniac manifest w tym konkretnym scenariuszu, co jest
akceptowalne dla oceny focused fixa parsera.

## Closeout

Focused fix jest zamkniety. Kryterium sukcesu bylo waskie: RealHarness ma
rozpoznawac opisowe wpisy `.sage/.auto-fixes.log` jako `safe_auto_fix`.
Targeted tests i pelny rerun potwierdzily ten efekt. Pelny harness nadal moze
pokazywac `complete=false` przez scenario 06, ale to nie jest regresja ani
blocker dla tego fixa.
