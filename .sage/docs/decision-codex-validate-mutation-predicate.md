---
title: "ADR — Codex `sage_validate_mutation` predicate"
status: proposed-amended
status_history:
  - 2026-04-29 proposed
  - 2026-04-30 amended (v1 narrowed scope — P3 tier-1 N/A, P4 N/A, bash impl)
date: 2026-04-29
amended: 2026-04-30
codex_min_version: "0.126"
related:
  - .sage/work/20260429-codex-port-rewrite/brief.md
  - .sage/work/20260429-codex-port-rewrite/spec.md (§6.3 — v1 predicate scope; §10 tier-1 soft policy; §16 Cut B+D)
  - .sage/work/20260429-codex-port-rewrite/poc-c1-results.md (anchor empirically validated on 0.126)
  - .sage/docs/research-codex-port-rewrite-base.md (§4.7-bis, §6.2.1)
  - .sage/work/20260429-codex-port-rewrite/cross-port-survey.md (§4 Q4)
supersedes: .sage/docs/decision-codex-mutation-guardrail-stack.md (rejected cycle)
---

# ADR — `sage_validate_mutation` predicate

> **v1 AMENDMENT (2026-04-30) — narrowed scope.** The full
> P1+P2+P3+P4 predicate below is the **v2-target** design. **Codex
> v1 ships a narrowed subset** — read `spec.md §6.3` as the
> authoritative v1 contract, this ADR for v2 redesign reference.
>
> **What v1 actually implements:**
> - **Implementation:** inline bash in
>   `runtime/platforms/codex/hooks/pre-tool-validate.sh` (~40 LOC:
>   jq for payload, yq for manifest frontmatter, case-pattern glob
>   match). NO MCP server, NO `sage_validate_mutation` MCP tool.
>   Cause: Cut B (see ADR-3) deferred MCP entirely.
> - **P1 (active initiative):** ACTIVE in v1 as written below.
> - **P2 (mutation target in scope):** ACTIVE in v1 as written
>   below — Sage state mutations bypass, production code requires
>   P3.
> - **P3 (workflow gate satisfied):** PARTIALLY ACTIVE. Only the
>   "spec.md + plan.md exist with `status: completed`" check fires.
>   The "Tier-1 bypass" row (P3 second row, `tier: 1` field as
>   hard escape) is **N/A in v1** (Cut D, decision 2026-04-30):
>   `tier:` is **soft policy** in AGENTS.md + skill prose only;
>   the bash predicate **ignores `tier:` entirely**. Hard tier-1
>   bypass returns in v2 alongside MCP predicate (richer Python
>   logic where the marker check + `tier_set_by` validation
>   becomes worthwhile).
> - **P4 (approval proof):** N/A in v1. Cause: Cut A (see ADR-2)
>   deferred the entire approval-token mechanism. v1 predicate
>   does NOT check `approved_at`/`approved_by`/`decisions.md`
>   cross-reference. Phase enforcement at validator level becomes
>   soft policy in AGENTS.md + skill prose.
>
> **v1 layer scope:** L1 (Codex hook surface) only. L2 (MCP
> validator) and L5 (git pre-commit backstop) deferred — see
> `spec.md §2` v1 layer scope decision and ADR-3 + ADR-7
> amendments. v2 expansion: L1+L2 once MCP returns.
>
> **What survives this amendment from the original ADR:**
> Cross-port truth, P1+P2 design, deny-fail-closed framing
> (achieved in bash via `exit 2`), tier-1 honest framing,
> failure modes (legacy artifacts, race, edge-case patches),
> "what happens when this fails" decision tree. Multi-hook
> ordering (PASS_ALL_FIRE_UNORDERED, empirical anchor PoC A1
> 2026-04-30) remains binding for v1.
>
> **What is INVALID in v1 from the original ADR:**
> - "MCP server unreachable at startup" failure mode (no MCP).
> - "MCP server crashed mid-session" failure mode (no MCP).
> - "Validator never has to handle this case at runtime" (was
>   about MCP startup; v1 has no MCP startup).
> - References to ADR-3 in Failure modes (MCP server availability).
> - P4 dependency on ADR-2.
>
> **v2 reactivation triggers** (per spec.md §8 + §13.2): when MCP
> returns, P3 tier-1 bypass + P4 approval proof both return
> together (predicate becomes worth Python).

