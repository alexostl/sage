---
title: "ADR — Codex Stop hook scope (turn audit logic)"
status: proposed
date: 2026-04-29
codex_min_version: "0.126"
related:
  - .sage/work/20260429-codex-port-rewrite/brief.md (Q6, C5)
  - .sage/docs/decision-codex-instruction-surfaces.md (ADR-5 §Stop — surface contract)
  - .sage/docs/decision-codex-mcp-stack.md (ADR-3 D6 — incident log path; D3 — sage_audit_turn tool)
  - .sage/docs/decision-codex-validate-mutation-predicate.md (ADR-1 — Tier-1, --no-verify mitigations)
  - .sage/docs/decision-codex-approval-proof-schema.md (ADR-2 — approval token + forge framing)
  - .sage/docs/research-codex-port-rewrite-base.md (§4.5 — Stop hook semantics)
---

# ADR — Stop hook scope (turn audit logic)

## Context

ADR-5 (§`Stop`) locks the **surface contract** for the Stop hook:

- Script: `runtime/platforms/codex/hooks/turn-audit.sh`
- Fires: end of every turn (Stop has no matcher per research base §4.5)
- Shim → `sage_audit_turn` MCP tool call
- Findings written to `.sage/.mcp-incidents.log`
- v1: **NEVER** blocks continuation (`"continue": true` always)

ADR-5 deliberately defers the **audit logic** here. This ADR locks
what `sage_audit_turn` actually inspects, what it writes, and what
it intentionally does NOT do in v1.

This ADR also closes brief open question **Q6** ("Stop hook v1
scope — warn-only on missed gates, or attempt automatic recovery?")
with the answer: **warn-only**. Recovery requires writing artifacts
on the user's behalf (scaffold missing spec.md, etc.), which
contradicts ADR-1's gate semantics — agent cannot self-issue an
approval, so the scaffold would be unapproved by construction.

### What the Stop hook is for (and what it is not)

The Stop hook is the **audit trail closer**, not a second
enforcement gate. The mutation gate is `PreToolUse` (ADR-1); by the
time `Stop` fires, every mutation has already happened. The hook's
job is:

1. Record what happened in the turn for later inspection (`sage
   doctor`, `bin/sage status`, the outcome harness).
2. Detect patterns that the pre-mutation gate cannot see (stale
   approval tokens, forge attempts, `--no-verify` commits, Tier-1
   self-promotion without `decisions.md` entry, writes to `.sage/`
   bypassing the validator).
3. Surface dead-validator state to the user via `sage doctor` (per
   ADR-3 D6 — Stop hook is the second writer to
   `.mcp-incidents.log` after `pre-tool-validate.sh`).

It is NOT for: rolling back changes, scaffolding artifacts,
self-issuing approvals, or hard-blocking the next turn.

## Decision

### D1 — `sage_audit_turn` MCP tool I/O schema

**Input** (from Stop hook payload, Codex 0.126 contract):

```json
{
  "session_id": "<codex session uuid>",
  "transcript_path": "<absolute path to session transcript>",
  "cwd": "<repo root>",
  "stop_hook_active": true | false
}
```

`stop_hook_active = true` indicates this Stop hook fired in
response to a previous Stop hook returning `"continue": false` (per
research base §4.5). v1 never sets `continue: false`, so v1 should
always observe `stop_hook_active = false`. If the tool sees `true`,
it logs an incident — that means a v1+ build sneaked a hard-block
in unintentionally.

**Output** (back to Stop hook):

```json
{
  "continue": true,
  "incidents": [
    {"check": "stale_token", "severity": "warn", "summary": "..."},
    ...
  ],
  "audit_summary": "<one-line human summary, optional>"
}
```

The hook script translates `incidents` into `.sage/.mcp-incidents.log`
appends and exits 0. **v1: `continue` is unconditionally `true`**
in the tool's output. The field is reserved for v2 (when severity
of certain incidents may upgrade to hard-block).

### D2 — Seven audit checks (v1)

The tool runs all seven checks in order, accumulating
incidents. Each check is independent — one failure does not
short-circuit the rest. Checks are append-only by construction (no
mutation to project state from inside the audit).

#### C1 — Stale UPS-token

Detection:
1. Read `.sage/.approval-pending` (if absent → skip C1).
2. Compare `expires_at` (from token JSON) against current time.
3. If `expires_at < now` → token expired and was not consumed.

