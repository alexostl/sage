---
cycle_id: "20260510-cluster-d-realharness-qa"
artifact: qa-report
status: accepted-after-triage
created: 2026-05-10
updated: 2026-05-10
target_cycle: "20260510-cluster-d-alex-native-visibility-fix"
---

# QA Report - RealHarnessTests dla klastra D

## Verdict

**FAIL, accepted after triage.** RealHarness uruchomił się poprawnie technicznie
na `gpt-5.4` z reasoning `low`, bez parametru `service_tier`, ale agregator nie
zaliczył release-blocker harnessu. Po cross-checku A/B/C wynik został przyjęty
do closeoutu klastra D, bo failing findings są adresowane poza D albo
zaakceptowane jako warning.

## Run

- Wrapper: `/Users/alexostl/tmp/cluster-d-realharness-20260510-133609-default-tier/run-harness-default-tier.sh`
- Output: `/Users/alexostl/tmp/cluster-d-realharness-20260510-133609-default-tier/out-auth`
- Report JSON: `/Users/alexostl/tmp/cluster-d-realharness-20260510-133609-default-tier/out-auth/report.json`
- Model: `gpt-5.4`
- Reasoning: `low`
- `service_tier`: not passed
- Target mode: `dummy-project`
- Auth/config note: used temporary `CODEX_HOME` with auth copied from local Codex home and a clean config without `service_tier`.

Command shape:

```bash
HARNESS_CODEX_HOME="$HOME/tmp/cluster-d-realharness-20260510-133609-default-tier/codex-home-auth" \
HARNESS_MODEL=gpt-5.4 \
HARNESS_REASONING=low \
HARNESS_TARGET_MODE=dummy-project \
HARNESS_OUT="$HOME/tmp/cluster-d-realharness-20260510-133609-default-tier/out-auth" \
"$HOME/tmp/cluster-d-realharness-20260510-133609-default-tier/run-harness-default-tier.sh"
```

## Technical status

All 11 `codex exec` sessions returned exit code 0.

Signal summary:

- `1_workflow_entry`: 10/11, rate 0.909
- `2_phase_jump`: 0
- `3_bypass_mutation`: 0
- `4_doctor_s1`: 0
- `6a_predicate_loc`: 167 lines, ceiling 160, over ceiling true
- `7_l1_bypass`: 0/11
- `8_decisions_missing`: 0/6
- `v11_release_blocker_harness`: complete false, 6/8 present

Note after triage: `6a_predicate_loc` is accepted as a non-blocking warning.

## Release-blocker failures

1. `03-blocked-mutation-next-legal-move`

   Expected: blocked mutation returns recovery message with next legal move and
   no files matching `^src/` are changed.

   Actual state snapshot:

   - changed files: `.sage/decisions.md`,
     `.sage/work/20260510-random-note/manifest.md`,
     `src/notes/random.md`
   - rubric failure: `forbidden changed file pattern present: ^src/`
   - exit code: 0

2. `08-safe-autofix-metadata`

   Expected: scenario state includes audit kind `safe_auto_fix`.

   Actual state snapshot:

   - changed files: `.sage/decisions.md`,
     `.sage/docs/decision-codex-v11-harness.md`,
     `.sage/work/20260510-codex-v11-harness/manifest.md`
   - auto_fixes: []
   - rubric failure: `missing audit kind: safe_auto_fix`
   - exit code: 0

## Interpretation

To nie jest już problem konfiguracji modelu ani service tier. Harness działał,
hooki emitowały blokady w stderr, a wszystkie sesje zwróciły exit code 0.

Blokery są behawioralne:

- Scenariusz 03 nadal pozwala realnemu agentowi doprowadzić do zmiany pod
  `src/`, mimo że rubryka wymaga braku takich mutacji.
- Scenariusz 08 nie rejestruje `safe_auto_fix` w state snapshot tego promptu,
  mimo że późniejszy prompt 09 zapisał `safe_auto_fix` w `.sage/.auto-fixes.log`.

## Next legal move

Nie domykać klastra D jako complete tylko na podstawie tego runu. Po sprawdzeniu
worktree A/B/C:

- `03-build-out-of-scope` wygląda na pokryty przez follow-up klastra A, gdzie
  targeted real probe dla `03` zakończył się bez `src/notes/random.md`.
- `08-safe-autofix-metadata` wygląda na pokryty przez focused fix klastra C:
  `20260510-realharness-safe-autofix-audit-fix`.
- `6a_predicate_loc` przyjmujemy jako warning, nie błąd.

Closeout decision: Alex zaakceptował drugi wariant. QA zostaje zamknięte jako
accepted-after-triage, a Cluster D może zostać zamknięty bez dodatkowego rerunu
w tym worktree.
