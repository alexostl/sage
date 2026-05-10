---
cycle_id: "20260424-codex-enforcement-hybrid-levers"
title: "Codex Enforcement Hybrid Levers (L1+L2+L4+L5)"
type: spec
workflow: build
phase: spec
status: completed
scope: standard
created: 2026-04-24
handoff: |
  Key decisions: four-lever bundle (L1 sticky context, L2 verification.md
  template + validator, L4 bin/sage-close, L5 git pre-commit) selected as
  Option [1] from the surface audit. Shared validator `verification_check.py`
  is the single source of truth for L2/L4/L5 shape rules — the planner must
  schedule it as the first implementation task so L1's sticky-block "ready
  to close" check, L4's gate, and L5's hook all consume the same module
  from day one.
  Open questions: exact path layout — `runtime/platforms/codex/hooks/lib/`
  vs project `bin/` vs `.githooks/`. Recommend keeping platform-specific
  helpers under `runtime/platforms/codex/hooks/lib/`, generic close-out
  under `bin/`, hook scripts under `.githooks/`. Confirm in plan.
  Risks to watch in implementation: (R1) sticky-context dilution — measure
  size on real .sage state, not just fixtures; (R3) sage-close partial
  failure — write idempotence tests first, before mainline path; (R4)
  pre-prompt.sh regression — run existing test suite after every L1 change
  and before checkpoint, not only at end.
  Next agent should: write plan.md with tasks ordered as
  validator → L2 template → L1 sticky context → L4 sage-close → L5
  pre-commit → end-to-end test on this very cycle (DONE-WHEN #10).
  Avoid `{N,M}` Python regex quantifiers inside `python3 -c "$(cat <<'PY'`
  heredocs (Bash brace expansion); use `*?` or external helper file.
related:
  - .sage/docs/analysis-codex-enforcement-surface-audit.md
  - .sage/docs/analysis-codex-enforcement-gap.md
  - CODEX_FRAMEWORK_COMPLIANCE_REPORT_019dbe38.md
  - .sage/work/20260423-branch-worktree-operating-model/manifest.md
  - runtime/platforms/codex/hooks/pre-prompt.sh
  - runtime/platforms/codex/HOOKS.md
  - runtime/platforms/codex/README.md
  - AGENTS.md
non_goals:
  - L3 (in-workspace phase tracker) — parked, see sage-memory f9a6eb1f
  - L6 (mandatory reviewer subagent with binding verdict) — rejected
  - L7 (phase strings validator) — out of scope
  - L8 (PreToolUse Bash extension for risky mutations) — out of scope
  - Per-turn re-injection of full AGENTS.md — Codex platform limitation
  - Antigravity / non-Codex platforms
---

# Codex Enforcement Hybrid Levers (L1+L2+L4+L5)

## WHAT

Four cooperating enforcement levers that raise observable Sage compliance on
Codex from the current ~45–55 % baseline to a structural ceiling of 78–85 %,
without requiring a second runtime, a binding reviewer subagent, or an
out-of-process supervisor. All four levers are platform-agnostic in design and
also strengthen Claude Code when it consumes the same `.sage/` and
`bin/sage-close` surface.

The four levers, identified in `analysis-codex-enforcement-surface-audit.md`
and selected as Option [1] of that audit's recommendation:

1. **L1 — Sticky `additionalContext` injection.** Modify
   `runtime/platforms/codex/hooks/pre-prompt.sh` so that **every** turn (not
   only blocked turns) emits a small, deterministic
   `hookSpecificOutput.additionalContext` that re-states: which initiative is
   active, which artifacts already exist on disk, and which gate the agent is
   currently inside.

2. **L2 — `verification.md` template with required sections + validator.** Add
   a canonical `verification-template.md` under
   `.agents/skills/sage:build/templates/` (and reused by `sage:fix`). Required
   sections, in this exact order: `## Pre-fix reproducer`, `## Implementation
   summary`, `## Test command + pasted output`, `## Close-out checklist`. The
   `pre-prompt.sh` gate refuses to clear "ready to close" prompts when an
   active initiative has no `verification.md` matching the template.

3. **L4 — `bin/sage-close <slug>` atomic close-out script.** A bash entry
   point that performs, in order: (a) verify `verification.md` exists and
   passes shape check, (b) verify working tree clean except for the new
   commit, (c) commit on `selfhost` with a HEREDOC message, (d) merge
   into `codex-port` via the documented dual-branch operating model
   (`20260423-branch-worktree-operating-model/manifest.md`), (e) push both
   branches, (f) prepend a close entry to `.sage/decisions.md`. The script is
   idempotent on re-run (skip phases already completed) and refuses to
   continue on first failed precondition.

4. **L5 — Git `pre-commit` hook validating `verification.md`.** A
   `.githooks/pre-commit` script (installed via `core.hooksPath` so it travels
   with the repo) that, when staged files include any path under
   `.sage/work/<slug>/` with a Standard+ frontmatter (`scope: standard` or
   `scope: comprehensive`), requires:

   - `.sage/work/<slug>/verification.md` exists,
   - file contains all four required headings from L2,
   - the "## Test command + pasted output" section contains a fenced block
     with at least one line that is not the command line itself.

   On failure: hook exits non-zero with a one-line message + the path of the
   missing/incomplete file. No `--no-verify` escape inside `bin/sage-close`.

## WHY

Two prior remediation cycles (`20260423-codex-enforcement-gap-fix`,
`20260424-codex-enforcement-gate-revision`) closed the Critical gaps in
PREAMBLE injection and AGENTS.md strictness. The residual report
`CODEX_FRAMEWORK_COMPLIANCE_REPORT_019dbe38.md` still scored 5/10 with seven
findings. The audit traced the residue to five bypass classes that
text-only enforcement structurally cannot close:

- **Finding #1** (impl before root-cause) — *one-shot gate bypass*: gate
  fires once per turn, agent continues into edits in the same turn.
- **Finding #2** (wrong diagnosis caught by subagent) — *text-only mandate*:
  "On [A]: Run auto-review" is a prose line, not a forcing function.
- **Finding #3** (backfilled artifacts) — *missing phase/state tracker*: no
  gate checks "phase is implementation but plan.md is missing".
- **Finding #4** (close-out not autonomous) — *missing close-out gate*: no
  Stop hook on Codex; user had to remind agent to commit and push.
- **Finding #5** (paraphrased phase strings) — *text-only mandate*.
- **Finding #6** (cross-thread `019dbf41` jump-to-implementation) — *one-shot
  gate bypass + missing state tracker*.
- **Finding #7** (no failing-test-first) — *missing template slot*.

The four-lever bundle attacks four of the five bypass classes — *partially*
for the one-shot gate (L1 re-prompts on the **next** turn but does not
stop intra-turn bypass), mechanically for the others:

| Class | Levers that close it | Findings closed |
|---|---|---|
| One-shot gate bypass | **L1** (every-turn sticky context = re-prompt) | #1 soft, #6 soft |
| Text-only mandate | **L1 + L5** (sticky reminder + git enforcement) | #5 soft |
| Missing phase/state tracker | partially — *L3 would close fully* | #3 partial |
| Missing close-out gate | **L4 + L5** (scripted close + git hook) | #4 mech |
| Missing template slot | **L2** (verification.md required slots) | #7 mech |

The audit estimates the compliance lift at +25–35 percentage points,
producing a 78–85 % ceiling, in ~1.5 days of work. Going further (L3, L6)
costs 4–5 additional days for ~10 pp; the user explicitly opted out of that
spend in this cycle.

## HOW

### L1 — Sticky `additionalContext` (pre-prompt.sh)

- Today `pre-prompt.sh` only emits `additionalContext` when it `block`s a
  turn or rewrites a routing decision. Extend it so that on **every** turn
  (including pure-passthrough), the script computes a 6–12 line summary
  block and emits it as `hookSpecificOutput.additionalContext` with
  `decision: "continue"`.

- Summary block content (deterministic, not LLM-generated):
  - Active initiative slug if exactly one is `in-progress`, else "(none)".
  - Phase, taken from artifact frontmatter precedence:
    `verification` > `implementation` > `plan` > `spec` > `brief`.
  - Required-but-missing artifacts for current phase
    (e.g. "spec.md missing", "verification.md missing").
  - Pending close-out flag if `verification.md` exists but no
    matching close entry in `.sage/decisions.md` for this slug.
  - One-line reminder of the next gate (`Sage:` prefix, no code block).

- Computation lives in a small Python helper
  `runtime/platforms/codex/hooks/lib/active_state.py` so the bash script
  stays narrow and testable. **Hard constraint** carried from prior memory:
  Python regex called from `python3 -c "$(cat <<'PY' … PY)"` must avoid
  `{N,M}` quantifiers (Bash brace expansion); use `*?` or move the regex
  into the helper file rather than inlining it.

- Cost discipline: total injected text per turn ≤ 600 characters in the
  common case; ≤ 1.2 KB worst case. Below the noise floor of AGENTS.md
  (~12 KB) so dilution effect is acceptable.

### L2 — verification.md template + validator

- Add `.agents/skills/sage:build/templates/verification-template.md` and
  reference it from both `sage:build` Step 6 and `sage:fix` Step 4.
  Required headings, exact spelling, exact order:

  1. `## Pre-fix reproducer`
  2. `## Implementation summary`
  3. `## Test command + pasted output`
  4. `## Close-out checklist`

- Template ships with a frontmatter block including
  `cycle_id`, `verified_at`, `scope`, and `closed: false`.

- Validator: a small Python module
  `runtime/platforms/codex/hooks/lib/verification_check.py` exposing
  `validate(path) -> (ok: bool, reasons: list[str])`. Reused by L1 (to
  decide "ready to close" reminder), L4 (to gate the script), and L5
  (to gate the commit). Single source of truth for shape rules.

### L4 — bin/sage-close <slug>

- New executable `bin/sage-close` (bash). Single positional argument: the
  initiative slug (matching directory under `.sage/work/`).

- Phases (each idempotent, each refuses to advance on its own failure):

  1. **Preflight.** Resolve slug → directory; abort if not found.
  2. **Verify.** Call `verification_check.validate(verification.md)`;
     abort with reasons on failure.
  3. **Decide branches.** Read
     `.sage/work/20260423-branch-worktree-operating-model/manifest.md` for
     the branch model; default `inner=selfhost`,
     `integration=codex-port`, `mirror=main` (mirror is read-only here).
  4. **Commit (inner).** If working tree dirty in inner branch's worktree,
     stage `.sage/**` + any files listed under `## Files changed` of
     verification.md, then commit using a HEREDOC message containing the
     spec link, plan link, and verification.md link. Never `git add -A`.
  5. **Integrate.** In the `codex-port` worktree: fetch + merge inner
     branch with `--no-ff`; HEREDOC merge message references the cycle id.
  6. **Push.** Push inner and integration branches to origin in parallel.
     Default off when `SAGE_CLOSE_NO_PUSH=1` (for tests). Apply the
     `gh pr close --delete-branch` gotcha pattern from prior memory: never
     pass `--delete-branch` from this script; merges only.
  7. **Record.** Prepend a one-paragraph close entry to `.sage/decisions.md`
     and flip `closed: true` in verification.md frontmatter.

- Re-run on the same slug skips already-completed phases (detected via
  git log + frontmatter), so partial failure is recoverable without manual
  cleanup.

- Output style: `Sage:` prefix lines, no code blocks. Final line is
  `Sage: close-out complete for <slug>.` on success.

### L5 — Git pre-commit hook

- New `.githooks/pre-commit` (bash) installed via
  `git config core.hooksPath .githooks` documented in repo README + run by
  a `bin/sage-install-hooks` helper (called once per fresh clone).

- Triggering condition: `git diff --cached --name-only` includes any path
  matching `^.sage/work/[^/]+/` AND that initiative's `spec.md` (or
  `brief.md`) frontmatter declares `scope: standard` or `scope:
  comprehensive`.

