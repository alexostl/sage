---
title: "ADR — `sage doctor` + `sage status` scope"
status: proposed
date: 2026-04-29
codex_min_version: "0.126"
related:
  - .sage/work/20260429-codex-port-rewrite/brief.md (Q8 — doctor command surface)
  - .sage/docs/decision-codex-validate-mutation-predicate.md (ADR-1 — predicate, NOT duplicated by doctor)
  - .sage/docs/decision-codex-approval-proof-schema.md (ADR-2 — migration tooling)
  - .sage/docs/decision-codex-mcp-stack.md (ADR-3 D6 — doctor scope narrowing)
  - .sage/docs/decision-codex-shared-skill-manifest.md (ADR-4 — drift checks)
  - .sage/docs/decision-codex-instruction-surfaces.md (ADR-5 §FM-1..FM-9)
  - .sage/docs/decision-codex-preamble-extraction.md (ADR-6 — char budget)
  - .sage/docs/decision-codex-stop-hook-scope.md (ADR-7 — incident-log consumer)
  - .sage/docs/decision-codex-outcome-harness.md (ADR-8 — harness eligibility check)
---

# ADR — `sage doctor` + `sage status` scope

## Context

`sage status` and `sage doctor` are the two CLI surfaces where the
user sees what Sage actually knows about the project. They sit
ABOVE the MCP layer (callable from `bin/sage`, no MCP dependency
required for doctor — by design from ADR-3 D6) and BELOW the
session layer (no Codex required to run them).

