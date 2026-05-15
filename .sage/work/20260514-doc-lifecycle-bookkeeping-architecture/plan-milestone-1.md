---
title: "Milestone 1 plan: decisions policy i retention"
cycle_id: "20260514-doc-lifecycle-bookkeeping-architecture"
workflow: build
phase: plan
status: completed
created: 2026-05-14
updated: 2026-05-14
approved_at: "2026-05-14"
approved_by: "alexostl"
autonomy_grant: full
related:
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/spec.md"
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/plan.md"
  - ".sage/docs/decision-doc-lifecycle-bookkeeping.md"
---

# Milestone 1 plan: decisions policy i retention

## Constitution constraints

- Tests before code: kazdy behavior-level change dostaje deterministic test
  albo aktualizacje istniejacego testu przed source wording/runtime change.
- Minimization pass: preferujemy konsolidacje istniejacych surfaces zamiast
  dodawania kolejnej warstwy instrukcji.
- Scope discipline: Milestone 1 dotyczy Codex core decision capture policy,
  retention, archive read policy i harness Signal 8. Closeout reconciliation,
  `work_index`, Claude Code, Antigravity, generic platform docs i legacy
  Claude plugin zostaja poza tym milestone.

## Technology decisions

Using existing stack: Bash, Bats, `jq`, `git` i istniejace generator/test
patterns. Nie dodajemy nowych dependencies.

## Tasks

- [x] **Task 1: Decision capture policy surface tests**
  - **Read first:** `core/constitution/sage-process.constitution.md`,
    `core/workflows/build.workflow.md`, `core/workflows/fix.workflow.md`,
    `core/workflows/architect.workflow.md`, `core/workflows/analyze.workflow.md`,
    `core/capabilities/review/auto-review/SKILL.md`,
    `core/capabilities/review/auto-qa/SKILL.md`,
    `core/capabilities/orchestration/sage-navigator/SKILL.md`,
    `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`,
    `runtime/platforms/codex/setup/tests/alex-native-core-text.bats`,
    `runtime/platforms/codex/setup/tests/subagent-review-policy.bats`.
  - **Files:** `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`,
    `runtime/platforms/codex/setup/tests/alex-native-core-text.bats`,
    `runtime/platforms/codex/setup/tests/subagent-review-policy.bats`.
  - **Action:** Dodac/zmienic assertions, ktore wymagaja, zeby generated
    Codex `AGENTS.md`, canonical constitution, workflow checkpoint surfaces i
    auto-review/auto-QA mowily: `decisions.md` jest decision logiem, nie process
    logiem; review verdict, intermediate checkpoint, completion checkpoint
    przed approval, frontmatter/process flip i pure bookkeeping nie tworza
    global decision entry domyslnie.
  - **Test:** Testy maja najpierw failowac na starym wording.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats runtime/platforms/codex/setup/tests/subagent-review-policy.bats`
  - **Depends on:** none.

- [x] **Task 2: Decision capture policy wording**
  - **Read first:** Task 1 tests, `core/constitution/sage-process.constitution.md`,
    `core/workflows/build.workflow.md`, `core/workflows/fix.workflow.md`,
    `core/workflows/architect.workflow.md`, `core/workflows/analyze.workflow.md`,
    `core/capabilities/orchestration/build-loop/SKILL.md`,
    `core/capabilities/orchestration/sage-navigator/SKILL.md`,
    `runtime/platforms/codex/setup/lib/agents-md.sh`,
    `core/capabilities/review/auto-review/SKILL.md`,
    `core/capabilities/review/auto-qa/SKILL.md`.
  - **Files:** same as read-first source files.
  - **Action:** Zastapic stare Rule 7/process-log wording waska polityka:
    decision-worthy events trafiaja do `.sage/decisions.md`; auto-review,
    auto-QA, intermediate revisions, completion checkpoint przed approval i
    pure bookkeeping nie tworza osobnego global decision entry domyslnie.
  - **Test:** Task 1 tests.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats runtime/platforms/codex/setup/tests/subagent-review-policy.bats`
  - **Depends on:** Task 1.