- On trigger: invoke `verification_check.validate` against the initiative's
  `verification.md`. Hook exits 0 on pass; non-zero with single-line
  message + missing-section list on fail.

- Lightweight initiatives (`scope: lightweight`, or no scope frontmatter)
  are not gated by this hook. Spec/plan-only commits (no implementation
  files) are not gated.

- Hook does NOT call out to network, does NOT touch git index, and is
  bypass-only via explicit `git commit --no-verify`. `bin/sage-close`
  never passes that flag.

### Cross-cutting

- All four levers share `verification_check.py` so shape rules live in one
  file. Schema changes there ripple consistently.
- Tests (Step 7 of the build): a small `tests/` tree under
  `runtime/platforms/codex/hooks/` exercising:
  - `verification_check.validate` happy-path + each failure mode,
  - `pre-prompt.sh` sticky-context shape on a fixture `.sage/`,
  - `bin/sage-close` dry-run mode (`SAGE_CLOSE_DRY=1`) on a fixture repo,
  - `pre-commit` hook against a fixture repo (commit blocked + commit
    allowed cases).

## DONE-WHEN

Each item below is a behavioral acceptance criterion, verifiable from
outside the agent (file check, command exit, transcript regex). No item
relies on the agent's self-report.

1. **L1 firing ratio.** A scripted run of `pre-prompt.sh` against 5 fixture
   `.sage/` states (no-active, brief-only, spec-only, plan-only,
   verification-pending) emits a sticky `additionalContext` of correct
   shape on **every** invocation. Fixture-driven test passes.

