---
cycle_id: "20260424-codex-enforcement-hybrid-levers"
title: "Plan: Codex Enforcement Hybrid Levers (L1+L2+L4+L5)"
type: plan
workflow: build
phase: plan
status: completed
scope: standard
created: 2026-04-24
spec: .sage/work/20260424-codex-enforcement-hybrid-levers/spec.md
review_verdict: APPROVE-WITH-NOTES
related:
  - .sage/work/20260424-codex-enforcement-hybrid-levers/spec.md
  - .sage/docs/analysis-codex-enforcement-surface-audit.md
  - .sage/work/20260423-branch-worktree-operating-model/manifest.md
  - runtime/platforms/codex/hooks/pre-prompt.sh
  - runtime/platforms/codex/HOOKS.md
---

# Plan: Codex Enforcement Hybrid Levers

Nine tasks, ordered so each task can be tested independently and so later
tasks consume artifacts the earlier ones already published. Test-first
(Base Principle 1) for every task that ships code.

The order is **not** the audit's lever numbering. It is the dependency
order:

1. **Fixtures** — built once, consumed by every later task.
2. **Validator** — single source of truth, consumed by L1, L4, L5.
3. **Template + skill refs** — produces a known-valid file shape.
4. **L1 sticky context** — depends on validator (for "ready to close").
5. **L4 sage-close script** — depends on validator + branch model.
6. **L5 pre-commit hook** — depends on validator.
7. **Install ergonomics** — depends on L5.
8. **Path convention pin** — small docs/skill cleanup, does not gate later
   work but must land before end-to-end self-close.
9. **End-to-end self-close** — closes this cycle through the new bundle
   and proves DONE-WHEN #10.