- [x] **Task 3: Archive rotation tests**
  - **Read first:** `runtime/platforms/codex/hooks/post-tool-check.sh`,
    `runtime/platforms/codex/hooks/tests/post-tool-check.bats`.
  - **Files:** `runtime/platforms/codex/hooks/tests/post-tool-check.bats`.
  - **Action:** Dodac failing tests dla automatycznej rotacji i jej safety
    constraints: primary checkout rotuje do 50 current +
    `.sage/decisions-archive.md`; linked worktree nie rotuje; archive jest
    newest-first; header zostaje zachowany; short/exactly-50 nie rotuje; 51
    entries rotuje jedna decyzje; malformed/headerless file fail-open bez
    utraty danych; powtorne uruchomienie jest idempotentne.
  - **Test:** Nowe Bats tests maja failowac przed implementacja helpera.
  - **Verify:** `bats runtime/platforms/codex/hooks/tests/post-tool-check.bats`
  - **Depends on:** none.

- [x] **Task 4: Codex PostToolUse assumption check**
  - **Read first:** `runtime/platforms/codex/hooks/post-tool-check.sh`,
    `runtime/platforms/codex/hooks/tests/post-tool-check.bats`.
  - **Files:** `runtime/platforms/codex/hooks/tests/post-tool-check.bats`;
    `plan-milestone-1.md` only if the assumption is false and needs handoff.
  - **Action:** Verify by deterministic fixture that `post-tool-check.sh`
    receives a payload with `tool_input.command` for `apply_patch`, can parse
    claimed paths, and rotation only runs after successful patch response. If
    this fixture cannot represent actual Codex PostToolUse behavior, stop
    before archive rotation implementation.
  - **Test:** Existing/new `post-tool-check.bats` payload fixture.
  - **Verify:** `bats runtime/platforms/codex/hooks/tests/post-tool-check.bats`
  - **Depends on:** Task 3.

- [x] **Task 5: Archive rotation implementation**
  - **Read first:** Task 3 tests, `runtime/platforms/codex/hooks/post-tool-check.sh`.
  - **Files:** `runtime/platforms/codex/hooks/post-tool-check.sh`,
    opcjonalnie nowy maly helper w `runtime/platforms/codex/hooks/lib/`.
  - **Action:** Po udanym `apply_patch` dotykajacym `.sage/decisions.md`,
    w primary checkout rotowac decisions: 50 newest zostaje w
    `.sage/decisions.md`, reszta idzie do jednego newest-first
    `.sage/decisions-archive.md`. Primary checkout wykrywac przez
    `git rev-parse --path-format=absolute --git-dir` ==
    `git rev-parse --path-format=absolute --git-common-dir`; linked worktree
    nie rotuje. Hook musi zachowac posture `exit 0 always`, fail-open na
    malformed/nieparsowalnym pliku, atomic/no-loss writes przez temp files i
    idempotency.
  - **Test:** Task 3 tests.
  - **Verify:** `bats runtime/platforms/codex/hooks/tests/post-tool-check.bats`
  - **Depends on:** Task 3, Task 4.

- [x] **Task 6: Signal 8 and archive read policy tests**
  - **Read first:** `runtime/platforms/codex/harness/README.md`,
    `runtime/platforms/codex/harness/lib/aggregate-signals.sh`,
    `runtime/platforms/codex/harness/tests/aggregate-signals.bats`,
    `runtime/platforms/codex/harness/v11-scenarios.json`.
  - **Files:** `runtime/platforms/codex/harness/tests/aggregate-signals.bats`,
    `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`.
  - **Action:** Dodac/zmienic tests, ktore wymagaja archive read policy
    search-first oraz definiuja Signal 8 przez explicit metadata contract w
    `v11-scenarios.json` albo rownowaznym fixture field:
    - scenarios/fixtures z `requires_decision_entry: true` bez
      `.sage/decisions.md` nadal sa wykrywane;
    - scenarios/fixtures z `requires_decision_entry: false` albo brakiem flagi
      nie sa karane za process-only/frontmatter-only/bookkeeping flip;
    - aggregator nie klasyfikuje natural-language diffu jako `decision-worthy`.
  - **Test:** Tests maja failowac przed aktualizacja harness/instruction text.
  - **Verify:** `bats runtime/platforms/codex/harness/tests/aggregate-signals.bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - **Depends on:** Task 1, Task 5.

- [x] **Task 7: Archive read policy and Signal 8 implementation**
  - **Read first:** Task 6 tests, `runtime/platforms/codex/harness/README.md`,
    `runtime/platforms/codex/harness/lib/aggregate-signals.sh`,
    `runtime/platforms/codex/harness/v11-scenarios.json`,
    `runtime/platforms/codex/setup/lib/agents-md.sh`.
  - **Files:** same as read-first source files.
  - **Action:** Dopisac generated instruction text dla archive read policy:
    `rg` first, fragment read, full archive read only with named reason.
    Zmienic Signal 8 zgodnie z explicit metadata contract z Task 6. Jezeli
    implementation wymaga klasyfikatora natural-language, stop zamiast
    maskowania ryzyka.
  - **Test:** Task 6 tests.
  - **Verify:** `bats runtime/platforms/codex/harness/tests/aggregate-signals.bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - **Depends on:** Task 6.

