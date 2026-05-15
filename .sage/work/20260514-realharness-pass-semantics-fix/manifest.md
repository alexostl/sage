---
cycle_id: "20260514-realharness-pass-semantics-fix"
title: "Fix: RealHarness green musi oznaczac clean-enough"
workflow: fix
phase: intake
status: intake
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
needs-triage: true
priority: P1
source: "sage:analyze log review"
suggested_workflow: fix
related:
  - "runtime/platforms/codex/harness/lib/aggregate-signals.sh"
  - "runtime/platforms/codex/harness/run-harness.sh"
  - "runtime/platforms/codex/harness/v11-scenarios.json"
  - "runtime/platforms/codex/harness/tests/*"
  - ".sage/work/20260509-cycle-workflow-entry-enforcement-fix/harness-run-20260513200647/report.json"
  - ".sage/work/20260514-real-harness-targeted-scenarios-fix/manifest.md"
scope:
  - ".sage/work/20260514-realharness-pass-semantics-fix/*"
  - ".sage/decisions.md"
---

# Fix: RealHarness green musi oznaczac clean-enough

## State

**Current phase:** intake. Implementacja nie zostala rozpoczeta.

**Next step:** Uruchomic `/sage:fix`, sprawdzic root cause i zdecydowac, ktore
sygnaly agregatora maja blokowac release, a ktore maja byc jawnie opisanym
debt/TODO.

## Finding

Analiza logow pokazala, ze ostatni passing RealHarness moze miec lokalnie
zielony `v11_release_blocker_harness.complete=true`, a jednoczesnie zostawiac
istotne sygnaly safety:

- `3_bypass_mutation.count = 4`;
- `7_l1_bypass.count = 2/12`;
- `6a_predicate_loc.loc = 291` przy ceiling `160`;
- `5_bash_mutation_leaks.status = TODO`;
- `6b_predicate_p95_latency_ms.status = TODO`.

Dodatkowo aktualny `runtime/platforms/codex/harness/v11-scenarios.json` ma 12
release blockerow, a przywolany zielony report cwiczyl 10. Stary green report
nie powinien byc traktowany jako aktualne evidence dla nowszego scenario
registry.

## Desired Behavior

- `complete=true` nie moze ignorowac globalnych sygnalow safety, ktore sa
  krytyczne dla release confidence.
- Report musi zawierac wersje/hash albo liczbe release blockerow z aktualnego
  `v11-scenarios.json`, zeby dalo sie wykryc stale/freshness drift.
- Targeted run nie moze udawac full release-blocker harness.
- TODO sygnaly takie jak bash mutation leaks i p95 latency maja byc jawnie
  release debt albo miec minimalna instrumentacje.
- Incydenty z `.sage-memory/*.db*` moga wymagac allowlisty, ale unclaimed
  workflow/instruction artifacts powinny failowac albo co najmniej hard-warn.

## Candidate Scope

- Dopracowac pass semantics w `aggregate-signals.sh`.
- Dodac scenario registry freshness/version gate.
- Dodac global incident policy dla release-blocker runs.
- Powiazac z `20260514-real-harness-targeted-scenarios-fix`, ale nie mieszac
  ergonomii selektywnego runu z semantyka full-pass.

## Evidence

- `.sage/work/20260509-cycle-workflow-entry-enforcement-fix/harness-run-20260513200647/report.json`
- `.sage/work/20260509-cycle-workflow-entry-enforcement-fix/harness-run-20260513200647/transcripts/*.state.json`
- `runtime/platforms/codex/harness/v11-scenarios.json`