---

## Context

The Codex rewrite's foundational anchor is `PreToolUse(apply_patch)`
calling Sage MCP `sage_validate_mutation`. The validator's job: given an
attempted file mutation, decide **allow** or **deny** based on the
project's current Sage workflow state on disk.

This is the architectural difference between the new Codex port and the
reverted M0–M3 cycle: M0–M3 tried to gate at the *prompt* layer (regex
intent classification). The new port gates at the *mutation* layer
(language-agnostic, deterministic).

The predicate must be **explicit and observable** — readable from disk,
not inferable from agent memory. No string parsing of prompts, no
language detection.

**Empirical anchor status (PoC C1, 2026-04-29):** validated on Codex
0.126.0-alpha.15. `PreToolUse(apply_patch)` fires before mutation,
payload carries `tool_name: "apply_patch"`, `exit 2` from hook
deterministically blocks the mutation, STDERR surfaces back into the
agent context. Codex 0.117 lacked custom-tool hook support — this ADR
therefore **requires Codex ≥ 0.126** (Codex Desktop App or 0.126+ CLI).

**Multi-hook ordering (PoC A1, 2026-04-30):** when multiple entries
are registered for the same event (`PreToolUse(apply_patch)` x2,
e.g. framework + user override), Codex 0.126 fires **all** of them
but in **non-deterministic order** (PASS_ALL_FIRE_UNORDERED). v1
design treats hooks as **order-independent**: the validator's
allow/deny is a pure function of disk state, so concurrent firing
order does not change the verdict. Hook scripts MUST NOT rely on
"running first" or "running last".

## Cross-port truth (relevant context)

Antigravity has no mutation gating; relies on RULES injection +
voluntary compliance. Generic same. Claude port plugin has
`PostToolUse` (after-the-fact, not gating). **The Codex port is the
first Sage port to implement deterministic pre-mutation gating** —
there is no working pattern to copy; we are establishing it.

## Decision

The validator returns **deny** if any of the following predicates fail.
Otherwise **allow**.

### P1 — There is an active initiative

An "active initiative" is a directory under `.sage/work/` whose
`manifest.md` (or, for legacy artifacts without manifest, `spec.md`)
has frontmatter `status: in-progress` and `phase ∈ {plan, deliver,
review}`.

If no manifest matches, the validator examines all artifacts; if zero
artifacts have `status: in-progress`, **deny** with message:
*"No active Sage initiative. Run `/sage` or describe what you're
working on to enter a workflow."*

If multiple match, the most recently `updated:` wins.

**Scope is the current worktree only.** Each git worktree has its own
`.sage/` directory and its own Codex MCP process started from that
worktree's `<worktree>/.codex/config.toml`. The validator never reads
sibling worktrees. Cross-worktree coordination is out of scope for v1.
A user running two Codex sessions in two worktrees gets two
independent validators, each with its own active-initiative view —
this is correct, not a race.

### P2 — Mutation target is in scope

Three categories of mutation target:

1. **Source code, framework, or production assets** — `apply_patch`
   modifying anything outside `.sage/`. Must satisfy P3 (workflow gate).
2. **Sage state mutations** — `apply_patch` modifying anything under
   `.sage/work/<active>/` or `.sage/decisions.md` or
   `.sage/docs/decision-*.md`. **Allow** without P3 (the workflow uses
   these files to record itself; gating them creates a chicken-egg
   problem).
3. **Sage cycle metadata** — `apply_patch` creating a new directory
   under `.sage/work/`. **Allow** (this is workflow entry, not
   workflow execution).

The validator distinguishes by path matching the patch hunk targets.

### P3 — Workflow gate satisfied (only for P2.1 mutations)

For each workflow type, the gate is:

| Workflow | Required artifacts on disk | Required statuses |
|---|---|---|
| `build` (Standard+) | `spec.md` AND `plan.md` | both `status: completed` |
| `build` (Tier 1, ≤1 file, no design decision) | none | none — bypass |
| `fix` (surgical, 1–2 files) | `root-cause.md` OR `spec.md` | `approved` or `completed` |
| `fix` (moderate/systemic) | `plan.md` (fix plan) | `status: completed` |
| `architect` | `brief.md` AND `spec.md` AND `plan.md` | all `status: completed` |
| `research`/`analyze`/`design` | typically read-only; mutation indicates pivot to build/fix → recurse |