Path layout decisions (from spec handoff + reviewer note #4):
- Platform-specific helpers: `runtime/platforms/codex/hooks/lib/`
- Generic close-out script: `bin/sage-close`
- Hook scripts: `.githooks/`
- Test fixtures: `runtime/platforms/codex/hooks/tests/fixtures/`
- Test runners: `runtime/platforms/codex/hooks/tests/`
- Verification artifact location, pinned: `.sage/work/<slug>/verification.md`
  (slug root, never under a phase subdir).

---

## Task 1 — Test fixtures builder

**Why first:** reviewer item #6. Without a single fixtures source, each
later task ad-hocs its own directories and the suites diverge.

**Files:**
- `runtime/platforms/codex/hooks/tests/fixtures/build_fixtures.sh` (new)
- `runtime/platforms/codex/hooks/tests/fixtures/README.md` (new, short)
- Fixture trees produced into `runtime/platforms/codex/hooks/tests/.tmp/`
  (gitignored), not committed.

**Scope:**
- Five `.sage/` states matching DONE-WHEN #1: `no-active`, `brief-only`,
  `spec-only`, `plan-only`, `verification-pending`. Each is a minimal
  `.sage/work/<slug>/` directory tree with frontmatter set so the
  active-state computation has unambiguous answers.
- One throwaway git repo fixture with a documented branch graph
  (`selfhost`, `codex-port`) for L4 dry-run + L5 hook tests.
- One sample valid `verification.md` and one of each defective shape
  (missing each required heading).

**Done when:**
- `bash build_fixtures.sh` produces all fixture trees idempotently;
  re-run is a no-op.
- README enumerates each fixture and which task consumes it.
- README also pins the **test runner choice** (default: `python3 -m
  unittest discover` for portability — no extra dependency. Pytest
  optional, documented as "if installed, also passes").
- `git status` is clean after a build (everything lands under `.tmp/`).

---

## Task 2 — `verification_check.py` validator + tests

**Why second:** the validator is the single source of truth for L1 (ready
to close), L4 (close gate), L5 (commit gate). Building anything else first
risks divergent shape rules.

**Files:**
- `runtime/platforms/codex/hooks/lib/verification_check.py` (new)
- `runtime/platforms/codex/hooks/lib/__init__.py` (new, empty)
- `runtime/platforms/codex/hooks/tests/test_verification_check.py` (new)

**Scope:**
- Public surface: `validate(path: str) -> tuple[bool, list[str]]` and a
  module constant `REQUIRED_SECTIONS = (...)` exposing the four headings
  in canonical order.
- Shape rules (from spec L2 + DONE-WHEN #11 update):
  - File exists at `path`.
  - Frontmatter present with `cycle_id`, `verified_at`, `scope`, `closed`.
  - All four headings present, in the canonical order.
  - "## Test command + pasted output" body contains a fenced block
    whose body has at least one non-command line (the L5/DONE-WHEN #11
    shape check).
- Failure mode: each missing/malformed section produces one entry in the
  reasons list. No exceptions for malformed files — return `(False, [...])`.
- **No `{N,M}` quantifiers**; the heredoc gotcha applies if any caller
  inlines a regex via `python3 -c`. Use `*?` everywhere needed.

**Done when:**
- `python3 -m pytest runtime/platforms/codex/hooks/tests/test_verification_check.py`
  passes (or the project's chosen runner — confirm in T1 fixtures README).
- Each defective fixture produces exactly the expected reasons list
  (covered by parametrized test cases).
- Happy-path fixture returns `(True, [])`.

---

## Task 3 — `verification-template.md` + skill references

**Why third:** L1 sticky context surfaces "ready to close" only when a
template-shaped file can exist. Cannot exist before template is published.

**Files:**
- `.agents/skills/sage:build/templates/verification-template.md` (new)
- `.agents/skills/sage:build/SKILL.md` (edit Step 6 to reference template)
- `.agents/skills/sage:fix/SKILL.md` (edit Step 4 to reference template)

**Scope:**
- Template ships with the four required headings + frontmatter scaffolded
  with placeholder values (`cycle_id: TODO`, `verified_at: TODO`,
  `scope: TODO`, `closed: false`).
- Skill edits add a single line each pointing to the template path and
  saying "verification.md MUST follow this template — validated by
  `verification_check.py` and by the pre-commit hook".

**Done when:**
- `verification_check.validate(<filled-template>)` returns `(True, [])`
  after frontmatter placeholders replaced and a one-line stdout pasted.
- Both skill edits land. Diff of each shows exactly one new line
  paragraph + path reference.

---

## Task 4 — L1: `pre-prompt.sh` sticky `additionalContext` + `active_state.py`

**Why fourth:** L1 closes the audit's largest finding cluster (#1, #6
soft) and is the highest-traffic surface. Validator is now in place so
the "ready to close" line works on day one.

**Files:**
- `runtime/platforms/codex/hooks/lib/active_state.py` (new)
- `runtime/platforms/codex/hooks/pre-prompt.sh` (edit, additive)
- `runtime/platforms/codex/hooks/tests/test_active_state.py` (new)
- `runtime/platforms/codex/hooks/tests/test_pre_prompt_sticky.sh` (new)

**Scope:**
- `active_state.py` exposes `compute(sage_root: str) -> StickyBlock`
  returning the deterministic 6–12 line summary.
- **Active-state semantics — reuse existing hook predicate.**
  `pre-prompt.sh` already defines "active" via `_initiative_is_active`
  (any non-terminal frontmatter on spec/plan/brief/fix-plan), and a
  `TERMINAL_STATUSES = {"completed", "abandoned"}` constant. Reuse both
  — do NOT introduce a narrower `status: in-progress` rule, or the
  sticky block will diverge from what the hook actually gates on
  (plan-reviewer note).
- **Active-initiative tie-breaker (reviewer item #1):** when 2+
  initiatives are active by the existing predicate, pick the one with
  the most-recently-updated `manifest.md` mtime; if no manifest, fall
  back to most-recently-updated frontmatter `updated:` field; if still
  tied, alphabetical by slug. Write the chosen slug into the sticky
  block prefixed with the count: `Active: <slug> (1 of N active)`.
- Phase precedence: `verification` > `implementation` > `plan` > `spec` >
  `brief`, computed from the most-advanced artifact present.
- "Ready to close" line: emitted when `verification.md` exists, validator
  returns `(True, [])`, **and** the verification.md frontmatter has
  `closed: false` (the same predicate T5's `verification_closed` uses).
  No coupling to `decisions.md` heading format — single source of truth
  is the verification.md frontmatter (plan-reviewer note).
- Size budget enforced in `active_state.py` (truncate phase-specific
  hints first, then drop optional lines, never drop required lines).
  Hard cap 1.2 KB; soft target 600 B.
- `pre-prompt.sh` change is additive: existing block/redirect logic
  untouched; new sticky context appended on every emission path,
  including the "no decision change" path. **Refactor hint** (plan
  reviewer): there are multiple `sys.exit(0)` paths in the embedded
  Python today. Introduce a single `emit_and_exit(decision, …)` helper
  that always appends sticky context, and route every exit through it.

**Done when:**
- `test_active_state.py` covers all five fixture states from T1 plus the
  multi-active tie-breaker case; passes.
- `test_pre_prompt_sticky.sh` invokes the hook five times with the
  fixture states and asserts the emitted JSON contains a sticky block in
  every case; passes.
- Existing `pre-prompt.sh` test suite still passes (regression check —
  DONE-WHEN #12).
- Worst-case fixture produces ≤ 1.2 KB block; common fixtures ≤ 600 B
  (DONE-WHEN #2).

---

## Task 5 — L4: `bin/sage-close <slug>` atomic close-out

**Why fifth:** depends on validator. Independent of L1 hook (script-side
lever).

**Files:**
- `bin/sage-close` (new, executable bash)
- `runtime/platforms/codex/hooks/tests/test_sage_close.sh` (new)

**Scope:**
- Single positional arg: slug. Resolves to `.sage/work/<slug>/`.
- Phases as in spec (preflight → verify → commit → integrate → push →
  record). Each phase is a bash function returning 0/non-0; the script
  short-circuits on first failure.
- **Idempotence detection (reviewer item #5):** for each phase, a
  `phase_done_<name>` predicate. Predicates:
  - `commit_done`: `git -C <inner-worktree> log --grep="<cycle_id>" -n1`
    on the inner branch returns a hit.
  - `integrate_done`: same grep on the integration branch returns a hit
    AND that hit is a merge commit.
  - `push_done`: `git rev-parse <branch>@{upstream}` matches local tip
    for both branches.
  - `record_done`: `.sage/decisions.md` first 50 lines contain the slug
    under a heading.
  - `verification_closed`: frontmatter `closed: true`.
  Re-run skips any phase whose predicate is true; logs `Sage: <phase>
  already done, skipping.`
- Branch model: **hardcode the defaults** `inner=selfhost`,
  `integration=codex-port`, `mirror=main`, with a top-of-script comment
  pointing to `.sage/work/20260423-branch-worktree-operating-model/manifest.md`
  as the rationale. The manifest is prose, not structured — parsing it
  is over-engineering. If the model ever changes, edit both files
  together (plan-reviewer note).
- `SAGE_CLOSE_DRY=1` short-circuits all mutating commands and prints the
  planned actions only (DONE-WHEN #4).
- `SAGE_CLOSE_NO_PUSH=1` skips push phase (for tests).
- HEREDOC commit and merge messages, never `git add -A`. Never
  `--no-verify` and never `--delete-branch` (carrying forward the prior
  `gh pr close` gotcha as a coding rule for this script).
- Final stdout line: `Sage: close-out complete for <slug>.`

**Done when:**
- `SAGE_CLOSE_DRY=1 bin/sage-close <fixture-slug>` against T1 fixture
  prints all phases without touching git; exits 0 (DONE-WHEN #4).
- `bin/sage-close <fixture-slug>` against fresh fixture produces one
  commit on inner branch, one merge commit on integration branch, one
  prepended decisions entry; exits 0 (DONE-WHEN #6).
- Re-running on already-closed fixture logs "already done" for each
  phase, exits 0, makes no new commits, no duplicate decisions entry
  (DONE-WHEN #5). **Test must explicitly capture before/after state**
  (plan-reviewer note): record `git rev-parse HEAD` on inner +
  integration branches and `wc -l .sage/decisions.md` *before* re-run,
  re-run, then assert all three values are unchanged. Logging "already
  done" is necessary but not sufficient — a buggy predicate could log
  it while still committing.
- Verification failure (defective verification.md fixture) blocks at
  phase 2 with reasons; exits non-0; no commits made.

---

## Task 6 — L5: `.githooks/pre-commit` hook

**Why sixth:** depends on validator. Independent of L4.

**Files:**
- `.githooks/pre-commit` (new, executable bash)
- `runtime/platforms/codex/hooks/tests/test_pre_commit_hook.sh` (new)

**Scope:**
- Trigger condition uses `git diff --cached --name-only` and applies
  this **two-stage filter (reviewer item #2)**:
  - Stage A: collect any staged path matching `^\.sage/work/([^/]+)/`;
    extract the slug. If none, the hook exits 0 immediately (no
    initiative touched).
  - Stage B: read `.sage/work/<slug>/spec.md` (or `brief.md`) frontmatter.
    If `scope` is missing or `lightweight`, exit 0.
  - Stage C — **implementation-file detection.** Require at least one
    staged path that is **not** under `.sage/` and **not** under the
    docs allowlist (`README*`, `*.md` at repo root, `docs/**`). If no
    such path is staged, exit 0 — this is a spec/plan/docs-only commit
    (DONE-WHEN #9).
  - If we reach this point, we have a Standard+ initiative with
    implementation files staged. Validate `verification.md`.
- On validator failure, exit non-0 with one line:
  `Sage: pre-commit blocked — verification.md for <slug>: <first reason>.
  See .sage/work/<slug>/verification.md.`
- No network calls, no git index writes, no `--no-verify` recommendation
  (the user must consciously type it).

**Done when:**
- Negative case: fixture commit with implementation file staged + missing
  verification.md → blocked with correct message; exits non-0
  (DONE-WHEN #7).
- Positive case: same commit with valid verification.md → allowed; exits
  0 (DONE-WHEN #8).
- False-positive ceiling: commit staging only `spec.md` → allowed
  regardless of verification.md state (DONE-WHEN #9).
- **Mixed-case test (plan-reviewer note):** commit staging both
  `spec.md` AND an implementation file → must apply the gate (Stage C
  hits because of the impl file). If verification.md is missing →
  blocked. If valid → allowed. This is the realistic case and must
  fail closed.
- Lightweight scope commit: implementation file staged, scope:
  lightweight in frontmatter → allowed (no gating).
- **Docs allowlist coverage check:** test that committing only
  `AGENTS.md`, `CLAUDE.md`, `README.md`, or any `docs/**` path is
  ungated (these live at repo root or under docs/ and end in .md, so
  the rule already covers them; assertion confirms the rule actually
  matches in practice).

---

## Task 7 — `bin/sage-install-hooks` + install ergonomics

**Why seventh:** L5 only fires when `core.hooksPath` points at
`.githooks/`. Without an install path, L5 silently does nothing for any
fresh contributor (reviewer item #3).

**Files:**
- `bin/sage-install-hooks` (new, executable bash)
- `README.md` (edit — add a one-paragraph "Repo hooks" section)
- `runtime/platforms/codex/hooks/tests/test_install_hooks.sh` (new)

**Scope:**
- `bin/sage-install-hooks` runs `git config core.hooksPath .githooks` in
  the current repo, verifies the resulting config matches, prints
  `Sage: hooks installed (.githooks).` Idempotent.
- README section names the script and points to `.githooks/pre-commit`
  for what it does. Single short paragraph.
- Discovery surface: inspect `bin/sage`. If it already runs first-run
  setup, append a one-line check that suggests `bin/sage-install-hooks`
  when `core.hooksPath` is unset. **If `bin/sage` does NOT have
  first-run setup**, prepend a decisions.md entry (Rule 7) naming this
  as a known install-ergonomics gap to revisit, instead of silently
  skipping (plan-reviewer note).

**Done when:**
- Running `bin/sage-install-hooks` in a throwaway git repo sets
  `core.hooksPath = .githooks`. Re-run is a no-op.
- `git config --get core.hooksPath` returns `.githooks` after run.
- README edit is one short paragraph, no marketing.

---

## Task 8 — Pin `verification.md` path convention

**Why eighth:** small consistency fix surfaced by reviewer item #4. Must
land before T9 self-close so the path is unambiguous when L1, L4, L5 all
look for the file.

**Files:**
- `.agents/skills/sage:build/SKILL.md` (Step 6 — pin path)
- `.agents/skills/sage:fix/SKILL.md` (Step 4 — pin path)
- `.agents/skills/sage:build/templates/verification-template.md`
  (frontmatter comment naming canonical path)

**Scope:**
- One sentence in each location: "verification.md lives at
  `.sage/work/<slug>/verification.md` — slug root, not under any phase
  subdirectory."

**Done when:**
- All three files include the sentence verbatim.
- No grep hit anywhere else in the repo for an alternate path
  (`verification/verification.md`, `verification-*.md`, etc.) referenced
  as canonical.

---

## Task 9 — End-to-end self-close (DONE-WHEN #10)

**Why last:** proves the whole bundle on this cycle.

**Files:**
- `.sage/work/20260424-codex-enforcement-hybrid-levers/verification.md`
  (new — written from the template)
- `.sage/decisions.md` (close entry, prepended by `bin/sage-close`)

**Scope:**
- Fill the template's four sections for **this** cycle:
  - Pre-fix reproducer: the residual compliance score and the seven
    findings being attacked.
  - Implementation summary: list of the eight prior tasks landed +
    files touched.
  - Test command + pasted output: the actual stdout of the test runner
    invocation (DONE-WHEN #11).
  - Close-out checklist: every DONE-WHEN box ticked or explicitly
    deferred with a reason.
- **Risk-handling for self-close (plan-reviewer note):**
  1. Run `SAGE_CLOSE_DRY=1 bin/sage-close
     20260424-codex-enforcement-hybrid-levers` first. Paste the dry-run
     output and present `[A]/[R]` to user before the real run. Do not
     skip the dry-run gate even on a green bill of health from earlier
     tasks.
  2. If the real run fails mid-phase, recovery is via T5's idempotence
     contract: re-run after fixing the failing precondition, all
     completed phases skip, only the failing phase + later run.
     **Recovery is part of T9's done-when** — if T5's idempotence is
     broken in practice (not just in fixture), T9 fails and we fall
     back to manual close.
- Run `bin/sage-close 20260424-codex-enforcement-hybrid-levers` for
  real after dry-run approval. Expect the script to: validate the
  verification, commit on `selfhost`, merge into `codex-port`,
  push (or print the planned push if user chooses
  `SAGE_CLOSE_NO_PUSH=1`), prepend the close entry.

**Done when:**
- All 12 DONE-WHEN criteria from spec satisfied (each item carries a
  satisfied-by reference in verification.md).
- Dry-run `SAGE_CLOSE_DRY=1 bin/sage-close` exit 0 on this cycle and
  user approved the planned actions.
- Real `bin/sage-close` exit 0 on this cycle.
- If real run failed at any point, recovery via re-run succeeded
  without manual git operations (idempotence held in production, not
  only in fixture).
- `manifest.md` flipped to `status: complete`.
- `decisions.md` carries one new top-of-file entry summarizing the cycle.

---

## Task ordering rationale (one-liner)

Fixtures → validator → template → L1 → L4 → L5 → install ergonomics →
path pin → self-close. Earlier tasks are pure additions that cannot
break anything; later tasks layer mechanism on top. Each task is
independently testable, so a failure on T5 does not block T6.

## Verification strategy

Every task ships with a test (or a doc edit clearly diff-able). Final
verification.md aggregates evidence by referencing the per-task tests
and pasting end-to-end stdout from `bin/sage-close` dry-run + real run
on this cycle.

## Out of scope (carried from spec)

L3 (parked), L6 (rejected), L7, L8, per-turn AGENTS.md re-injection,
network-in-hooks, cross-platform UX parity. No deviations from spec
non-goals introduced by this plan.