Action:
- Append incident `{"check": "stale_token", "severity": "info",
  "issued_at": "...", "expired_at": "..."}` to log.
- The MCP tool **deletes the expired token** (consumes the cleanup
  responsibility — `sage_record_approval` already deletes consumed
  tokens, and the UPS hook does not delete on expiry alone).

Why this matters: the user typed `[A]` / `approve` but the agent
either crashed or skipped calling `sage_record_approval`. The
incident gives the user (and outcome harness) a signal that the
recovery loop is leaking.

Severity is `info`, not `warn`, because expiry is the **success
path of the timeout** — the token is supposed to expire if not
used. The signal is "agent didn't use it within 5 minutes," which
is interesting but not necessarily wrong.

#### C2 — Forge detection on `.approval-pending`

Detection:
1. Read `.sage/.approval-pending` (if absent → skip C2).
2. Read `.sage/.ups-hook.log` (defined in D4 below). Find any
   entry where `token_issued: true` AND
   `abs(entry.ts - approval_pending.mtime) ≤ 2 seconds`.
3. If no such entry → token exists but UPS hook never issued it.
   This is a forge attempt: some other process wrote the token
   file directly.

Action:
- Append incident `{"check": "forge_token", "severity": "warn",
  "approval_pending_mtime": "...", "no_matching_ups_hook_entry":
  true}`.
- **Do NOT delete the token.** Forensic preservation. The next
  `sage_record_approval` call will still validate it normally
  (token-existence is the gate, not provenance — per ADR-2 honest
  framing); the audit trail records the suspicion separately.

Why mtime ±2s: clock skew between the kernel (mtime) and the
hook script's wallclock (`ups-hook.log` entry) is typically
sub-millisecond, but we allow 2s for safety on slow systems and
NTP jitter. The window is narrow enough that an agent attempting
forge would have to also schedule a UPS hook firing within 2s,
which the agent cannot do (UPS only fires on real user input).

#### C3 — Pending-gate-not-addressed

Detection:
1. Read latest active manifest (`.sage/work/*/manifest.md` with
   `status: in-progress` or `paused`).
2. Read manifest frontmatter for `phase` field, e.g.,
   `phase: design-checkpoint-pending`.
3. If `phase` ends in `-pending` → a checkpoint was offered to the
   user but the turn ended without `[A]/[R]/[N]` recorded.

Action:
- Append incident `{"check": "pending_gate", "severity": "info",
  "manifest": "...", "phase": "..."}`.

Why this matters: agent presented a Zone 2 footer and turn ended
with no answer. Maybe the user is taking time to think — fine. But
if the next user message resumes the work without addressing the
gate, that's a process leak. Outcome harness uses this signal.

Severity is `info` (not `warn`) because the pause is often
legitimate. Repeated `info` for the same `(manifest, phase)` pair
across turns becomes interesting; v2 may upgrade.

#### C4 — Tier-1 self-promotion

Detection:
1. Read latest active manifest. Note current `tier` field value
   and `updated:` timestamp.
2. If `tier == 1`: search `.sage/decisions.md` (and most recent
   archive if rotated within the last 7 days) for an entry between
   the previous turn's audit timestamp (read from
   `.mcp-incidents.log`) and now that explicitly mentions both:
   - The cycle directory path verbatim, AND
   - The literal string `tier: 1` or `Tier 1` or `Tier-1`.
3. If `tier == 1` AND no such `decisions.md` entry exists → agent
   set Tier-1 without recording the user-approved rationale.

Action:
- Append incident `{"check": "tier1_self_promotion", "severity":
  "warn", "manifest": "...", "tier": 1, "no_decisions_entry":
  true}`.

Why this matters: ADR-1 P3 second row allows Tier-1 to bypass
spec/plan checks. The validator cannot determine if `tier: 1`
came from user consent or agent self-promotion. The Stop hook is
the only place the cross-check (manifest mutation vs decisions.md
entry) can happen, because both files are visible by then.

#### C5 — `--no-verify` commit detection

Detection:
1. Read git reflog entries since the previous Stop hook fire (use
   the `last_audit_at` field stored in `.mcp-incidents.log` — or
   session start if first audit of the session).
