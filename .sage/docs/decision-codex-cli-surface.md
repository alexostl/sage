---
title: "ADR — Codex `bin/sage` CLI surface"
status: proposed
date: 2026-04-30
codex_min_version: "0.126"
related:
  - .sage/work/20260429-codex-port-rewrite/spec.md (§7.1, §7.3 — bin/sage status; §13.2 outcome harness)
  - .sage/docs/decision-codex-doctor-and-status.md (ADR-8 — sage doctor scope)
  - .sage/docs/decision-codex-mcp-stack.md (ADR-3 — MCP deferred; reason for bash impl)
---

# ADR — `bin/sage` CLI surface

## Context

Sage ships a `bin/sage` CLI for project-level operations (`init`,
`update`, `status`, `doctor`). Codex port v1 needs a clear answer
to: which subcommands exist in v1, where is their state read from,
and which (if any) call out to MCP tools.

This is a sibling ADR to ADR-8 (`sage doctor` scope). ADR-8 covers
diagnostics + the auto-fix posture; this ADR covers the rest of
the CLI surface — specifically `bin/sage status` and the broader
"how does the CLI talk to project state" question.

## Cross-port truth

Claude port `bin/sage status` reads `.sage/work/*/manifest.md` and
`spec.md`/`plan.md` frontmatter directly from disk via shell tools
(grep/yq). No MCP, no helper service. Idempotent, fast, deps-light.

Antigravity + Generic ports have no `bin/sage status` equivalent —
state inspection happens through native Antigravity UI / generic
Markdown reading.

## Decision

`bin/sage status` (v1) reads project state **directly from disk**:

1. Iterate `<target>/.sage/work/*/` directories.
2. For each, parse YAML frontmatter from `manifest.md` (preferred)
   or fall back to `spec.md` / `plan.md` (legacy artifacts).
3. Aggregate `status:` and `phase:` into a JSON or human-readable
   summary (configurable via `--format json|text`, default text).
4. Emit to stdout. Exit 0 on success, exit 1 on parse error in any
   frontmatter file (with explicit "which file failed" message).

Implementation: bash + `yq eval` (minimum yq 4.x). No Python, no
MCP, no helper daemon.

**Why not an MCP `sage_status` tool:** the original ADR-3 (now
deferred — see ADR-3 v1 amendment) listed `sage_status` as one of
five planned MCP tools. Cut B (2026-04-30) deferred all of MCP
from v1; the bash equivalent is fully sufficient for the v1 use
case (read-only state inspection from current worktree). The MCP
flavor would only matter for **external consumers** (IDE clients,
remote dashboards) reading Sage state over MCP transport — not a
v1 requirement.

**This ADR predicts `sage_status` MCP tool will likely never be
promoted in v2 either.** Read-only state queries are bash-equivalent
forever; MCP wrap-around adds latency + dependency without semantic
benefit. v2 promotion would only happen if a concrete external
consumer materializes (e.g. a Sage IDE extension that wants a
JSON-RPC interface). Until then, `bin/sage status` stays bash.

## Options considered

### Option A — Bash-only `bin/sage status` (chosen)
Reads disk directly via yq. No external dependencies beyond yq.

- Pros: simple, fast, debuggable, parity with Claude port. No MCP
  cold-start.
- Cons: external consumers (if any v2) need a separate JSON-over-MCP
  surface — but none exist in v1 to design for.

### Option B — Bash + JSON output mode for future MCP wrap
Bash impl emits structured JSON when `--format json` requested;
v2 MCP `sage_status` becomes a thin wrapper around the bash command.

- Pros: forward-compatible with v2 if MCP returns.
- Cons: speculative — nobody has asked for `--format json` in v1
  use cases. Adds complexity now for a v2 maybe.

### Option C — MCP `sage_status` tool from v1
Ship the MCP tool now per original ADR-3.

- Pros: future-proof.
- Cons: requires MCP infrastructure (Cut B deferred all of it).
  Pure ceremony for v1 needs.

## Trade-offs

- **Determinism:** bash + yq is deterministic per disk state.
  Concurrent edits to `.sage/work/` during a `bin/sage status`
  run produce a snapshot-of-moment view; no locking. Acceptable.
- **External consumers:** if/when a real MCP-based consumer
  materializes, promote to v2 trigger 3 in ADR-3 (second consumer
  declares intent). Until then, no premature MCP surface.
- **Format stability:** the human-readable text output is **NOT**
  a stable contract — projects parsing it programmatically should
  use `--format json` (Option B) to be added if/when needed.

## Failure modes

- **Broken YAML frontmatter in any artifact:** exit 1 with
  filename + line context. `sage doctor` (ADR-8) surfaces this
  as a fixable diagnostic.
- **No `.sage/work/` directory:** print "no active initiatives,
  run `/sage` to start one" and exit 0 (not an error).
- **yq missing on PATH:** `bin/sage status` exits 2 with install
  hint. Pre-flight check in `bin/sage init --platform codex`
  catches this earlier (per ADR-3 v1 amendment + spec.md §7.1).

## Consequences

- ADR-3 (MCP stack) `sage_status` MCP tool entry is removed from v1
  scope and from v2 likely-shipped list (read-only = bash forever).
- `runtime/platforms/codex/` does not need any Python helper for
  CLI status; bash + yq is sufficient.
- v2 design constraint inherited from this ADR: if `sage_status`
  ever ships as MCP, it must remain a thin JSON wrapper around the
  bash impl (single source of truth for state semantics).

## Status: proposed
v1 amendment-friendly: this ADR encodes the post-Cut-B reality
without requiring a separate "deferred" status — the bash impl IS
the v1 design, not a fallback.