**Tier-1 bypass** (P3 second row) is the only escape. Activation:
explicit `tier: 1` field in active initiative's manifest frontmatter.
Default: no bypass.

**Honest framing of Tier-1 trust:** the manifest is a regular file, so
the agent can technically write `tier: 1` itself via `apply_patch`.
The validator does not (and cannot, deterministically) distinguish
"agent set this with user consent" from "agent self-promoted to
bypass". This is accepted risk in v1, mitigated by:
- Tier-1 edits are visible in `git diff` like any other change.
- ADR-7 Stop-hook audit flags initiatives that flipped to Tier-1
  without a corresponding approval entry in `decisions.md`.
- v2 candidate: dedicated `bin/sage tier 1` CLI flow that writes
  `tier_set_by: cli` marker; validator accepts `tier: 1` only with
  the marker. Deferred — not justified by current threat data.

The validator reads the active initiative's manifest, determines
workflow + tier, and checks the corresponding row.

### P4 — Approval proof is intact (only for `status: completed` artifacts)

For each required artifact named in P3, the validator confirms via
ADR-2 (approval-proof schema): frontmatter has `approved_at` AND
`approved_by`, and `decisions.md` has an entry referencing the
artifact path within the last N entries.

If `status: completed` but no approval proof → **deny** with message:
*"Artifact `<path>` claims completed but has no approval proof. Run
the missing checkpoint."* This guards against agent self-marking
artifacts as completed without user gate.

## Options considered

### Option A — File-existence-only predicate (simplest)
Check that `spec.md` and `plan.md` exist for build workflows. Done.
- Pros: minimal validator code.
- Cons: agent can scaffold empty files and bypass. **Antigravity uses
  this approach via voluntary RULES — it works only when the model
  reliably reads the rule. Codex doesn't (M0–M3 proven).**

### Option B — File-existence + status frontmatter (medium)
Files exist AND `status: completed`.
- Pros: simple, deterministic, captures most of the safety.
- Cons: agent can self-mark `status: completed` without user gate.

### Option C — Full predicate (chosen, P1+P2+P3+P4)
File-existence + status + approval proof + mutation-scope distinction.
- Pros: agent cannot bypass without persisting forged approval proof
  to disk (which is detectable). Distinguishes Sage-internal mutations
  from production mutations. Tier-1 bypass exists but requires explicit
  user opt-in.
- Cons: validator complexity; predicate fails in legacy projects
  without manifest.md → fallback to spec.md inferral covers this.

### Option D — Full predicate + content semantic check
Plus: validator reads spec.md and uses an LLM to check mutation aligns
with spec scope.
- Pros: catches "agent writes feature X when spec says Y."
- Cons: adds LLM call per mutation (latency, cost), non-deterministic,
  out of v1 scope.

## Trade-offs

- **Determinism:** P4 (approval proof) is the lever. Without it, agent
  self-marks → bypass. With it, bypass requires forging a proof entry
  in `decisions.md` — possible but observable.
- **Migration cost:** existing `.sage/work/` artifacts have varied
  frontmatter. Validator must tolerate missing fields with safe
  defaults (treat as `in-progress` if `status` absent). ADR-2 (approval
  proof schema) defines what frontmatter the validator expects going
  forward; legacy artifacts get a one-time migration script.
- **False denies:** agent attempts mutation in middle of
  workflow. Acceptable — error message routes to next gate.
- **Two-layer enforcement (Codex hooks + git hooks).** This ADR's
  validator runs **inside Codex** as a `PreToolUse(apply_patch)`
  hook — Codex lifecycle event, fires per tool call, deny via
  exit 2. The L5 pre-commit backstop is a **separate system**:
  `.githooks/pre-commit` is a git VCS event, fires per commit,
  runs regardless of which agent (or human) issued the commit.
  These are two distinct gates that happen to share log files
  (`.sage/.precommit.log`, `.sage/.session-mutations.log`) for
  Stop-hook cross-check (ADR-7 C5).