2. For each commit in the range, read the commit message and the
   git config setting that captured it. Specifically: check git's
   `core.hooksPath` was honored — Sage cannot directly observe
   `--no-verify` was passed (git does not record it), so the
   detection is **indirect**:
   - For each commit since `last_audit_at`, run
     `git log --format='%H %s' <range>` and check for the literal
     pattern `[no-verify]` in the message (Sage's pre-commit
     hook, when run normally, does not produce this marker; its
     absence proves nothing). The real detection is:
   - For each commit, check whether the `pre-commit` hook
     produced an entry in `.sage/.precommit.log` (pre-commit hook
     appends one line per invocation with `{commit_hash, ts,
     verdict}`). If a commit exists in git log but has no
     matching `.precommit.log` entry → `pre-commit` was not run,
     i.e., `--no-verify` (or hook removal).

Action:
- Append incident `{"check": "no_verify_commit", "severity":
  "warn", "commit": "<hash>", "subject": "..."}`.

Why this matters: ADR-1 trade-offs note that L5 pre-commit is
bypassable by `git commit --no-verify`, with detection deferred to
the Stop-hook audit. This is that detection.

**v2 caveat:** the indirect detection has false positives — if
`.sage/.precommit.log` is missing or wiped, all commits look
unverified. v2 will record a per-commit signature in the
pre-commit hook (HMAC over commit hash + Sage version) and verify
in the audit. v1 accepts the false-positive rate as a discovery
signal.

This check requires the **L5 pre-commit hook** to write
`.sage/.precommit.log`. That is a small additional spec for the
existing L5 hook (one new responsibility); flagged in
**Consequences** below as a Batch 3 amendment to L5.

#### C6 — Dead-validator detection

Detection:
1. The Stop hook script invokes `sage_audit_turn`.
2. If the MCP call returns `Transport closed` (or any transport
   error), the hook script catches it.

Action:
- Hook script writes the incident **directly** to
  `.sage/.mcp-incidents.log` with no MCP dependency:
  `{"check": "dead_validator", "severity": "error", "session_id":
   "...", "error": "Transport closed", "ts": "..."}`.
- Hook still exits 0. Codex Stop semantics (per /codex/hooks):
  exit 0 = let turn end normally; exit 2 = stderr injected as
  continuation prompt (NOT a benign print — agent sees stderr
  as if user said it); JSON `{"continue": false}` = stop turn;
  JSON `{"decision": "block"}` = counter-intuitively means
  "continue turn". v1 dead-validator path uses exit 0 — incident
  is logged for `sage doctor`, no agent-facing surface.
- `sage doctor` reads this incident on next run and surfaces
  recovery instructions per ADR-3 D6.

This is the same writer path that `pre-tool-validate.sh` uses for
its mid-session MCP failure (per ADR-3 amended writers list). The
two scripts share the line format; `sage doctor` parses both
uniformly.

#### C7 — Bypass-write detection on `.sage/`

Detection:
1. Run `git diff --name-only <last_audit_commit>..HEAD -- .sage/`
   to enumerate `.sage/` files mutated since previous audit.
2. Cross-reference the list against ADR-3's authorised-writers
   manifest (defined as a YAML in
   `runtime/platforms/codex/audit/sage-writers.yaml`):
   - `.sage/.approval-pending` ← UPS hook only
   - `.sage/.mcp-incidents.log` ← Stop hook + pre-tool-validate.sh
   - `.sage/.ups-hook.log` ← UPS hook only (D4 below)
   - `.sage/.precommit.log` ← L5 pre-commit hook only
   - `.sage/decisions.md` ← `sage_record_approval` MCP tool only
   - `.sage/work/**` ← MCP tools or workflow scripts
   - `.sage/docs/**` ← agent allowed (P2.2 — Sage internal)
3. Any file mutated outside its declared writer's path → suspect.
   "Suspect" not "forge": the agent legitimately edits `.sage/docs/`
   via `apply_patch` (P2.2). The check focuses on the **append-only
   logs and tokens** (the first four entries above). Any mutation
   to those by `apply_patch` is suspicious.

Detection mechanism: every `apply_patch` invocation goes through
`PreToolUse` → `pre-tool-validate.sh`. That hook records the patch
target paths in `.sage/.mcp-incidents.log` only on deny. For
**accepted** patches, we add a parallel session log:
`.sage/.session-mutations.log`, append-only, written by
`pre-tool-validate.sh` after `sage_validate_mutation` returns
allow. Each line: `{commit_hash_pending, files: [...], ts}`. The
Stop hook compares this list against actual `.sage/` git diff.

