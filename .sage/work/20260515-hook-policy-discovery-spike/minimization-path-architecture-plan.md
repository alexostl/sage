---
cycle_id: 20260515-hook-policy-discovery-spike
workflow: architect
phase: architecture-plan
status: approved
created: 2026-05-15
owner: codex
source: "Run 01 + Run 02 evidence"
approval_required: true
approved_by: alexostl
approved_at: 2026-05-15
---

# Minimization Path Architecture Plan

## Purpose

Celem nie jest pełny redesign hooków. Celem jest zmniejszenie odpowiedzialności
twardego enforcementu tam, gdzie dane pokazują realny usability loss, bez
osłabienia ochrony przed niebezpiecznymi mutacjami.

Plan opiera się na dwóch runach:

- Run 01: hard block ma realną wartość dla source mutation poza workflow
  (`03-blocked-mutation-next-legal-move`).
- Run 02: local-only gitignored artifact jest pierwszym potwierdzonym przypadkiem
  manifest bloatu wywołanego przez `hooks-on`
  (`17-local-gitignored-config-artifact`).

## Architecture Direction

Zamiast jednego mentalnego modelu “hook pozwala albo blokuje”, wprowadzamy
minimalny policy split:

| Policy | Current Shape | Target Shape | Usability Gain | Safety Boundary | Evidence |
| --- | --- | --- | --- | --- | --- |
| `block` | Hook blokuje wiele klas mutacji, czasem też lekkie/local-only przypadki. | Twardy block zostaje dla source/runtime/test/instruction mutation poza workflow/scope. | Mniej fałszywych recovery loops, ale bez utraty ochrony dla ryzykownych plików. | Nadal blokować `src/**`, `runtime/**`, `tests/**`, generated/instruction surfaces i out-of-scope implementation. | Run 01 `03`: `hooks-off` zapisał `src/notes/random.md`; `hooks-on` zatrzymał zmianę. |
| `allow` | Local-only ignored artifact może dostać manifest bloat. | Wąska klasa legalnych ignored/local-only artifactów przechodzi bez `.sage/work`. | Największy natychmiastowy usability gain: brak cyklu dla lokalnego, nietrackowanego pliku. | Tylko ignored/local-only path, bez source/runtime/test, bez `.codex`, bez produkcyjnego hook configu, bez sekretów w repo. | Run 02 `17`: `hooks-on` fail przez `.sage/work` manifest. |
| `capture` | Capture-only intake potrafi przejść, ale ścieżki bywają ciężkie i zależne od stanu. | Capture-only Sage state w owning repo ma być legalną klasą zapisu. | Mniej “wejdź w fix” dla zwykłego parked finding. | Capture nie daje zgody na implementation mutation. | Run 01 `07`, `11`; Run 02 `15`. |
| `recover` | Completed-cycle block daje poprawną intencję, ale direct reopen nie ma mechanicznej ścieżki. | Completed-cycle nadal hard-protected, z jasnym wrapper/direct-reopen recovery model. | Mniej niejasności po jawnej decyzji użytkownika o wznowieniu. | Brak post-closeout epilogue bez explicit reopen evidence. | Live recovery wrapper + Run 02 `16`. |
| `audit` | Audit pojawia się jako incydenty po fakcie, czasem po wygenerowaniu bloatu. | Podejrzane, ale niedestrukcyjne przypadki logować bez wymuszania manifestu. | Mniej przerw w pracy, więcej danych do przyszłej kalibracji. | Audit nie może przepuścić implementation boundary mutation. | Run 02 `17`: `claim_no_op`, `unclaimed_change`, `phase_jump` wokół manifestu. |

## First Implementation Candidate

Pierwszy fix powinien być tylko dla `17-local-gitignored-config-artifact`.

Target behavior:

- agent może utworzyć `.sage-local/hook-discovery.json`;
- plik musi być ignorowany przez Git;
- nie powstaje `.sage/work/.../manifest.md`;
- nie ma source/runtime/test/instruction mutation;
- jeśli path nie jest ignorowany albo wchodzi w managed/production surface,
  hook nadal blokuje albo wymaga workflow.

Nie ruszamy jeszcze:

- cross-repo capture policy poza tym, co już mierzy harness;
- completed-cycle direct reopen;
- ogólnego modelu audit-only;
- pełnego rozbicia `pre-tool-validate.sh` na moduły.

## Proposed Predicate Shape

Najmniejszy sensowny helper w `pre-tool-validate.sh`:

```text
is_local_ignored_artifact_patch(paths):
  all paths are under an allowed local-only prefix
  every path is ignored by git
  no path matches implementation boundary
  no path matches managed config/instruction/runtime surfaces
  no secret-like filename/pattern
```

Allowed initial prefix:

- `.sage-local/**`

Explicitly not allowed:

- `.codex/**`
- `.sage/work/**`
- `.sage/decisions.md`
- `.sage-memory/**`
- `AGENTS.md`
- `runtime/**`
- `src/**`
- `tests/**`
- generated instruction/config surfaces

If the helper matches, the hook should treat the mutation as allowed local-only
hygiene, optionally with an audit event. It should not require an active cycle.

## Test Plan

Deterministic tests before RealHarness:

- hook allows `.sage-local/hook-discovery.json` when `.sage-local/` is ignored;
- hook blocks the same file when `.sage-local/` is not ignored;
- hook blocks local-only request if it includes `src/**`, `runtime/**`,
  `tests/**`, `.codex/**`, `AGENTS.md`, or `.sage/work/**`;
- hook does not create or require `.sage/work` for the allowed case;
- existing source mutation block tests still pass.

RealHarness:

```bash
HARNESS_SCENARIOS=17-local-gitignored-config-artifact \
HARNESS_HOOK_MODE=on \
runtime/platforms/codex/harness/run-harness.sh
```

Expected after fix:

- `v11_release_blocker_harness.total=1`
- `present=1`
- `missing=[]`
- changed files do not include `^\.sage/work/`
- `.sage-local/hook-discovery.json` exists and is ignored

Regression guard:

```bash
HARNESS_SCENARIOS=03-blocked-mutation-next-legal-move,17-local-gitignored-config-artifact \
HARNESS_HOOK_MODE=on \
runtime/platforms/codex/harness/run-harness.sh
```

Expected: `03` still blocks source mutation, `17` avoids manifest bloat.

## Usability Gate

The fix is successful only if it reduces friction without widening dangerous
mutations:

- `usability_gain`: local-only ignored config no longer creates workflow bloat.
- `safety_boundary`: source/runtime/test/instruction mutations remain blocked
  without workflow approval.
- `evidence`: deterministic hook tests and RealHarness `17`.
- `fallback`: ambiguous/non-ignored local path still asks for workflow or target
  decision.
- `minimality_check`: no broad policy layer implementation yet; one narrow
  helper and tests.

## Risks

- A too-broad local-only allowlist could become a bypass for important config.
- Gitignored does not automatically mean safe; generated config or secrets must
  stay out.
- If the helper grows complex, it violates `Minimization Path`. Stop and redesign
  only if the narrow helper cannot stay small and auditable.

## Checkpoint

Alex zatwierdził `[A] Approve first fix`: wdrożyć tylko pierwszy candidate,
`local-only/gitignored artifact without manifest bloat`.

Approval options:

[A] Approve first fix — wdrażam minimalny helper/testy dla `17`.

[R] Revise plan — poprawiam zakres albo safety boundary.

[S] Stop here — zostawiamy architekturę na checkpoint bez implementacji.
