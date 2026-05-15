---
cycle_id: 20260515-hook-policy-discovery-spike
workflow: architect
phase: closeout
status: final
created: 2026-05-15
owner: codex
source: "Milestone 0.2 + first Minimization Path fix"
---

# Closeout: Milestone 0.2 and First Minimization Path Fix

## Scope Closed

Ten closeout domyka pierwszy wdrożony element `Minimization Path`:
legalny, gitignored local-only artifact pod `.sage-local/**` ma przechodzić bez
tworzenia `.sage/work` manifest bloatu.

W tej turze nie wdrożono szerokiego rewrite hooków, cross-repo policy ani
completed-cycle direct reopen. Te tematy zostały rozdzielone w target
architecture brief jako osobne kandydaty milestone.

## Implemented Runtime Behavior

- `pre-tool-validate.sh` rozpoznaje `local_ignored_artifact` przed cycle
  resolution.
- Dozwolone są tylko `Add`/`Update` dla `.sage-local/**`, jeśli ścieżka jest
  faktycznie ignorowana przez Git.
- Secret-like filenames, path traversal, `.git`, managed surfaces,
  source/runtime/test/config/instruction paths oraz mixed patches pozostają
  blokowane.
- Mutacja nie dziedziczy unrelated active cycle, więc nie wymusza sztucznego
  manifestu.

## Harness Coverage Added

- Dodano scenariusze `15-cross-repo-fix-intake-capture`,
  `16-completed-cycle-explicit-reopen` i
  `17-local-gitignored-config-artifact`.
- Harness umie teraz przygotować secondary target repo oraz agregować rubryki
  dla `secondary_files` i `secondary_changed_files`.
- Run 02 potwierdził, że `17` był pierwszym najmniejszym false positive:
  `hooks-off` przechodziło, a `hooks-on` generowało `.sage/work` bloat.

## Verification Evidence

Świeża deterministyczna weryfikacja przed closeoutem:

```text
bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh
bash -n runtime/platforms/codex/harness/run-harness.sh
bash -n runtime/platforms/codex/harness/lib/aggregate-signals.sh
jq empty runtime/platforms/codex/harness/v11-scenarios.json
git diff --check
```

Wszystkie powyższe komendy zakończyły się kodem `0`.

```text
bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
1..98
ok 1-98
```

```text
bats runtime/platforms/codex/harness/tests/run-harness.bats runtime/platforms/codex/harness/tests/aggregate-signals.bats
1..26
ok 1-26
```

RealHarness evidence z tej tury:

- RealHarness focused `17`: `total=1`, `present=1`, `missing=[]`;
- RealHarness guard `03+17`: `total=2`, `present=2`, `missing=[]`.

## Residual Work

Najmniejszy sensowny follow-up to `0.3 Audit Noise Calibration`: usunąć albo
skalibrować mylący `claim_no_op` dla ignored local-only artifacts, bez ruszania
cross-repo i completed-cycle policy.

## Handoff

Następny cykl powinien zaczynać się od `0.3 Audit Noise Calibration` albo od
osobnego planu dla `0.4 Capture Ownership Calibration`. Nie należy rozszerzać
obecnego pierwszego fixu o te tematy bez nowego planu i approval checkpoint.