Action:
- For each `.sage/` file mutated outside its declared writer:
  - If the file is in the append-only list (token, hook log,
    incident log, precommit log, decisions.md): incident
    `{"check": "bypass_write", "severity": "warn", "path": "...",
    "writer_expected": "...", "writer_actual": "apply_patch"}`.
  - Otherwise (regular Sage file like `.sage/work/.../spec.md`):
    no incident — that is normal agent work.

This catches the forge-via-apply_patch path that ADR-2 §"Why this
works" describes. Detection here closes the loop on the honest
framing claim (detectable, not preventable).

This check is **the most expensive** of the seven (one git diff
per audit). Acceptable: Stop hook fires once per turn, not per
tool call.

### D3 — Incident log format

`.sage/.mcp-incidents.log` is **JSON Lines** (one JSON object per
line, no enclosing array). Append-only. Schema:

```json
{
  "ts": "2026-04-29T14:23:15Z",
  "session_id": "abc-123-...",
  "turn_id": 42,
  "audit_run_id": "<uuid>",
  "check": "stale_token | forge_token | pending_gate | tier1_self_promotion | no_verify_commit | dead_validator | bypass_write",
  "severity": "info | warn | error",
  "details": { ... check-specific fields ... }
}
```

Plus a **separator line** at audit start:

```json
{"ts": "...", "session_id": "...", "turn_id": 42, "audit_run_id": "...", "check": "audit_start", "severity": "info"}
```

And an **end-marker line** at audit end (so doctor can detect
truncated audits):

```json
{"ts": "...", "audit_run_id": "...", "check": "audit_end", "severity": "info", "incident_count": 3}
```

The end-marker also stores `last_audit_at` semantics implicitly —
`sage_audit_turn` reads back the most recent `audit_end` to find
the previous audit's timestamp for C5 (`--no-verify`) and C7
(`bypass_write`) range queries.

### D4 — UPS hook log (new artifact)

`.sage/.ups-hook.log` is introduced by **this ADR** to enable C2
(forge detection on `.approval-pending`).

JSON Lines, append-only, written exclusively by
`runtime/platforms/codex/hooks/ups-approval.sh`. Schema:

```json
{
  "ts": "2026-04-29T14:23:00Z",
  "session_id": "abc-123-...",
  "prompt_hash": "sha256:abcd...",
  "matched_vocabulary": ["[A]"] | ["approve"] | [],
  "token_issued": true | false,
  "token_expires_at": "..." | null
}
```

`prompt_hash` is SHA-256 of the prompt text. Privacy: the literal
prompt is not logged, only its hash. The hash is for outcome
harness replay (compare hashes to identify which prompts triggered
matches).

`matched_vocabulary` is an array because future prompt may
contain multiple matches; v1 issues at most one token per UPS
firing regardless.

### D4-bis — Codex Stop hook output semantics (callout)

Codex's Stop hook output vocabulary is **counter-intuitive**.
Locked here for all ADRs that touch Stop:

| Output | Meaning |
|---|---|
| exit 0 | turn ends normally |
| exit 2 | stderr injected back into agent as next-turn prompt |
| JSON `{"continue": false}` | stop the turn |
| JSON `{"decision": "block"}` | **continue** the turn (NOT block) |

v1 invariant (D5 below) uses **only exit 0**. The token-block
patterns (`continue: false`, `decision: "block"`) are documented
here for ADR completeness; they are not used in v1.

### D5 — v1 invariant: NEVER hard-block

`sage_audit_turn` always returns `continue: true`. The hook script
always exits 0 (or, on transport error caught by C6, still 0).
There is **no v1 code path** where the Stop hook causes Codex to
refuse the next turn.

Rationale (closes brief Q6):
- Audit fires after the fact. By the time it can decide to block,
  every mutation has happened. Blocking the next turn does not
  undo what the current turn produced.
- Auto-recovery (scaffolding missing artifacts) requires the audit
  to write project state, which contradicts ADR-1 gate semantics
  (no agent-issued approvals, no MCP-issued artifacts without a
  workflow script driving the user).