2. **L1 size budget.** None of the 5 fixture invocations produce a sticky
   block exceeding 1.2 KB; common cases fit within 600 B.

3. **L2 template installed.** `verification-template.md` exists in
   `.agents/skills/sage:build/templates/` and is referenced from
   `sage:build` Step 6 and `sage:fix` Step 4. `verification_check.validate`
   returns `(True, [])` for the unmodified template after frontmatter
   completion.

4. **L4 dry-run.** `SAGE_CLOSE_DRY=1 bin/sage-close 20260424-codex-enforcement-hybrid-levers`
   prints the planned phases + branch operations without touching git
   state, exits 0.

5. **L4 idempotence.** Re-running `bin/sage-close` on a fully-closed
   fixture initiative reports "already closed" and exits 0 without
   creating duplicate commits or duplicate decisions entries.

6. **L4 dual-branch behavior.** A fixture run on a throwaway worktree
   produces one commit on `selfhost`, one merge commit on
   `codex-port`, and one prepended entry in `.sage/decisions.md`.

7. **L5 negative case.** Attempting to commit an implementation file under
   a `scope: standard` initiative whose `verification.md` is missing or
   incomplete is blocked by the hook with a clear single-line reason.

8. **L5 positive case.** The same commit succeeds once `verification.md`
   matches the template and contains pasted test output.

