---
title: "ADR — Codex approval proof schema"
status: deferred-to-v2
status_history:
  - 2026-04-29 proposed
  - 2026-04-30 deferred-to-v2 (Cut A — UPS approval gate cut entirely from v1)
date: 2026-04-29
amended: 2026-04-30
related:
  - .sage/work/20260429-codex-port-rewrite/brief.md
  - .sage/work/20260429-codex-port-rewrite/spec.md (§6.2 — UPS deferred; §13.2 v2 promotion triggers; §16 Cut A)
  - .sage/docs/decision-codex-validate-mutation-predicate.md
  - .sage/docs/research-codex-port-rewrite-base.md (§5 row 18)
  - .sage/work/20260429-codex-port-rewrite/cross-port-survey.md (§4 Q5)
supersedes: .sage/docs/decision-codex-approval-proof.md (rejected cycle)
---

# ADR — Approval proof schema

> **DEFERRED TO v2 (decision 2026-04-30, Cut A).** This ADR's entire
> approval-token mechanism (UPS hook, `.approval-pending` file,
> `.ups-hook.log`, `sage_record_approval` MCP tool, frontmatter
> `approved_at`/`approved_by`/`decisions.md` cross-check) is
> **NOT shipped in Codex v1**. The validator (ADR-1) v1 narrowed
> predicate skips P4 (approval proof) entirely.
>
> **Why deferred:** see `spec.md §6.2` and `decisions.md` 2026-04-30
> entry "Codex approval gate deferred entirely from v1". Briefly:
> every keyword/markup/numeric mechanism considered violated brief
> Hard Anti-Pattern (no keyword classification) or required
> agent/user discipline not justified by current threat data
> (M0-M3 failure mode was different — agent ignored AGENTS.md
> routing, NOT agent forging approval).
>
> **v2 reactivation conditions** (binding, must fire before any
> v2 design starts — see `spec.md §13.2`):
> 1. Phase-jump rate above threshold X% (measured by
>    `turn-audit.sh` `phase_jump_observed` probe).
> 2. User-pain rate above Y/week (self-reports via `sage doctor`
>    or self-learning storage).
> 3. Forge attempt observed (audit detects fabricated "user
>    approved" claims without corresponding user message).
>
> **v2 design constraint locked** (per decisions.md 2026-04-30):
> deterministic surface only — numeric / markup / slash-command.
> Never keyword/regex/semantic match on free text. Never LLM
> classification per UPS message.
>
> Content below is preserved as v1-baseline-rejected design for
> v2 redesign reference. **Do NOT implement in v1.** The v2 ADR
> replacing this one will pick a deterministic surface from the
> set above informed by the empirical data collected by v1
> outcome harness.

---

## Context

The validator from ADR-1 needs to confirm that "this artifact was
approved by the user" — not "the agent says it was approved." The
proof must:

1. Live on disk, survive compaction / fresh subagents / new sessions.
2. Be machine-readable (validator parses without LLM).
3. Be human-auditable (user can verify `decisions.md` matches reality).
4. Be hard to forge accidentally (if agent writes the proof without
   user input, that's detectable).

Cross-port truth: Antigravity + Generic use **file existence as
implicit approval**. Works for synchronous human+agent in 1 turn.
Codex is asynchronous (compaction, subagents, multi-session cycles) —
file existence is insufficient. This is a **Codex-specific hard
requirement**, not a design preference.

## Decision

Approval proof is **dual-redundant**: stored on the artifact
(frontmatter) AND in the project log (`decisions.md`). Validator
checks both; mismatch = deny.

### Schema A — Artifact frontmatter

```yaml
status: completed
approved_at: 2026-04-29T14:23:00Z
approved_by: alexostl  # username, not "agent"
approval_gate: design  # which checkpoint: elicitation | design | plan | milestone-N | final
approval_record: .sage/decisions.md#2026-04-29-codex-port-rewrite-brief-approved
```

- `approved_at` — ISO 8601 UTC, written by `sage_record_approval` MCP tool.
- `approved_by` — current `whoami` (or `git config user.name` fallback).
  **Never `agent`, `claude`, `codex`, etc.** Validator denies if value
  matches a known-agent pattern.
- `approval_gate` — string identifying which workflow checkpoint
  produced this approval. Free-form for now; will be enumerated in v2.
- `approval_record` — path-with-anchor to the matching `decisions.md`
  entry. Validator follows this and verifies the section exists.

### Schema B — `decisions.md` entry

```markdown
### YYYY-MM-DD — <title matching approval>

<reasoning, what was approved, why, alternatives>

Approval gate: design (or whichever)
Artifact: .sage/work/<cycle>/spec.md
```

- Section heading anchor must match the artifact's `approval_record`
  field.
- Validator's match is **structural**: heading exists in `decisions.md`
  AND the section body mentions the artifact path verbatim.
- Soft constraint (not enforced): the section explains *what* was
  approved and *why*. This is for the human reader; validator doesn't
  inspect prose semantics.

## Approval write flow

User approves at a checkpoint. Agent calls
`sage_record_approval(artifact_path, gate, decision_text)`:

1. MCP tool generates timestamp, reads `whoami`/git config.
2. Writes frontmatter fields atomically (mktemp + mv).
3. Prepends section to `decisions.md` matching schema B.
4. Returns `approval_record` anchor for downstream artifacts to
   reference.

The agent **does not write approval frontmatter directly**. Always
through the MCP tool. This forces the timestamp + actor identity to be
synthesized at one point, not faked by composing strings in agent
output.

## Approval authority — who can call `sage_record_approval`

The MCP tool refuses to write a proof unless a one-shot
**approval-pending token** exists at `.sage/.approval-pending` AND
matches the artifact path. The token is the only path from real user
input to a valid approval proof; the agent cannot self-issue one.

### Mechanism

1. **`UserPromptSubmit` hook** runs on every user message
   (PoC C1 ext. 2026-04-29 confirmed: payload contains `prompt` field
   with the user's literal text, on Codex 0.126).
2. **Hook script** (`runtime/platforms/codex/hooks/ups-approval.sh`)
   detects English Sage gate vocabulary in the prompt — literal
   `[A]`, `[a]`, `approve`, `continue` (whole-word, case-insensitive).
   On match, it writes `.sage/.approval-pending` containing JSON:
   ```json
   {
     "cycle": "<inferred from latest active manifest, or null>",
     "gate": "<from latest pending checkpoint, or null>",
     "issued_at": "2026-04-29T14:23:00Z",
     "expires_at": "2026-04-29T14:28:00Z"
   }
   ```
   `cycle` and `gate` are best-effort; the validator does NOT require
   them to match — the token's mere existence + non-expiry is the
   gate.
3. **`sage_record_approval` MCP tool**, before writing any proof:
   - Reads `.sage/.approval-pending`. If missing → deny with
     *"No pending user approval. The user must explicitly type
     [A] / approve / continue first."*
   - Checks `expires_at` (5-minute window). If expired → deny + delete.
   - On success: writes frontmatter + `decisions.md` (steps 1–4
     above), then **deletes the token** (one-shot use).
4. **Stop hook** (ADR-7) audits stale tokens at turn end: if a
   token exists at session end without being consumed, log an
   incident note (user typed approval but agent never followed
   through).

### Non-goals (intentional)

- **Not intent classification.** The hook does not parse intent,
  detect Polish, or interpret meaning. It looks for literal English
  Sage gate vocabulary, which is part of Sage's published checkpoint
  surface (Zone 2 footer: `[A] Approve`). Users who type "yes go
  ahead" or "tak, pojechać dalej" do NOT issue a token. This is a
  trade-off accepted for determinism: the surface itself teaches the
  required vocabulary; `sage status` will surface a *"approval
  pending — type [A] to confirm"* hint to coach the user.
- **Not session-wide consent.** Each gate needs its own user
  approval. Five-minute expiry prevents a stale token from carrying
  consent across unrelated mutations.

### Why this works

The hook is the only writer of `.sage/.approval-pending`. The hook is
fired by Codex on real user input — it cannot be triggered by the
agent constructing a fake message to itself. Even if the agent calls
`apply_patch` to forge the token file, that mutation goes through
PreToolUse → `sage_validate_mutation`, where P2.2 lets it pass (it's
in `.sage/`) but the Stop-hook audit (ADR-7) flags any non-hook write
to `.approval-pending` as a forge attempt. Honest framing: detectable,
not preventable, consistent with V3 from brief.

## Options considered

### Option A — Frontmatter only
- Pros: simplest schema; one source of truth.
- Cons: artifact gets renamed/moved → proof orphaned. No project-wide
  audit trail.

### Option B — `decisions.md` only
- Pros: chronological audit trail; survives artifact moves.
- Cons: artifact's `status: completed` and the matching log entry can
  drift independently. Validator must scan whole log per check.

### Option C — Both, cross-referenced (chosen)
- Pros: structural integrity (mismatch = deny); both views available
  (per-artifact and chronological); forging requires editing two
  files in coordination.
- Cons: schema is more complex; one field on each side requires the
  other to be valid.

### Option D — Cryptographic signing
HMAC over (artifact-hash + timestamp + user) signed by a per-project
key.
- Pros: tamper-evident.
- Cons: massive overengineering for a junior-dev solo project. Out of
  scope for v1; revisit if multi-user trust ever matters.

## Trade-offs

- **Forge resistance:** to bypass, agent must (a) write valid
  frontmatter with realistic timestamp + user identity, AND
  (b) prepend a matching `decisions.md` entry. Both steps are visible
  via `git diff`. **Detectable, not preventable.** This is intentional
  — the rewrite uses honest framing (V3 from brief), not crypto-grade
  enforcement.
- **Migration burden:** existing artifacts have no proof. ADR-1 P4
  marks them as "needs migration" rather than denying outright.
  Migration script: `sage doctor --migrate-approval` walks
  `.sage/work/`, prompts user per artifact, fills frontmatter.
- **`decisions.md` size:** prepending grows the file unboundedly.
  Existing rotation rule (200 lines → archive to
  `decisions-{YYYY-MM-DD}.md`) handles this. Validator searches
  current file first, then archives if needed.
- **Multi-user / future:** `approved_by` is a single string today.
  Schema is forward-compatible: future array `[alex, alice]` for joint
  approval is a one-field change.
- **Single-writer assumption (v1).** One Codex session per worktree at
  a time. `sage_record_approval` does NOT lock `decisions.md`;
  concurrent writers from two sessions in the same worktree would
  corrupt the prepend (lost write). Sub-agents within one session
  are sequential (parent waits for sub) so they don't race. **v2
  trigger conditions for adding `flock(2)` on `.sage/.decisions.lock`
  around the prepend:** any user reports interleaved sessions in
  the same worktree, or the outcome harness exposes the race in
  practice.
- **Status field alias normalization.** Validator accepts only the
  literal string `status: completed` (with -d). Legacy initiatives
  using `status: complete` (without -d) are normalized by `sage
  doctor --migrate-approval` to the canonical form before the
  validator is asked. This avoids a special-case in the validator.

## Failure modes

- **Clock skew on machine:** timestamp may be wrong by minutes. Not
  validator-relevant; for log readability only.
- **`whoami` returns `root` or generic name:** validator accepts any
  non-known-agent pattern. Only blocks values matching `claude`,
  `codex`, `agent`, `assistant`, `bot`.
- **`decisions.md` rotation in middle of approval write:** atomic
  write to single file (current `decisions.md`). Rotation is a
  separate, manual action triggered after the write.
- **User edits `decisions.md` and breaks the anchor:** validator's
  next check denies. Error message: *"Approval record at
  `.sage/decisions.md#anchor` not found. Run `sage doctor` to
  re-link."*

## Consequences

- ADR-1 P4 reads frontmatter → validates against `decisions.md`.
  Direct dependency.
- `sage_record_approval` is a **mandatory** MCP tool. Cannot be
  optional.
- `bin/sage` may grow `sage approve <artifact> [--gate design]` for
  CLI-driven approval (not v1 must-have, but useful for headless
  automation).
- Outcome harness must include "agent tries to mark approval without
  user input" as a test case.
- Tooling for migrating legacy artifacts is needed —
  `sage doctor --migrate-approval`.
- **Migration plan for the existing 14 mixed-schema initiatives** in
  `.sage/work/` (status `complete` vs `completed`, missing
  `approved_at` / `approved_by`, varied `phase` values) is a
  pre-v1-cutover task tracked in Batch 3. Acceptance for the
  migration: (a) `sage doctor --migrate-approval --dry-run` lists
  every artifact that would be modified with diff preview; (b) user
  approves the batch in one go via `[A]` checkpoint; (c) migration
  writes proofs marked `approval_gate: legacy-migration` and a
  single `decisions.md` entry summarizing the batch; (d) post-run
  verification passes (no `status: complete` remaining; every
  `status: completed` has `approved_at`). The validator MUST NOT
  ship to v1 production with un-migrated artifacts in the project.

## What happens when this fails

1. **User approves verbally, agent forgets to call
   `sage_record_approval`** → next mutation denies. User runs
   `/sage:continue` or types approval again; MCP tool catches up.
2. **Frontmatter present but `decisions.md` entry missing** (e.g.,
   manual edit deleted it) → validator denies. `sage doctor` rebuilds.
3. **`decisions.md` archived but anchor still referenced** →
   validator falls back to archive search; if not found, denies.
4. **Agent forges proof intentionally** → visible in `git diff`. No
   automated detection in v1; relies on user reading commits or PR
   review. v2 candidate: `sage doctor --verify-approval-trail` walks
   git history + log entries.

## Empirical anchor + residual risks (added 2026-04-30 review)

The UPS forge-resistance argument (only the UPS hook can write
`.sage/.approval-pending`, only real user input fires UPS) is
empirically anchored on Codex 0.126.0-alpha.15 — see
[poc-A1-uncertainties.md](../work/20260429-codex-port-rewrite/review-2026-04-30/poc-A1-uncertainties.md)
(U1 PASS: UPS does not re-fire when Stop hook injects stderr via
exit 2).

**D-class residual risks (retest at every major Codex bump):**
- **D-R1 — Subagent UPS firing.** PoC did not cover sub-agent
  task spawn ("agent dispatches sub-agent with fabricated user
  message"). If a sub-agent path triggers UPS in the parent
  session, the token mechanism becomes forgeable. Watch: when
  Codex adds first-class sub-agent API.
- **D-R2 — Hook `additionalContext` injection.** Docs do not
  guarantee that UPS is bypassed when another hook returns
  `additionalContext`. Watch: any hook contract change in
  `/codex/hooks` referencing `additionalContext`.

Both flagged in `sage doctor` as "Codex version watch" — when
detected version exceeds last-validated, doctor surfaces "retest
PoC A1 before trusting forge-resistance claim".

## Status: proposed
Awaiting user approval at design checkpoint after Batch 3 + spec.md.
