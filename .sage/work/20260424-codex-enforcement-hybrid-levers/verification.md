---
cycle_id: "20260424-codex-enforcement-hybrid-levers"
verified_at: "2026-04-28"
scope: standard
closed: true
---

# Verification: Codex Enforcement Hybrid Levers (L1+L2+L4+L5)

## Pre-fix reproducer

The two prior remediation cycles
(`20260423-codex-enforcement-gap-fix`,
`20260424-codex-enforcement-gate-revision`) closed the Critical PREAMBLE
and AGENTS.md gaps, but the residual compliance report
`CODEX_FRAMEWORK_COMPLIANCE_REPORT_019dbe38.md` still scored **5/10** with
seven findings:

- **#1 (Critical)** Implementation before root-cause gate.
- **#2 (Critical)** Wrong diagnosis caught by sub-agent only after user
  correction.
- **#3 (Major)** Backfilled artifacts (plan.md written post-hoc).
- **#4 (Major)** Close-out (commit/push) not executed without user
  prompt.
- **#5 (Major)** Phase strings paraphrased instead of exact.
- **#6 (Major)** Same jump-to-implementation pattern in `019dbf41`.
- **#7 (Minor)** No failing-test-first; verification.md template lacked
  a slot.

The audit
(`.sage/docs/analysis-codex-enforcement-surface-audit.md`) traced the
residue to five bypass classes that text-only enforcement structurally
cannot close, and recommended Option [1]: hybrid bundle L1+L2+L4+L5.
Estimated effort 1.5 days, ceiling 78–85% observable Sage compliance on
Codex.

## Implementation summary

Nine tasks landed in dependency order. Each task carried a test (or a
diff-able doc edit) and was approved against its own DONE-WHEN before
the next started.

- **T1 fixtures** —
  `runtime/platforms/codex/hooks/tests/fixtures/build_fixtures.sh` plus
  `tests/fixtures/README.md`. Builds nine fixture trees (5 sage states,
  multi-active for tie-breaker, lightweight, verifications/, git_repo)
  under `tests/tmp/` (gitignored). Idempotent.
- **T2 validator** —
  `runtime/platforms/codex/hooks/lib/verification_check.py` exposing
  `REQUIRED_SECTIONS`, `REQUIRED_FRONTMATTER`, and
  `validate(path) -> (ok, reasons)`. Single source of truth for shape
  rules consumed by L1/L4/L5. 14 tests.
- **T3+T8 template + path pin** —
  `.agents/skills/sage:build/templates/verification-template.md` with
  the canonical four-section shape and TODO scaffold. Skill references
  added in `.agents/skills/sage:build/SKILL.md` Step 6 and
  `.agents/skills/sage:fix/SKILL.md` Step 5; both pin
  `.sage/work/<slug>/verification.md` as the canonical path.
- **T4 L1 sticky context** — new module
  `runtime/platforms/codex/hooks/lib/active_state.py` with
  `compute(sage_root)` returning a deterministic 4–8 line state block
  (active slug + tie-breaker, phase, missing artifacts, next gate,
  ready-to-close indicator). `runtime/platforms/codex/hooks/pre-prompt.sh`
  refactored: every emission now flows through `emit_and_exit()` which
  appends sticky context to `additionalContext` on every meaningful
  turn (block, hint, passthrough). 12 unit tests + 10 sticky bash
  tests.
- **T5 L4 bin/sage-close** — `bin/sage-close <slug>` script. Seven
  idempotent phases (preflight → verify → mark closed → record →
  commit → integrate → push). Mark + record reordered before commit so
  the commit captures the `closed: true` flip. Idempotent via git-log
  grep + frontmatter predicates. Branch model hardcoded (inner =
  selfhost, integration = codex-port). Gitignore-tolerant on
  `.sage/` paths. 5 tests including before/after assertions for
  idempotence.
- **T6 L5 .githooks/pre-commit** — new `.githooks/pre-commit` shell
  hook with three-stage filter (slug match → scope gate →
  implementation-file detection) before invoking the validator. Only
  blocks Standard+ implementation commits; spec/plan-only and
  lightweight-scope commits pass. 8 tests covering negative,
  positive, mixed-case, lightweight, docs-allowlist, and
  no-initiative paths.
- **T7 install ergonomics** — `bin/sage-install-hooks` that wires
  `core.hooksPath = .githooks`. Idempotent. README "Repo hooks"
  paragraph added pointing at the script and explaining the gate.
  4 tests. `bin/sage` first-run gap noted in decisions for follow-up.

In-cycle gotcha captured to sage-memory: bash 3.2 mis-parses raw
apostrophes inside `<<'PY'` heredoc bodies inside `$(...)`
substitution. Same class as the prior `{N,M}` brace-expansion gotcha;
the rule "extract Python to importable modules, keep heredocs tiny"
pays for itself.

## Test command + pasted output