9. **L5 false-positive ceiling.** Committing only `.sage/work/<slug>/spec.md`
   (no implementation files) is **not** blocked, regardless of
   verification.md state.

10. **End-to-end.** This very cycle (`20260424-codex-enforcement-hybrid-levers`)
    is closed via `bin/sage-close`, with a verification.md that satisfies
    the validator, a commit that passes the pre-commit hook on its own
    rules, and a `.sage/decisions.md` close entry prepended.

11. **Pasted test output (shape).** The verification.md "## Test command +
    pasted output" section contains a fenced block whose body has at least
    one line beyond the command line. (Validator cannot tell prose from
    real stdout; "real stdout" is enforced socially via Rule 5, not
    mechanically.)

12. **No regressions.** Existing `pre-prompt.sh` behaviors retained:
    `$skill` whitelist, status-aware build gate, Tier 1 passthrough, fix
    redirect. Existing test suite for `pre-prompt.sh` still passes.

## Out of scope (explicit non-goals)

- L3 in-workspace phase tracker — parked, revival criteria stored in
  sage-memory `f9a6eb1f76114e27b0ad0d0917229931`.
- L6 mandatory reviewer subagent with binding verdict — rejected.
- L7 phase strings validator — observability lever, not in this cycle.
- L8 PreToolUse Bash extension for "risky mutations" (symlink swap,
  global path writes) — out of cycle.
- Per-turn re-injection of full AGENTS.md — Codex platform limitation.
- Cross-platform UX parity with Claude Code slash commands — non-goal of
  the Codex port.
- Network calls inside hooks (telemetry, remote validators) — non-goal.

## Risks & mitigations

- **R1.** Sticky context dilution. Adding 0.6–1.2 KB per turn could erode
  AGENTS.md salience. *Mitigation:* keep block under budget (DONE-WHEN
  #2); hold the block to deterministic, structural lines only (no prose).

- **R2.** False positives in pre-commit hook break developer flow.
  *Mitigation:* hook only triggers on Standard+ initiatives with
  implementation files staged; spec/plan-only commits are ungated
  (DONE-WHEN #9).

- **R3.** `bin/sage-close` partial failure leaves repo in inconsistent
  state. *Mitigation:* idempotent phase execution (DONE-WHEN #5); each
  phase verifies its own preconditions before mutating.

- **R4.** Test suite regression on `pre-prompt.sh` due to shape change.
  *Mitigation:* DONE-WHEN #12 explicit; shape change is additive
  (`additionalContext` already supported).

- **R5.** `verification_check.py` becoming a god-module. *Mitigation:*
  module exposes only `validate(path)` and constants; reused, not extended,
  by L4 and L5.

- **R6.** Residual close-out hole: an agent that says "done" without
  attempting any commit bypasses both L4 and L5 (the hook only fires on
  commit; the script only runs if invoked). *Mitigation:* L1's sticky
  block surfaces "pending close-out" on the next turn whenever
  `verification.md` exists but no close entry is in `decisions.md`; the
  build/fix workflow Step 8 PREAMBLE must name `bin/sage-close` as the
  sanctioned path. This is an acknowledged residual — a Stop-equivalent
  forcing function would require platform support Codex does not expose.

## Compliance signals (Rule self-check)

- **Rule 1A** (memory before work) — performed at workflow start; relevant
  hits include brace-expansion gotcha, `gh pr close --delete-branch`
  gotcha, line-count proxy correction, handoff-vs-execution correction.
- **Rule 3** (artifact on disk) — this spec is the artifact.
- **Rule 4** (checkpoint) — spec presented for [A]/[R] before plan.
- **Rule 5** (verify with pasted output) — encoded in DONE-WHEN #11 and
  #1/#4/#7/#8 acceptance.
- **Rule 7** (record decisions) — entry prepended to `.sage/decisions.md`
  for L3 parking + option [1] selection.