- [x] **Task 8: Milestone verification**
  - **Read first:** all changed files.
  - **Files:** no new implementation files unless tests reveal a missed
    scoped surface.
  - **Action:** Run deterministic suites touched by Tasks 1-7 and `git diff
    --check`. Full RealHarness is deferred to final cross-milestone
    verification, unless implementation changes runtime behavior in a way that
    deterministic tests cannot cover.
  - **Test:** N/A.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats runtime/platforms/codex/setup/tests/subagent-review-policy.bats runtime/platforms/codex/hooks/tests/post-tool-check.bats runtime/platforms/codex/harness/tests/aggregate-signals.bats && git diff --check`
  - **Depends on:** Tasks 1-7.

## Milestone result

Milestone 1 zostal zaimplementowany i zaakceptowany przez Alexa.

- `decisions.md` jest opisany jako decision log, nie process log.
- Auto-review/Auto-QA verdicts i pure bookkeeping sa process evidence, bez
  domyslnego global decision entry.
- Codex PostToolUse rotuje `.sage/decisions.md` do 50 current entries i
  `.sage/decisions-archive.md` tylko w primary checkout.
- Linked Git worktrees nie rotuja archive.
- Signal 8 uzywa explicit `requires_decision_entry`, bez natural-language
  classifiera.
- `AGENTS.md` nie ma twardego limitu bajtow; test pilnuje braku verbose
  explainers zamiast sztywnego rozmiaru.
- Full RealHarness zostaje na final cross-milestone verification.

Verification passed:

```text
bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats runtime/platforms/codex/setup/tests/subagent-review-policy.bats runtime/platforms/codex/hooks/tests/post-tool-check.bats runtime/platforms/codex/harness/tests/aggregate-signals.bats && git diff --check
1..106
ok 106 aggregate-signals: bug-report-no-fix fails if transcript mentions parent repo .sage writes
```

## Scope

Approved implementation scope for Milestone 1 should include only:

- `.sage/work/20260514-doc-lifecycle-bookkeeping-architecture/*`
- `.sage/docs/decision-doc-lifecycle-bookkeeping.md`
- `.sage/decisions.md`
- `core/constitution/sage-process.constitution.md`
- `core/workflows/build.workflow.md`
- `core/workflows/fix.workflow.md`
- `core/workflows/architect.workflow.md`
- `core/workflows/analyze.workflow.md`
- `core/workflows/review.workflow.md` (inventory/exclusion check only; do not
  rewrite unless Codex core tests show it is part of this policy surface)
- `core/capabilities/orchestration/build-loop/SKILL.md`
- `core/capabilities/orchestration/sage-navigator/SKILL.md`
- `core/capabilities/review/auto-review/SKILL.md`
- `core/capabilities/review/auto-qa/SKILL.md`
- `runtime/platforms/codex/setup/lib/agents-md.sh`
- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
- `runtime/platforms/codex/setup/tests/alex-native-core-text.bats`
- `runtime/platforms/codex/setup/tests/subagent-review-policy.bats`
- `runtime/platforms/codex/hooks/post-tool-check.sh`
- `runtime/platforms/codex/hooks/lib/*`
- `runtime/platforms/codex/hooks/tests/post-tool-check.bats`
- `runtime/platforms/codex/harness/README.md`
- `runtime/platforms/codex/harness/lib/aggregate-signals.sh`
- `runtime/platforms/codex/harness/tests/aggregate-signals.bats`
- `runtime/platforms/codex/harness/v11-scenarios.json`

Explicitly out of Milestone 1:

- `runtime/platforms/claude-code/**`
- `runtime/platforms/antigravity/**`
- `runtime/platforms/generic/**`
- `tools/sage-claude-plugin/**`
- public README/CHANGELOG/history docs, chyba ze deterministic Codex tests
  wymagaja minimalnej aktualizacji.

## Stop conditions

- Archive rotation needs a larger cross-platform writer abstraction.
- Signal 8 cannot be narrowed without weakening release-blocker semantics.
- Signal 8 narrowing would require a brittle natural-language classifier rather
  than explicit metadata/test matrix.
- Codex PostToolUse payload behavior differs from deterministic fixture in a way
  that makes rotation unsafe.
- Any change requires editing files outside the scope list.
- Tests show `post-tool-check.sh` is not the right place for rotation.