```
$ cd runtime/platforms/codex/hooks
$ python3 -m unittest discover -s tests -p 'test_*.py' 2>&1 | tail -5
..........................
----------------------------------------------------------------------
Ran 26 tests in 0.008s

OK

$ bash tests/test_pre_prompt_sticky.sh 2>&1 | tail -5
PASS [ready-to-close]
PASS [no-active-sticky]

Results: 10 passed, 0 failed.

$ bash tests/test_sage_close.sh 2>&1 | tail -5
PASS [validator blocks bad shape]
PASS [unknown slug exits clean]

Results: 5 passed, 0 failed.

$ bash tests/test_pre_commit_hook.sh 2>&1 | tail -5
PASS [docs allowlist passes]
PASS [no initiative touched ungated]

Results: 8 passed, 0 failed.

$ bash tests/test_install_hooks.sh 2>&1 | tail -5
PASS [missing .githooks aborts]
PASS [outside git repo aborts]

Results: 4 passed, 0 failed.

Totals: 53 tests, 0 failed.
```

## Close-out checklist

- [x] **DONE-WHEN #1 — L1 firing ratio.** Sticky context emitted for
  all 5 fixture states + multi-active. (`test_active_state.py`
  + `test_pre_prompt_sticky.sh`).
- [x] **DONE-WHEN #2 — L1 size budget.** Common cases ≤ 600 B, hard
  cap ≤ 1.2 KB enforced and tested
  (`test_active_state.SizeBudget`).
- [x] **DONE-WHEN #3 — L2 template installed.** Template at
  `.agents/skills/sage:build/templates/verification-template.md`,
  filled template passes validator, both skill refs landed.
- [x] **DONE-WHEN #4 — L4 dry-run.** `SAGE_CLOSE_DRY=1` prints
  planned phases without touching git; tested
  (`case_dry_run`).
- [x] **DONE-WHEN #5 — L4 idempotence.** Re-run on already-closed
  fixture skips every phase, no new commits, no decisions diff;
  before/after `git rev-parse` and `wc -l` asserted explicitly per
  plan-reviewer note (`case_idempotent_rerun`).
- [x] **DONE-WHEN #6 — L4 dual-branch behavior.** Real run produces
  one inner-branch commit + integration-branch advance + merge
  commit referencing slug + decisions entry
  (`case_real_run`).
- [x] **DONE-WHEN #7 — L5 negative case.** Standard-scope commit with
  missing/incomplete verification.md is blocked with one-line message
  (`case_negative_missing_verification`,
  `case_mixed_blocked_when_invalid`).
- [x] **DONE-WHEN #8 — L5 positive case.** Same commit succeeds once
  verification.md matches the template
  (`case_positive_valid_verification`,
  `case_mixed_allowed_when_valid`).
- [x] **DONE-WHEN #9 — L5 false-positive ceiling.** Spec-only and
  lightweight-scope commits pass without validator gating
  (`case_spec_only_commit`, `case_lightweight_ungated`,
  `case_no_initiative_touched`, `case_docs_allowlist`).
- [ ] **DONE-WHEN #10 — End-to-end self-close.** Pending — this
  verification.md is the precondition; `bin/sage-close
  20260424-codex-enforcement-hybrid-levers` runs after user [A]/[R]
  on dry-run.
- [x] **DONE-WHEN #11 — Pasted test output (shape).** Section above
  contains a fenced block whose body has more than the command line.
- [x] **DONE-WHEN #12 — No regressions.** Existing `pre-prompt.sh`
  behaviors (skill whitelist, status-aware build gate, Tier 1
  passthrough, fix redirect) preserved; the modified hook still
  passes its existing test cases via `test_pre_prompt_sticky.sh`
  which exercises every legacy emission path with sticky added.

## Files changed

The list below is what `bin/sage-close` will stage on commit
(verbatim — the script reads the `- ` lines below). On this repo,
`.sage/` is gitignored on `selfhost` per the branch-worktree
operating model, so .sage/work/ artifacts stay local; only the code
files below ship.

- runtime/platforms/codex/hooks/lib/__init__.py
- runtime/platforms/codex/hooks/lib/verification_check.py
- runtime/platforms/codex/hooks/lib/active_state.py
- runtime/platforms/codex/hooks/pre-prompt.sh
- runtime/platforms/codex/hooks/tests/__init__.py
- runtime/platforms/codex/hooks/tests/.gitignore
- runtime/platforms/codex/hooks/tests/fixtures/build_fixtures.sh
- runtime/platforms/codex/hooks/tests/fixtures/README.md
- runtime/platforms/codex/hooks/tests/test_verification_check.py
- runtime/platforms/codex/hooks/tests/test_active_state.py
- runtime/platforms/codex/hooks/tests/test_pre_prompt_sticky.sh
- runtime/platforms/codex/hooks/tests/test_sage_close.sh
- runtime/platforms/codex/hooks/tests/test_pre_commit_hook.sh
- runtime/platforms/codex/hooks/tests/test_install_hooks.sh
- bin/sage-close
- bin/sage-install-hooks
- .githooks/pre-commit
- .agents/skills/sage:build/templates/verification-template.md
- .agents/skills/sage:build/SKILL.md
- .agents/skills/sage:fix/SKILL.md
- README.md