- **L5 backstop is bypassable by `git commit --no-verify`.** Honest
  framing: `--no-verify` defeats the git layer, and we do not detect
  bypass server-side in v1. Mitigation: AGENTS.md prose forbids
  `--no-verify` outside explicit user-approved exceptions, and the
  Stop-hook audit (ADR-7) compares git log against in-session commit
  events. v2 candidate: server-side hook (GitHub branch protection /
  pre-receive). Deferred — not on critical path for v1.
- **False allows:** P2.2/P2.3 (Sage state) intentionally bypass. Risk:
  agent writes a fake approval entry to `.sage/decisions.md` and a
  matching `approved_by`/`approved_at` block in an artifact's
  frontmatter, then a subsequent mutation passes P4 on the strength
  of that forged proof. **Accepted risk in v1** (user decision,
  2026-04-29): no current data shows this failure mode is common in
  practice; M0–M3 failures were at the prompt-classification layer,
  not at decisions.md forgery. Mitigations remain: forged entries
  appear in `git diff`, and ADR-7 Stop-hook audit at turn end
  cross-checks "did the user actually speak between session start
  and the new approval?". Revisit if outcome harness or production
  use surfaces this as a real attack path.

## Failure modes

- **Legacy artifacts (no manifest, no status):** validator falls back
  to permissive (treat as in-progress). Logged as "frontmatter migration
  needed" via `sage doctor`.
- **Race: two initiatives flipped to in-progress:** validator picks
  most recent `updated:`, logs warning.
- **MCP server unreachable at startup:** with `required = true` on
  the MCP server, Codex hard-fails session creation with a clear
  copyable error (PoC C1 T2, empirically confirmed). Validator never
  has to handle this case at runtime — the session simply doesn't start.
- **MCP server crashed mid-session:** PoC C1 T3 (Codex 0.126) shows
  Codex returns `Transport closed` as a clean tool error and **does
  NOT respawn** the server within the session. Every subsequent
  `apply_patch` call therefore fails — agent cannot bypass by retry.
  This is **deny-fail-closed by construction** (validator can't say
  allow, so the mutation can't proceed). UX caveat: user must restart
  Codex; surfaced via `sage doctor` (see ADR-3).
- **Path matching fails on edge-case patch hunks** (binary files,
  rename-only, mode-change-only): treat as P2.1 (most restrictive).
- **Cold-start: first-ever mutation in a brand-new project, no
  manifest or `.sage/work/` directory yet.** P1 finds zero
  in-progress initiatives → deny. This is correct: agent must first
  create the cycle directory (P2.3, allowed) and an initiating
  manifest (Sage state, P2.2, allowed) before any production-code
  mutation. The error message must guide the user: *"No active Sage
  initiative. Run `/sage`, describe what you're working on, and let
  the workflow create the cycle directory before editing production
  files."* This deny is the intended UX, not a bug.

## Consequences

- ADR-2 (approval proof schema) becomes hard prerequisite — the
  validator depends on it.
- Sage workflow definitions (`core/workflows/*.workflow.md`) must
  declare which artifacts are required at which gate. Currently encoded
  in workflow markdown prose — needs structured frontmatter for
  validator to read.
- `sage doctor` checks "are there `status: completed` artifacts without
  approval proof?" — flags forged or migrated state.
- Tier-1 bypass requires UX in `bin/sage` or skill prose: how does the
  user explicitly mark an initiative tier 1? Likely a manifest field
  set during workflow entry, not retroactively.

## What happens when this fails

1. **Validator denies a legitimate mutation** — user sees clear error,
   runs missing gate, retries. Friction is the design intent.
2. **Validator allows a mutation that should be denied** — caught by
   ADR-7 Stop hook audit at turn end (logs gap to `.sage/decisions.md`)
   and by L5 pre-commit backstop. Outcome harness measures rate.
3. **Predicate too strict → workflow becomes painful** — telemetry from
   outcome harness identifies which P-rule denies most often;
   architecture revision in v2 once data exists.

## Status: proposed
Awaiting user approval at design checkpoint after Batch 3 + spec.md.
