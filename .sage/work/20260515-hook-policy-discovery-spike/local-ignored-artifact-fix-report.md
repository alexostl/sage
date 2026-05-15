---
cycle_id: 20260515-hook-policy-discovery-spike
workflow: fix
phase: verify
status: in-progress
created: 2026-05-15
owner: codex
source: "First Minimization Path fix"
---

# Local-Ignored Artifact Fix Report

## Scope

Wdrożono pierwszy minimalny fix z `Minimization Path Architecture Plan`:
legalny `.sage-local/**` artifact ignorowany przez Git może przejść bez aktywnego
cyklu i bez tworzenia `.sage/work` manifestu.

Nie zmieniono polityk dla:

- cross-repo capture;
- completed-cycle direct reopen;
- audit-only;
- source/runtime/test/instruction mutation.

## Implementation

`pre-tool-validate.sh` dostał helper `is_local_ignored_artifact_patch`, który
przepuszcza tylko wtedy, gdy:

- wszystkie claimowane ścieżki są pod `.sage-local/**`;
- operacja to `Add` albo `Update`;
- Git faktycznie ignoruje każdą ścieżkę;
- nazwa ścieżki nie wygląda jak sekret;
- patch nie miesza source/runtime/test/instruction/managed surfaces.

Helper działa przed `resolve_cycle_for_patch`, żeby ignored local-only artifact
nie dziedziczył unrelated active cycle. To było potrzebne po regression guardzie:
`03` zostawiał aktywny cykl, a `17` wpadał przez to z powrotem w manifest bloat.

## Verification

Deterministic:

```text
bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh
bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
1..98
ok 1-98
```

RealHarness focused run:

```text
HARNESS_SCENARIOS=17-local-gitignored-config-artifact
HARNESS_HOOK_MODE=on
report: /tmp/sage-hook-local-ignored-fix-20260515074638/report.json
v11_release_blocker_harness.total=1
v11_release_blocker_harness.present=1
v11_release_blocker_harness.missing=[]
phase_jump=0
bypass_mutation=0
```

Regression guard:

```text
HARNESS_SCENARIOS=03-blocked-mutation-next-legal-move,17-local-gitignored-config-artifact
HARNESS_HOOK_MODE=on
report: /tmp/sage-hook-local-ignored-guard2-20260515075306/report.json
v11_release_blocker_harness.total=2
v11_release_blocker_harness.present=2
v11_release_blocker_harness.missing=[]
phase_jump=0
bypass_mutation=0
```

## Residual Note

`17` still emits `claim_no_op` for `.sage-local/hook-discovery.json` because the
file is ignored and does not appear in normal git porcelain. That is acceptable
for this first fix because the target was manifest-bloat removal and safety
preservation, not audit-noise elimination. If this warning becomes noisy in real
use, it should be a separate small audit-calibration follow-up.

## Verdict

First Minimization Path fix passes. It removes `.sage/work` bloat for the
local-only ignored artifact while preserving the `03` source mutation boundary.