- Hard-blocking on critical incidents (forge, --no-verify) is a
  v2 candidate **only after the outcome harness shows that
  warn-only leaks the failure mode in measurable cases**. v1
  collects data; v2 acts on it.

The v1 contract for the user is: **incidents are visible in `sage
doctor` and `bin/sage status`. The user decides whether to act.**

## Options considered

### Option A — Warn-only, structured log (chosen)

Audit runs every turn, logs incidents, never blocks. Severity is
informational; user reviews via `sage doctor`.

- Pros: zero risk of false-positive denial of service. All audit
  data preserved for outcome harness analysis. Implementation is
  straightforward (read-only checks + append-only writes).
- Cons: relies on user attention; an ignored incident log
  accumulates noise.

### Option B — Hard-block on critical incidents

Audit returns `continue: false` for `forge_token` or
`bypass_write` of severity `warn`+.

- Pros: stronger enforcement; agent cannot ignore.
- Cons: false positives on indirect detections (especially C5
  `--no-verify` and C7 `bypass_write` if writers list drifts) become
  user-visible session breaks. v1 data is insufficient to tune
  thresholds. **High risk of breaking sessions for the user during
  the discovery period.**

### Option C — Auto-recovery (scaffold artifacts)

Audit detects "build workflow active, plan.md missing", scaffolds
an empty plan.md, and lets next turn proceed.

- Pros: fixes the leak it observed.
- Cons: violates ADR-1 P4 (artifact written without approval
  proof). Creates a phantom artifact that the next turn's gate
  treats as in-progress. Worse than the disease — masks the
  process error instead of surfacing it.
- **Rejected at design**, not deferred. This is incompatible with
  ADR-1's invariant that agent-written artifacts cannot bypass
  approval.

### Option D — Hybrid: warn-only + on-demand recovery via `bin/sage`

Audit is warn-only. User runs `bin/sage repair --cycle <id>` if
they want to re-scaffold a missing artifact (with explicit user
consent at CLI).

- Pros: combines safety of A with recovery utility.
- Cons: defers the recovery surface to ADR-9 / `bin/sage` scope.
  Not v1 critical-path.
- **Acceptable as v2** via ADR-9 expansion. Out of v1 audit scope
  but listed in Consequences as a follow-up.

## Trade-offs

- **Detection vs. prevention.** All seven checks are detection.
  They cannot rewind a turn. The Stop hook's value is the audit
  trail, not real-time blocking. This is V3 honest framing
  consistent with the brief: defense-in-depth, not crypto-grade
  enforcement.
- **Cost of C7 (bypass-write).** One `git diff` per audit. On a
  large repo with many `.sage/` files, this is ~50–200ms.
  Acceptable because Stop fires once per turn, not per tool call.
  If the cost ever matters, scope C7 to a hard-coded list of
  append-only targets (current implementation strategy) rather
  than full `.sage/` enumeration.
- **C5 false positives.** If `.sage/.precommit.log` is wiped or
  the L5 hook isn't installed, every commit looks `--no-verify`.
  ADR-9 (`sage doctor`) will surface "L5 hook missing" prominently
  so the user knows the audit is operating with a degraded
  signal.
- **`.ups-hook.log` and `.session-mutations.log` and `.precommit.log`
  growth.** All append-only. Rotation policy: per-session-start, the
  SessionStart hook truncates `.ups-hook.log` and
  `.session-mutations.log` (they are session-scoped, not project
  history). `.mcp-incidents.log` rotates at 1000 lines into
  `.sage/.mcp-incidents-{YYYY-MM-DD}.log`. `.precommit.log` rotates
  monthly. Rotation logic lives in `sage doctor --rotate-logs`,
  invoked by the SessionStart hook for the session-scoped logs.
- **Privacy of `.ups-hook.log`.** Stores only prompt hashes. If a
  user is concerned about correlation attacks (someone with the
  log + a candidate prompt can confirm the prompt was typed),
  they can opt out via a project setting (deferred to v2 — not on
  v1 critical path). v1 default: hashes recorded.
- **Audit determinism.** All seven checks are pure functions of
  filesystem state at audit time. Two audits at the same instant
  with the same state produce the same incident list. This is
  required for the outcome harness (ADR-8) to compare
  control/treatment runs reproducibly.