This ADR closes brief Q8 ("`sage doctor` command surface — separate
binary or `sage status --diagnose`? What checks exactly?") and
consumes the failure-mode and check requirements from every prior
ADR. It also resolves four open questions deferred from Batch 2:

- **ADR-5 Q2** — PermissionRequest / PostToolUse stub scripts: NO
  in v1 (`sage doctor` validates absence; their wiring would be a
  v2 PR).
- **ADR-5 Q3** — `developer_instructions` size budget: 700–1000
  chars enforced by `sage doctor --strict` lint.
- **ADR-5 Q4** — tone-lint forbidden-phrase list: locked here as
  the v1 seed (extensible via spec.md, not via this ADR).
- **ADR-5 Q5** — `runtime/platforms/codex/INSTALL.md` framing for
  native escape hatches: documented as a `sage doctor` warning
  surface, not a hard lint.

Plus the v2 deferred verification snapshot from ADR-5 lands here
as `sage doctor --codex-version-changed` (re-runs the empirical
findings cross-check when `codex_min_version` is bumped).

### Why the split (status vs doctor)

These are different jobs with different audiences:

- **`sage status`** — fast read-only snapshot. "What's active
  right now?" Junior-dev runs this 30 times a day. Output is
  one screen, no actionable items, no diagnostic drill-down.
  Latency target ≤ 200ms. Works with or without MCP up.
- **`sage doctor`** — diagnostic with copyable fixes. "Why is
  X broken?" or "Is everything healthy enough to ship v1?".
  Junior-dev runs this when something feels off. Output may be
  multi-screen. Latency target ≤ 5s. Works without MCP for
  environment + reachability checks; degrades gracefully if MCP
  is up but slow.

A single command would conflate fast inspection with slow
diagnosis. The split is for UX, not technical necessity.

## Decision

### D1 — `sage status` scope (fast snapshot)

Output (single screen, ≤30 lines):

```
sage v0.<x> on <platform=codex> @ <repo-relative-path>
profile: fast-trusted        codex: 0.126.x   trust: trusted ✓

Active initiatives:
  ▶ 20260429-codex-port-rewrite — architect/design (Batch 3)
    last update 2 hours ago

Hooks:
  SessionStart  ✓   UserPromptSubmit  ✓   PreToolUse(apply_patch)  ✓
  Stop          ✓   PermissionRequest —   PostToolUse              —

MCP server:           reachable (sage-mcp-server, 4 tools)
.sage/.approval-pending: empty
Last harness run:     2026-04-29 (PASS, 14/14 prompts in dual arm)

3 unacknowledged incidents — run `sage doctor` to inspect
```

**Computed checks (deterministic, all read-only):**

1. Active initiatives — scan `.sage/work/*/manifest.md` for
   frontmatter `status: in-progress | paused`, sort by `updated`.
2. Profile — read `~/.codex/config.toml` (and per-project
   override) for `approval_policy` + sandbox state.
3. Codex version — `codex --version` (cached 60s in
   `.sage/.cache/codex-version`).
4. Trust state — read `~/.codex/config.toml`
   `[projects."<abs>"].trust_level`. If unset → flag as
   `untrusted ⚠` and link to `bin/sage init` for fix.
5. Hooks — read `<repo>/.codex/hooks.json` and check that the four
   v1 hook scripts (`session-init.sh`, `ups-approval.sh`,
   `pre-tool-validate.sh`, `turn-audit.sh`) exist + are
   executable. PermissionRequest / PostToolUse explicitly absent
   — show `—` (em-dash), not red. v1-correct state.
6. MCP reachable — invoke `sage_status` MCP tool with 1s
   timeout. `reachable` / `unreachable (Transport closed)` /
   `unreachable (timeout)`.
7. Approval-pending state — read `.sage/.approval-pending`. If
   present and unexpired → show "1 approval pending — type [A]
   to consume". If expired → show "1 stale token (run sage
   doctor)".
8. Last harness run — read `.sage/work/<active-cycle>/harness-runs/`
   for most recent tarball; show timestamp + verdict from
   embedded summary. If absent and we're in v1 cutover phase
   → flag (D5 hard gate from ADR-8).
9. Incident count — count unacknowledged JSON Lines in
   `.sage/.mcp-incidents.log` since last `sage doctor
   --acknowledge`.

**MCP-down behavior:** show all checks except #6 normally; show
#6 as `unreachable` with one-line copyable fix. Status NEVER
fails (exits 0) — it's an inspection tool, not a gate.

**`sage status --json`** — same data as JSON for harness, scripts,
shell prompts. v1 schema versioned with `schema_version: 1` field.

### D2 — `sage doctor` scope (diagnostic)

Modes:

- `sage doctor` — default, runs all health checks, prints
  human-readable report with copyable fixes.
- `sage doctor --strict` — adds lint + drift checks (slower,
  ~2s extra). Used in CI and pre-cutover verification.
- `sage doctor --json` — machine-readable output for harness
  consumption.
- `sage doctor --acknowledge <audit_run_id>` — mark incidents
  from a given audit run as seen (drops them from `sage status`
  badge).
- `sage doctor --rotate-logs` — rotate `.mcp-incidents.log`,
  `.precommit.log` (consumed by SessionStart hook for session-
  scoped logs per ADR-7).
- `sage doctor --migrate-approval [--dry-run]` — ADR-2
  legacy-artifact migration (already specified in ADR-2; this
  ADR locks the CLI surface).
- `sage doctor --codex-version-changed` — re-run empirical
  findings cross-check (closes the v2-deferred verification
  snapshot from ADR-5).

**Default checks (15 categories):**

#### E1–E5 — Environment

- **E1** Python ≥ 3.10 present.
- **E2** `uv` / `pipx` / `pip` ladder result, plus path to the
  shim at `~/.sage/bin/sage-mcp-server` (per ADR-3 D2).
- **E3** Git version + repo state (clean? on a branch?).
- **E4** Codex version (`codex --version`) — fail if < 0.126.
  Copyable upgrade command in fix message.
- **E5** Disk space: `<disk_free>` on `.sage/` mount. Flags
  if < 100 MiB (logs grow; harness archives accumulate).

#### M1–M3 — MCP layer

- **M1** Sage MCP server installed and shim present.
- **M2** Server reachable (1s timeout). On failure: print the
  actual MCP error (not just "down") + restart instructions.
- **M3** `enabled_tools` config matches v1 surface (4 tools
  per ADR-3 D3). Drift = warn.

#### H1–H3 — Hook layer

- **H1** Four v1 hook scripts exist + executable + start with
  `#!/usr/bin/env bash` (closes FM-4 from ADR-5).
- **H2** `<repo>/.codex/hooks.json` matches the schema in ADR-5
  (no extra hooks wired, no missing v1 hooks).
- **H3** `.codex/config.toml` has `[features].codex_hooks =
  true` and version pin `codex_min_version = "0.126"`.

#### S1–S4 — `.sage/` state

- **S1** Active initiatives have valid frontmatter (parseable
  YAML, required fields present).
- **S2** `decisions.md` is well-formed (anchor format,
  prepend-only invariant — verified by checking that the most
  recent entry is at the top).
- **S3** Approval-proof integrity — for every artifact with
  `status: completed`, frontmatter has `approved_at` AND
  `approved_by`, and `decisions.md` (current + recent archives)
  has the matching anchor. Closes ADR-2 V1 W3 single-writer
  cross-check.
- **S4** Writers-manifest enforcement —
  `runtime/platforms/codex/audit/sage-writers.yaml` exists
  and matches the actual ADR-3 + ADR-7 writer list verbatim
  (drift = warn).

#### `--strict` extras

- **L1** Tone lint on AGENTS.md and `developer_instructions`
  generated content (LR-1..LR-3 from ADR-5):
  - **Forbidden phrases v1 seed** (case-insensitive substring
    match): `"agents should"`, `"agents may"`, `"consider "`,
    `"it is recommended"`, `"please "`, `"if you'd like"`,
    `"feel free to"`, `"try to"`, `"agent will typically"`.
  - One match per file = warn; ≥ 2 matches = error.
  - Closes ADR-5 Q4. Spec.md is the canonical place to extend
    this list (commits in spec.md change the seed; this ADR
    locks today's set).
- **L2** Rules-drift lint between AGENTS.md and
  `developer_instructions` — both must derive from the same
  `runtime/platforms/codex/templates/canonical-rules.yaml`
  (introduced by ADR-5). Doctor reads the YAML and verifies
  both generated artifacts include the canonical rule
  identifiers in their compiled body. Closes FM-9.
- **L3** `developer_instructions` size budget — must fit
  700–1000 characters (closes ADR-5 Q3). Below 500 → warn
  ("compression too aggressive"); above 1000 → error
  ("rule scope drift, see ADR-5 §rules 1-5").
- **L4** AGENTS.md size budget — must fit ≤ 32 KiB
  (`AGENTS_MD_MAX_BYTES`, ADR-5 verified). Above → error.
- **L5** `skills.compiled.json` drift (closes FM-3) — recompile
  in-memory from `core/workflows/*.workflow.md` frontmatter and
  diff against the on-disk compiled file. Drift = error.
- **L6** Preamble char budget (ADR-6) — sum of ≤300-char
  teasers per visible workflow ≤ 16 × 310 = 4960 / 8000
  (38% headroom). Above → warn.
- **L7** Harness eligibility — corpus.yaml parses, evaluator.py
  runs without import errors, results dir is present (or
  empty-but-creatable). Doctor doesn't run the harness; it
  just verifies the harness can be invoked.

#### Incident surfacing

- **I1** Read `.mcp-incidents.log` since last
  `--acknowledge`. Group by `check` type; show count + most
  recent example per type. Severity-ordered (`error` first,
  then `warn`, then `info`).
- **I2** For `dead_validator` (severity `error`) → suggest
  Codex restart explicitly with the timestamp of the death
  event.
- **I3** For `forge_token` / `tier1_self_promotion` /
  `no_verify_commit` (severity `warn`) → link to
  `git diff HEAD~<N>` for the implicated commits/files.

#### Native escape-hatch warnings (ADR-5 Q5)

- **N1** If `~/.codex/AGENTS.override.md` exists, doctor
  prints an INFO note (not warn): "User-global override is a
  native Codex feature; Sage does not manage it. Contents are
  invisible to `sage doctor` lint." This closes Q5: doctor
  acknowledges the surface, doesn't enforce on it.
- **N2** If project-level `.codex/AGENTS.local.md` exists
  (another native Codex escape-hatch), same INFO note.
- **N3** If `<repo>/.codex/config.toml` has fields outside
  Sage's managed block (recognised by `# --- SAGE BEGIN ---`
  / `# --- SAGE END ---` markers), INFO note: "User additions
  detected outside the Sage block; preserved across `sage
  generate`." Closes ADR-5 append-below preservation surface
  for config.toml.

### D2.5 — Platform routing (cross-platform CLI, port-specific checks)

`sage doctor` is a **cross-platform CLI command** in `bin/sage`,
not a Codex-only command. The same applies to `sage status`. The
distinction is:

- **CLI surface** (the command itself) — cross-platform. Junior
  dev runs `bin/sage doctor` regardless of which port the project
  uses.
- **Check set** (what doctor actually inspects) — partly
  cross-platform, partly per-port. This ADR locks the **Codex
  port's check set** because we are inside the Codex port rewrite
  cycle. Other ports' check sets are out of this cycle's scope —
  Claude port and Antigravity port define their own check sets in
  their own work cycles (or have already done so in pre-existing
  `bin/sage` code that this ADR does not touch).

**Platform detection** (deterministic, no flags required):

1. Read project root for port markers:
   - `<repo>/.codex/config.toml` → Codex port active
   - `<repo>/.claude/` directory → Claude port active
   - `<repo>/.antigravity/` directory → Antigravity port active
2. Multiple markers may coexist (a project can use Sage on
   multiple ports). Doctor runs every active port's check set
   plus the cross-platform set; output is grouped by port.
3. No markers → only cross-platform checks run; doctor prints
   "no Sage port surfaces detected — run `sage init` to set
   one up."

**Check-set matrix for the Codex port (this ADR's scope):**

| Check | Scope | Why |
|---|---|---|
| E1 (Python ≥ 3.10) | cross-platform | Sage runtime dep, all ports |
| E2 (uv/pipx/pip ladder) | Codex-only in v1 | Installer ladder is for the MCP server, which is Codex-only per ADR-3 |
| E3 (git version + repo state) | cross-platform | All Sage state is git-tracked |
| E4 (Codex ≥ 0.126) | Codex-only | Codex version pin |
| E5 (disk space on `.sage/`) | cross-platform | Affects all ports |
| M1–M3 (MCP layer) | Codex-only in v1 | Sage MCP is Codex-port-only per ADR-3 / brief C4 |
| H1–H3 (hooks) | Codex-only | `.codex/hooks.json` is Codex-specific surface |
| S1 (active manifest frontmatter) | cross-platform | `.sage/work/` schema is shared |
| S2 (decisions.md well-formed) | cross-platform | `.sage/decisions.md` is shared |
| S3 (approval-proof integrity) | Codex-only in v1 | Requires MCP predicate; Claude/Antigravity have no MCP, use file-existence proof per cross-port survey |
| S4 (writers manifest) | Codex-only | Writers manifest enumerates Codex hook writers |
| L1 (tone lint AGENTS.md + dev-instructions) | Codex-only | dev-instructions is Codex-only; AGENTS.md tone-lint surface is Codex-specific (Claude has different surface) |
| L2 (rules drift between two surfaces) | Codex-only | Two-surface architecture is ADR-5 = Codex-only |
| L3 (dev-instructions size 700–1000) | Codex-only | dev-instructions is Codex-only |
| L4 (AGENTS.md ≤ 32 KiB) | Codex-only | 32 KiB cap is Codex-specific (`AGENTS_MD_MAX_BYTES`); other ports have different limits |
| L5 (`skills.compiled.json` drift) | cross-platform | Compiled manifest is read by all generators per ADR-4 |
| L6 (preamble char budget) | cross-platform | Preamble files are shared per ADR-6 |
| L7 (harness eligibility) | Codex-only | Outcome harness is Codex-only per ADR-8 |
| I1–I3 (incident surfacing) | Codex-only in v1 | `.mcp-incidents.log` is Codex-port-only per ADR-7 |
| N1–N3 (native escape hatches) | Codex-only | `AGENTS.override.md`, `.codex/AGENTS.local.md`, `config.toml` markers are Codex features |

**Cross-platform totals (this ADR delivers):** E1, E3, E5, S1, S2,
L5, L6 — **seven checks** that work on any port. The remaining
13 are Codex-specific.

**Implementation surface:**

```
bin/sage
  doctor.py
    cross_platform/         # E1, E3, E5, S1, S2, L5, L6
    codex/                  # everything in this ADR's matrix tagged Codex-only
    claude/                 # not defined in this cycle
    antigravity/            # not defined in this cycle
```

`bin/sage doctor` enumerates active platforms (per detection
logic above), runs cross-platform checks unconditionally, and
runs each active platform's check set. Output is grouped by
platform with a top-level cross-platform section.

**This ADR does not modify Claude or Antigravity doctor
behavior.** If `bin/sage doctor` already has Claude-specific
checks in the current codebase, they remain. If it doesn't,
adding them is a separate cycle.

### D3 — Verification snapshot (ADR-5 v2 deferred → here)

ADR-5 deferred the empirical-findings re-verification artifact
to v2. This ADR brings it back as a **doctor surface**, since
`sage doctor` is the right home for "is the platform we depend
on still behaving the way we measured?".

`sage doctor --codex-version-changed`:

1. Detect: read `.sage/.cache/codex-verification.json` for
   the version we last verified. Compare against current
   `codex --version`.
2. If versions match → print "verified for current Codex
   version" and exit 0.
3. If versions differ → run the cross-check programmatically:
   - Execute the four PoC C1 tests against the dummy project
     (test fixture lives in
     `runtime/platforms/codex/harness/poc/`, derived from the
     existing `poc-c1-results.md`).
   - Compare results to the expected values from the cycle's
     research base.
   - Write fresh `codex-verification.json` on success; write
     `codex-verification.failed.json` and exit non-zero on
     failure.
4. Output verdict: `VERIFIED` / `DRIFT_DETECTED` /
   `INFRASTRUCTURE_FAILURE`.

**v1 implementation strategy:** the cross-check is a SUBSET of
the harness — it's the four PoC tests, not the full 14-prompt
corpus. Cheap (~10s), runnable without provoking the full
harness. Spec.md will design the test fixture details; this
ADR locks the surface.

### D4 — Output format

**Default (human):**

Section headers grouped by category (Environment, MCP, Hooks,
.sage/ state, Strict, Incidents). Each line is one check with
status icon (✓ / ⚠ / ✗ / —) + one-line description + (for
failures) copyable fix command on the next line indented two
spaces.

**`--json`:**

```json
{
  "schema_version": 1,
  "ts": "2026-04-29T14:23:00Z",
  "checks": [
    {"id": "E1", "category": "environment", "status": "ok"},
    {"id": "E4", "category": "environment", "status": "fail",
     "message": "Codex 0.124 < 0.126 required",
     "fix": "brew upgrade codex"},
    ...
  ],
  "summary": {"ok": 13, "warn": 2, "fail": 1}
}
```

Stable schema across patch versions; bump `schema_version`
on breaking changes.

### D5 — Doctor must work without MCP

Per ADR-3 D6: doctor's primary value when things are broken is
diagnosing **why MCP is down**. So:

- E1–E5 (environment), H1–H3 (hooks), S1–S4 (.sage/ state),
  L4–L6 (size budgets), I1–I3 (incidents), N1–N3 (native
  escape) all run **without** MCP.
- M1–M3 (MCP layer) check reachability; if MCP is down, only
  M2 fails, others (M1 install present, M3 config sanity) still
  pass.
- L1–L3 (tone, drift, size of dev-instructions) require reading
  generated files only, no MCP.
- L7 (harness eligibility) requires harness corpus.yaml parse,
  no MCP.
- Incident surfacing (I1–I3) reads `.mcp-incidents.log`
  directly, no MCP.

The only checks that REQUIRE MCP up are M2 and S3 (S3 because
proof verification calls into the validator's predicate logic,
which lives in MCP per ADR-3 D5 single-source-of-truth). When
MCP is down, S3 prints `degraded — start MCP to verify
approval-proof integrity` instead of failing hard. This is
intentional: a degraded check is honest signal, not a fatal
error.

### D6 — Acknowledgement and incident lifecycle

`sage doctor --acknowledge <audit_run_id>` writes an entry to
`.sage/.mcp-incidents-ack.log`:

```json
{"audit_run_id": "...", "acknowledged_at": "...",
 "acknowledged_by": "alexostl"}
```

Subsequent `sage status` and `sage doctor` runs read this file
and skip incidents whose `audit_run_id` is in the ack log.
Append-only; never deleted (audit trail preserved). Rotated
along with `.mcp-incidents.log` itself.

`sage doctor --acknowledge --all` (no audit_run_id) is rejected
in v1 — too easy to silence real signals. User must explicitly
pick a run.

### D7 — Native escape-hatch posture (closes ADR-5 Q5)

`runtime/platforms/codex/INSTALL.md` documents:

- AGENTS.override.md (user-global, ~/.codex/) is a native Codex
  feature for personal directives. Sage doesn't write to it,
  doesn't lint it, doesn't validate against it. The user can
  put anything there; Sage warns of its existence (N1) so the
  user remembers it might affect agent behavior.
- `.codex/AGENTS.local.md` (project-level, gitignored) — same
  posture (N2). It's a native Codex escape hatch for
  per-machine personal additions.
- `<repo>/.codex/config.toml` USER additions outside the Sage
  block (N3) are preserved by `sage generate` (per ADR-5
  append-below model with `# --- SAGE BEGIN/END ---` markers)
  and surfaced by doctor for visibility.

This is the **honest** stance: Sage manages what Sage owns.
Native escape hatches exist by design in Codex; the user is
free to use them. Doctor's job is to make sure the user
*remembers* they exist.

## Options considered

### Option A — Single command (`sage status --diagnose`) (rejected)

One binary, two modes via flag.

- Pros: one command to remember.
- Cons: conflates fast inspection with slow diagnosis. Latency
  budget mismatch (status 200ms, doctor 5s). Junior-dev UX
  worse — needs to remember which flag does what.
- Brief Q8 leaned toward this; reversed here based on ADR-3 D6
  doctor scope (which is genuinely a different surface).

### Option B — `sage status` + `sage doctor` (chosen, D1+D2)

Two commands, complementary scope. `sage status` for "what's
on" and `sage doctor` for "why is X broken or degraded?".

- Pros: clear UX separation; latency budgets per command;
  doctor can grow checks without inflating status.
- Cons: two commands to remember. Mitigation: `sage status`
  always points at `sage doctor` when there are issues to
  inspect.

### Option C — Doctor as a service (rejected)

Run `sage doctor` continuously as a background daemon with a
status indicator (e.g., menu bar icon).

- Pros: real-time feedback; no "did I forget to run doctor?".
- Cons: significant out-of-scope engineering (daemon, IPC,
  cross-platform UI). Out of v1; possibly out of v2.

### Option D — Doctor as the only command (status absorbed) (rejected)

Drop `sage status`; doctor's default mode IS status.

- Pros: one command.
- Cons: doctor is slow. Junior-dev who runs it 30×/day will
  hate the latency. Status's 200ms target matters.

## Trade-offs

- **Two commands.** The split is for UX, not technical reasons.
  Both share the same backing predicates (in `core/` per ADR-3
  D4). Implementation cost: small (one CLI dispatcher, two
  output formatters).
- **`--strict` only on demand.** Lints L1–L7 are slow (read +
  parse generated files; recompile manifest). Default doctor
  excludes them; CI and pre-cutover verification should pass
  `--strict`. spec.md will document when to use which.
- **Ack flow could hide signals.** If user `--acknowledge`s a
  forge incident without investigating, the warning disappears
  from `sage status`. Mitigation: `--acknowledge --all` is
  rejected (D6); per-run ack forces user to see the run id and
  the count. v2 candidate: doctor warning when ack rate
  exceeds threshold.
- **Verification snapshot adds Codex round-trips.** Running
  PoC tests programmatically requires invoking `codex exec`
  4× per `--codex-version-changed`. ~30s. Acceptable on a
  Codex-version-bump cadence.
- **Forbidden-phrase list is heuristic.** Catches common
  weakening but misses synthesis (e.g., "you might want to
  consider thinking about whether you should perhaps"). v1
  accepts the imperfect signal; v2 may add LLM-as-tone-judge.
- **`sage status` JSON consumers create a coupling surface.**
  Every flag that adds/renames a field is a breaking change
  for shell prompts, harness, scripts. Schema version bump
  is mandatory. spec.md commits to v1 schema only adds fields,
  never removes/renames.

## Failure modes

**FM-9.1 — Doctor runs against MCP that is fully alive but
returns wrong predicate verdicts.** Doctor doesn't catch this
(S3 just verifies proof exists, not that predicate logic is
correct).
- Detection: outcome harness (ADR-8) catches it via
  expected_match.
- Mitigation: layered verification (doctor + harness + manual
  spot-check). Doctor is not the last line of defense.

**FM-9.2 — `sage status` runs while MCP server is starting.**
Race condition: M2 reachability check returns "unreachable"
during startup window.
- Detection: status reports unreachable until startup finishes.
- Mitigation: 1s timeout per check; status output explicitly
  notes "MCP unreachable — may still be starting; re-run in
  10s".

**FM-9.3 — Decisions.md archive search misses an entry** because
the archive was renamed manually.
- Detection: S3 reports "approved_at present but decisions.md
  entry missing" for legacy artifacts.
- Mitigation: doctor prints the expected anchor and offers
  `sage doctor --link-approval <artifact>` for re-linking.

**FM-9.4 — User has multiple Codex versions installed and `codex
--version` returns the wrong one.**
- Detection: E4 reports an unexpected version.
- Mitigation: doctor prints `which codex` output for clarity.

**FM-9.5 — `--codex-version-changed` PoC tests fail because of
infrastructure issue (tmp directory cleanup, network for
Codex auth).**
- Detection: D3 returns INFRASTRUCTURE_FAILURE verdict.
- Mitigation: explicit verdict states (vs. drift); spec.md
  details the test isolation strategy.

**FM-9.6 — Strict-mode lint flags a false positive (legitimate
"agents should" in a quoted example, e.g., AGENTS.md teaching
the user to NOT write that).**
- Detection: lint catches the literal phrase regardless of
  context.
- Mitigation: lint excludes lines starting with `>` (markdown
  blockquote) and lines inside fenced code blocks. Documented
  carve-out for "do not write X" pedagogy.

**FM-9.7 — Doctor itself crashes (Python exception in a
check).**
- Detection: doctor exits non-zero with traceback.
- Mitigation: each check wrapped in `try/except` that emits a
  synthetic `audit_skipped` row for that check; overall
  doctor returns the worst non-skipped verdict. Tests in
  `runtime/platforms/codex/mcp/sage_server/tests/` cover
  forced exceptions per check.

## Consequences

### New artifacts introduced by this ADR

- `bin/sage status` and `bin/sage doctor` subcommands.
- `runtime/platforms/codex/templates/canonical-rules.yaml`
  (referenced by ADR-5 FM-9; locked here as L2's source of
  truth for the rules-drift lint).
- `runtime/platforms/codex/audit/sage-writers.yaml` (introduced
  by ADR-7 C7; verified by S4 here).
- `.sage/.cache/codex-verification.json` (D3 snapshot).
- `.sage/.cache/codex-verification.failed.json` (D3 failure
  artifact).
- `.sage/.mcp-incidents-ack.log` (D6 acknowledgement log).
- `runtime/platforms/codex/harness/poc/` test fixture for D3.
- `runtime/platforms/codex/INSTALL.md` (consolidates D7 native
  escape-hatch documentation).

### Required Batch 3 closeout (final list)

After ADR-9 is approved, Batch 3 closeout amends **three** prior
documents in one pass, mirroring the Batch 2 closeout pattern:

1. **ADR-3 §"Files written outside MCP"** — append the four new
   non-MCP writers introduced by Batches 2 and 3:
   - `.sage/.ups-hook.log` (UPS hook — ADR-7 D4)
   - `.sage/.session-mutations.log` (`pre-tool-validate.sh` —
     ADR-7 C7)
   - `.sage/.precommit.log` (L5 pre-commit hook — ADR-7 C5)
   - `.sage/.mcp-incidents-ack.log` (`sage doctor` —
     ADR-9 D6)
2. **L5 pre-commit hook spec amendment** — record verdict line
   per invocation to `.sage/.precommit.log` (ADR-7 C5
   prerequisite).
3. **`runtime/platforms/codex/INSTALL.md` framing** — native
   escape-hatch posture per D7 (closes ADR-5 Q5).

### Backward consequences

- **ADR-3 D6 (sage doctor narrowing)**: this ADR honors that
  scope. Doctor does NOT duplicate predicate logic; it reads
  results of predicates run by MCP (via S3) and adds
  environment/lint checks that are MCP-independent.
- **ADR-5 §FM-1..FM-9**: every failure mode has a doctor check.
  FM-1 → L4 (size budget). FM-2 → E4 (version pin). FM-3 → L5
  (drift). FM-4 → H1 (executable + shebang). FM-5 →
  informational (UPS false positives are accepted; surfaced
  via I1 incident count). FM-6 → M2 (reachability). FM-7 → I3
  (forge incident link). FM-8 → L1 (tone lint). FM-9 → L2
  (rules drift).
- **ADR-7 incidents**: I1–I3 surface the seven check types.
  Severity-grouped, copyable git-diff links per type.
- **ADR-8 harness**: L7 (harness eligibility) is a doctor
  preflight. Doctor doesn't run harness; harness `bin/sage
  harness` is its own subcommand.
- **ADR-2 migration tooling**: `--migrate-approval` is the
  ADR-2-specified migration; this ADR locks the doctor flag
  surface.

### Out of v1 scope (deferred)

- LLM-based tone judge (forbidden-phrase list is the v1 floor).
- Continuous doctor daemon (Option C).
- Designing Claude / Antigravity port-specific check sets
  (those belong to their respective port cycles, not this one).
  This ADR delivers seven cross-platform checks (D2.5) plus the
  full Codex port check set; per-platform check sets for other
  ports are out of scope.
- `sage doctor --acknowledge --all` (intentionally not
  supported).
- Auto-fix flag (`sage doctor --fix`) — v1 prints copyable
  fix commands, user runs them. Auto-fix is risky enough to
  warrant explicit v2 design.

## What happens when this fails

1. **Doctor returns warnings indefinitely** (user ignores) →
   `sage status` keeps showing the badge ("3 unacknowledged
   incidents — run `sage doctor`"). No automatic escalation
   in v1; v2 may surface in shell prompt or commit hook.
2. **Doctor reports DRIFT_DETECTED on `--codex-version-changed`**
   → block v1 cutover (architecture verification failed).
   Spec.md must document remediation: investigate the diff,
   adjust predicates if Codex changed semantics, re-run.
3. **L1 forbidden-phrase lint catches a legitimate example**
   (FM-9.6) → fix the lint excludes (blockquote, fenced
   code) or amend the v1 seed list to be more specific.
4. **Doctor's M2 reports unreachable but MCP is actually
   reachable** (transient timeout) → re-run resolves; if
   persistent, doctor's diagnosis is then correct (something
   IS broken; user investigates).
5. **`sage status --json` consumer breaks because of schema
   change** → bump `schema_version`, document migration in
   spec.md, ship.

## Status: proposed
Awaiting user approval at design checkpoint after Batch 3 + spec.md.