- **Audit latency budget.** Stop hook target: ≤500ms total
  (audit + log append). Of which: C1 ~5ms, C2 ~10ms, C3 ~10ms,
  C4 ~20ms, C5 ~30ms (git log range), C6 instant on success or
  ~2s on transport timeout (Codex MCP timeout), C7 ~50–200ms
  (git diff). Total budget allows for slow disk + NTP jitter.

## Failure modes

**FM-7.1 — `sage_audit_turn` raises an unhandled exception.**
- Detection: hook script catches and writes a synthetic
  `dead_validator` incident with `error: "<exception message>"`.
- Impact: turn audit silently no-ops for that turn.
- Mitigation: Python server-side `try/except` around the entire
  audit; tests in `runtime/platforms/codex/mcp/sage_server/tests/`
  inject panics in each check.

**FM-7.2 — `.sage/.ups-hook.log` corrupted (partial write,
non-JSON line).**
- Detection: C2 finds no matching entry → reports forge incident
  spuriously.
- Impact: false-positive `forge_token` warnings.
- Mitigation: UPS hook writes via `mktemp + cat >> + mv` for atomic
  append (POSIX guarantees atomic appends only for writes ≤ PIPE_BUF;
  4KiB JSON lines are safely under). `sage doctor --strict` validates
  log JSON well-formedness on every run.

**FM-7.3 — `.sage/.session-mutations.log` missing when audit
runs.**
- Detection: C7 has no baseline to compare → audit logs
  `bypass_write_uncheckable` incident instead of false-positives.
- Impact: C7 reports "audit degraded" rather than spurious forge
  warnings.
- Mitigation: SessionStart hook ensures the file exists (touch +
  truncate); `pre-tool-validate.sh` recovers by re-creating if
  deleted mid-session.

**FM-7.4 — Manifest frontmatter malformed (C3, C4).**
- Detection: YAML parse fails.
- Impact: those checks skip with `audit_skipped` incident.
- Mitigation: `sage doctor --migrate-frontmatter` normalizes
  legacy manifests (already needed for ADR-2 P4); audit treats
  malformed as opaque.

**FM-7.5 — Clock skew between hook script and MCP server.**
- Detection: C2 ±2s window may falsely include or exclude UPS
  entries.
- Impact: rare; both processes are on the same host (no network).
- Mitigation: ±2s window is generous; user with clock issues
  sees more `forge_token` false positives, surfaced via `sage
  doctor`.

**FM-7.6 — User runs `sage doctor --rotate-logs` mid-audit.**
- Detection: rotation moves `.mcp-incidents.log` to a dated
  archive while audit is appending.
- Impact: incident may land in the rotated archive or a
  mid-rotation null state.
- Mitigation: rotation acquires file lock (`flock(2)`); audit
  acquires same lock for write. v1 documents this as known race
  with low probability; v2 trigger condition: any user reports
  data loss.

**FM-7.7 — `git log` fails (corrupt repo, missing HEAD).**
- Detection: C5 / C7 git invocations return non-zero.
- Impact: those checks log `audit_degraded` and skip.
- Mitigation: defensive subprocess; failure is non-fatal to the
  rest of audit.

## Consequences

### New artifacts introduced by this ADR

- **`.sage/.ups-hook.log`** — JSON Lines, written by UPS hook only.
  D4 above defines schema. **ADR-3 amendment required**: add to
  authorised-writers list ("`UserPromptSubmit` hook only").
- **`.sage/.session-mutations.log`** — JSON Lines, written by
  `pre-tool-validate.sh` only. **ADR-3 amendment required**.
- **`.sage/.precommit.log`** — JSON Lines, written by L5
  pre-commit hook only. **L5 hook spec amendment required**:
  add one line per invocation `{commit_hash, ts, verdict}`.
- **`runtime/platforms/codex/audit/sage-writers.yaml`** —
  declarative writer manifest. Single source of truth for C7
  bypass-write detection. Tested by unit test ensuring it stays
  in sync with ADR-3's writer list.

### Required follow-up actions in Batch 3 / spec.md

1. **ADR-3 §"Files written outside MCP" amendment** — add
   `.sage/.ups-hook.log`, `.sage/.session-mutations.log`,
   `.sage/.precommit.log` to the writers list. **CLOSED in
   Batch 3 closeout 2026-04-30** (ADR-3 §"Files written outside
   MCP" updated to include the four new writers + reference to
   `sage-writers.yaml`).
2. **L5 pre-commit hook line schema (locked here in Batch 3
   closeout 2026-04-30):**

   Each L5 invocation appends one JSON Lines entry to
   `.sage/.precommit.log`:

   ```json
   {
     "ts": "2026-04-30T09:42:11Z",
     "commit_hash_pending": "<sha resolved post-commit, null pre-commit>",
     "verdict": "pass | fail | skipped",
     "checks_run": ["lint", "test", "format", ...],
     "duration_ms": 1234,
     "sage_version": "0.<x>"
   }
   ```

   - `ts` — ISO 8601 UTC, written at hook start.
   - `commit_hash_pending` — at the moment L5 runs, the commit
     hash is not yet known. Field is `null` initially; a separate
     post-commit hook (added by Batch 3 implementation) writes a
     paired entry resolving the hash. The Stop-hook audit C5
     joins these two entries by timestamp proximity (±2s, same
     mtime semantics as C2).
   - `verdict` — `pass` if all checks succeeded, `fail` if any
     check failed (and the commit was blocked), `skipped` if the
     hook ran but produced no checks (e.g., empty repo state).
   - `checks_run` — array of check identifiers; freeform but
     stable per Sage version.
   - `sage_version` — written by hook to detect schema-bump
     compatibility.

   **Migration:** existing L5 hook in
   `core/gates/scripts/pre-commit-l5.sh` (or current path) gains
   a small `cat >> .sage/.precommit.log` section per check
   block. Atomic via `mktemp + cat + mv` (same pattern as
   `.ups-hook.log`).

   **Outcome harness assertion (ADR-8 D4):** the harness
   evaluator asserts that every commit produced by the harness
   run has a matching `.precommit.log` entry. Mismatch =
   `no_verify_commit` incident is correctly logged by C5.
3. **`sage_audit_turn` MCP tool implementation** lives in
   `runtime/platforms/codex/mcp/sage_server/tools/audit_turn.py`
   per ADR-3 D4 layout. Seven check functions in
   `core/audit_checks.py`.
4. **SessionStart hook** must touch+truncate `.ups-hook.log` and
   `.session-mutations.log` at session start (they are
   session-scoped, not project history). `.mcp-incidents.log` and
   `.precommit.log` are project history, not truncated.
5. **`sage doctor`** consumes `.mcp-incidents.log` and presents
   a rolled-up view (ADR-9). Doctor must handle the seven
   `check` types declaratively from this ADR's enumeration.
6. **Outcome harness** (ADR-8) treats incidents as evaluation
   signals: forge attempts in the harness corpus must produce
   `forge_token` incidents; missed gates must produce
   `pending_gate` incidents. The harness pass criteria includes
   "audit detected the planted leak."

### Backward consequences for ADR-5 §`Stop`

This ADR locks the audit semantics that ADR-5 §`Stop` step 2 left
to "ADR-7 will detail." No revision to ADR-5 needed; the surface
contract there remains accurate (shim → MCP → log).

### Out of v1 scope (deferred to v2 / future)

- Hard-block on critical incidents (Option B).
- Auto-recovery via `bin/sage repair` (Option D).
- Per-commit signature in L5 hook (closes C5 false-positive).
- Forge-prevention via `chattr +a` or Linux append-only inode
  flags (platform-specific, not portable to macOS).
- Multi-session concurrent audit (single-writer assumption from
  ADR-2 §Trade-offs applies here too).

## What happens when this fails

1. **Audit detects forge_token, user ignores log** → next turn
   proceeds; `sage doctor` keeps surfacing the incident until
   user clears it via `sage doctor --acknowledge <audit_run_id>`.
   No automatic escalation in v1.
2. **Audit times out (e.g., MCP slow)** → hook script kills
   subprocess after 5s, writes `dead_validator` incident, exits
   0. Next turn proceeds normally.
3. **All seven checks raise** → hook still exits 0. Synthetic
   incident `audit_total_failure` is logged; outcome harness
   pass criteria includes "audit failure does not break the
   session."
4. **`.mcp-incidents.log` reaches disk-full state** → append
   fails silently; hook exits 0. `sage doctor` surfaces
   "incidents log unwritable, check disk". v1 does not block on
   this.

## Status: proposed
Awaiting user approval at design checkpoint after Batch 3 + spec.md.
