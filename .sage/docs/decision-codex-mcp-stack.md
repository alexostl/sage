---
title: "ADR — Codex Sage MCP server stack"
status: deferred-to-v2
status_history:
  - 2026-04-29 proposed
  - 2026-04-30 deferred-to-v2 (Cut B — MCP server cut entirely from v1; bash predicate equivalent)
date: 2026-04-29
amended: 2026-04-30
codex_min_version: "0.126"
related:
  - .sage/work/20260429-codex-port-rewrite/brief.md (G4, C3)
  - .sage/work/20260429-codex-port-rewrite/spec.md (§8 — MCP deferred entirely; §6.0 bash rationale; §13.2 v2 promotion triggers; §16 Cut B)
  - .sage/work/20260429-codex-port-rewrite/poc-c1-results.md (T2 + T3 empirical)
  - .sage/docs/research-codex-port-rewrite-base.md (§4.7, §4.7-bis)
  - .sage/docs/decision-codex-validate-mutation-predicate.md
  - .sage/docs/decision-codex-approval-proof-schema.md
---

# ADR — Sage MCP server stack

> **DEFERRED TO v2 (decision 2026-04-30, Cut B).** Codex v1 ships
> with **no MCP server**: no Python runtime requirement, no
> `[[mcp_servers]]` block in generated `.codex/config.toml`, no
> `sage-mcp` package install, no `required = true` deny-fail-closed
> contract, no `Transport closed` failure mode, no MCP-unreachable
> handling. All v1 enforcement logic lives in **bash hooks**
> (~40-line predicate inline in `pre-tool-validate.sh`).
>
> **Sequence of cuts that led here** (compounded same day,
> 2026-04-30; see `decisions.md`):
> 1. "MCP lite" — 5 planned tools → 2 (`sage_validate_mutation` +
>    `sage_record_approval`). 3 deferred to bash with v2 promotion
>    triggers per tool.
> 2. "MCP ultra-lite" — paired with Cut A (UPS deferral),
>    `sage_record_approval` lost its only caller → also deferred.
>    Down to 1 tool.
> 3. "No MCP" (this cut) — single-tool predicate on v1-narrowed
>    scope = bash-equivalent (~40 LOC, jq + yq + glob match). Whole
>    Python infrastructure unjustified for one predicate. Drop all.
>
> **Why deferred:** brief V3 frames gating as *"a guardrail, not a
> hard boundary"* — MCP `required = true` deny-fail-closed contract
> is "hard boundary" without empirical evidence supporting need.
> Bash equivalence + cross-port consistency (Claude port hooks are
> bash) + lower cold-start cost (~135ms vs ~1.35s Python) make MCP
> over-engineering for v1 scope.
>
> **v2 reactivation conditions** (binding — see `spec.md §8` v2
> promotion + `decisions.md` 2026-04-30 entry):
> 1. Bash predicate exceeds ~80 LOC, OR cold-start > 1s, OR needs
>    language parsers (e.g. ADR-10 Check B symbol existence) — ship
>    MCP, move `sage_validate_mutation` + `sage_check_post_mutation`
>    to Python.
> 2. §6.2 v2 promotion fires (approval gate returns) —
>    `sage_record_approval` needs Python's atomic file ops, brings
>    server back with it.
> 3. Second port (Claude Code, antigravity, generic) declares intent
>    to share validator logic — shared `runtime/mcp/server/` becomes
>    warranted (no premature abstraction).
>
> **v2 design constraints locked** (per decisions.md 2026-04-30):
> - MCP location starts at `runtime/platforms/codex/mcp/`;
>   extraction to `runtime/mcp/server/` only when second consumer
>   materializes.
> - Distribution name `sage-mcp` reserved.
> - Env-var sentinel `SAGE_USE_MCP=1` switches evaluator between
>   bash and MCP (no big-bang migration).
>
> Content below is preserved as v1-baseline-rejected design for v2
> reactivation reference. **Do NOT implement in v1.** PoC C1 T2/T3
> empirical anchors (`required = true`, `Transport closed`) are
> still valid for v2 redesign — they describe Codex 0.126 behavior,
> which doesn't change because we deferred the consumer.

---

## Context

ADR-1 + ADR-2 require an MCP server hosting (at minimum)
`sage_validate_mutation` and `sage_record_approval`. Brief specifies
`required = true` (Codex refuses to start session if MCP fails to
init). This puts the server's reliability and installer flow on the
critical path: if installer is fragile, Codex breaks for the user
permanently.

**Empirical anchor status (PoC C1, 2026-04-29):**
- T2 confirmed `required = true` with a missing/broken server
  hard-fails session creation with a clear copyable error.
- T3 confirmed mid-session crash: Codex returns `Transport closed`
  as a clean tool error and **does NOT respawn the server**. Once
  the validator dies, every subsequent gated tool call fails for the
  rest of the session — deny-fail-closed by construction. UX caveat:
  user must restart Codex; this drives D6 (recovery path) below.

This ADR therefore **requires Codex ≥ 0.126** (matches ADR-1's
version pin — custom-tool hooks, hook payload semantics, MCP error
surfacing all assume the 0.126 baseline).

Decisions to make:

1. **Language / SDK** for the server.
2. **Installer flow** for `bin/sage init`.
3. **v1 tool surface** (which of the 9 proposed tools ship in v1).
4. **Project layout** (where the server code lives, how it's
   versioned).

Cross-port truth (informational only — Sage MCP is Codex-port-only in
v1 per C4): Antigravity has no MCP. Generic has no MCP. **No port
solves this; we're establishing it.**

## Decision

### D1 — Language: **Python**

The server is written in Python using the official
`mcp` SDK (`pip install mcp`).

Rationale:
- Sage's existing helpers (`runtime/mcp/json_to_toml.py`, hook scripts'
  Python invocations, Sage skill scripts under `sage/skills/*/scripts/`)
  are Python. Stack consistency for a junior-dev / vibe coder.
- Brief C3 allowed Node if it significantly simplified the server, but
  the MCP Python SDK is canonical in Anthropic + OpenAI tooling and
  Sage already depends on Python at runtime. Adding Node = +1 runtime
  to install in `bin/sage init`, +1 stack to debug.
- Type-checked with `pyright` (already used in `runtime/mcp/`).

Out of scope: Rust, Go. Considered for performance — rejected because
v1 server is I/O-bound (file reads), latency floor is filesystem, not
language.

### D2 — Installer: **`uv` with vendored fallback + shim dispatcher**

Primary installer flow in `bin/sage init`:

1. Detect `uv` binary (faster, deterministic resolver). If present,
   `uv tool install --from . sage-mcp-server`.
2. Fallback if `uv` absent: detect `pipx`, `pipx install --force ./runtime/platforms/codex/mcp/`.
3. Fallback if both absent: detect `python3 >= 3.10`, `pip install --user .`.
4. Fallback if Python missing: error with install instructions, fail
   `sage init` (do not silently skip — `required = true` later would
   fail anyway, better to fail upfront).
5. **Whichever installer succeeded, write a launch shim at
   `~/.sage/bin/sage-mcp-server`** (mode 0755) that `exec`s the
   chosen runtime. This is the invariant the rest of the system can
   depend on: regardless of installer ladder outcome, the launch
   command is always one absolute path. Example shim contents
   (chosen at install time):

   ```bash
   #!/usr/bin/env bash
   # auto-generated by bin/sage init; do not edit
   exec uv tool run sage-mcp-server "$@"
   ```

   Other variants: `exec pipx run sage-mcp-server "$@"` /
   `exec python3 -m sage_server "$@"`. `bin/sage init` records the
   chosen installer and shim variant in `~/.sage/install.json` so
   `sage doctor` can diagnose if it later breaks.

Server is vendored: source lives in
`runtime/platforms/codex/mcp/sage_server/`. Git-tracked. No PyPI
publication for v1 (downstream users get it via cloning the
framework).

Version pinning: `pyproject.toml` declares Python `>=3.10`, MCP SDK
exact version. `bin/sage doctor` reports installed version vs
pinned.

### D3 — v1 tool surface: **Phased rollout, 4 tools in v1**

The full 9-tool surface from research base §4.7-bis is the v1+v2
target. **v1 ships 4 tools**:

| Tool | Phase | Why v1 |
|---|---|---|
| `sage_status` | v1 | Read-only; required by `sage doctor`, hooks, `bin/sage status`. Smallest surface. |
| `sage_validate_mutation` | v1 | Foundational anchor (ADR-1). Without it, no mutation gate. |
| `sage_record_approval` | v1 | Foundational anchor (ADR-2). Without it, validator's P4 has nothing to read. |
| `sage_audit_turn` | v1 | Called by `Stop` hook (ADR-7). Closes the recovery loop. |

**v2 (out of v1 scope):**

| Tool | Why deferred |
|---|---|
| `sage_route` | Brief explicitly excludes prompt classification. Routing is via skill mentions, not MCP. |
| `sage_next_action` | Useful but not on critical path; agent can read manifest directly. |
| `sage_validate_transition` | Subsumed by validate_mutation + audit_turn for v1; future granular gates. |
| `sage_create_artifact` | v1 uses workflow scripts (existing `sage/skills/specify/scripts/`); MCP wrapper is a v2 ergonomics layer. |
| `sage_checkpoint` | Convenience wrapper over status + record_approval. Defer until pattern emerges. |

### D4 — Project layout

```
runtime/platforms/codex/
└── mcp/
    ├── pyproject.toml          # build + deps + entry point
    ├── README.md
    ├── sage_server/
    │   ├── __init__.py
    │   ├── server.py           # MCP server entry, registers 4 tools
    │   ├── tools/
    │   │   ├── status.py
    │   │   ├── validate_mutation.py
    │   │   ├── record_approval.py
    │   │   └── audit_turn.py
    │   ├── core/               # shared library (workflow state, gate predicates)
    │   │   ├── workflow_state.py
    │   │   ├── frontmatter.py  # parse YAML frontmatter
    │   │   ├── decisions.py    # parse decisions.md
    │   │   └── predicates.py   # ADR-1 P1-P4 logic
    │   └── tests/
    └── scripts/
        └── install.sh          # called by bin/sage init
```

The `core/` subpackage is intentionally **not exposed as a public
import path**. Hooks call MCP tools (which call core); `bin/sage
status` calls core directly (no MCP self-call). Both surfaces share
the same source of truth.

### D5 — Configuration in `.codex/config.toml`

```toml
[mcp_servers.sage]
command = "/Users/<user>/.sage/bin/sage-mcp-server"  # absolute path to shim, written by sage init
args = []
required = true
startup_timeout_sec = 5
tool_timeout_sec = 10
enabled_tools = ["sage_status", "sage_validate_mutation", "sage_record_approval", "sage_audit_turn"]
```

The `command` is the absolute path to the D2 shim. This block is
**stable across installer outcomes** (uv / pipx / pip-user) — the
shim handles dispatch internally. `bin/sage init` writes the shim
path with `$HOME` resolved at install time.

`enabled_tools` is verified to exist in the Codex 0.126 config schema
(per research base §5 row 20, §4 line 134/175). Listing tools
explicitly means when v2 adds tools, the deploy must opt in;
prevents silent surface drift.

### D6 — Mid-session recovery path

PoC C1 T3 (see
[poc-c1-results.md](../work/20260429-codex-port-rewrite/poc-c1-results.md))
surfaced an asymmetry on Codex 0.126.0-alpha.15: `required = true`
only protects session **startup**, not mid-session liveness. A
startup-healthy MCP that crashes later leaves the session running
with a permanently dead validator (no respawn). Every subsequent
gated mutation fails with `Transport closed` until the user restarts
Codex.

**Watch note:** retest no-respawn behavior at every major Codex
bump (≥0.130, ≥0.200). If Codex adds MCP auto-respawn, D6's
recovery path simplifies — `sage doctor` can drop the
restart-recommendation branch.

This is safe (deny-fail-closed) but bad UX if not surfaced. Decision:

1. **`sage doctor` includes a "current Codex session" probe** that
   detects "MCP listed in config but not reachable in this process".
   When triggered, doctor prints a clear remediation:
   *"Validator MCP appears to have crashed in the current Codex
   session. Restart Codex (close + reopen) to recover. The
   validator will hard-fail the session on restart if it still
   can't start, with the underlying error."*
2. **Stop hook (ADR-7) detects the dead-validator state** by checking
   if `sage_audit_turn` itself returns `Transport closed`. On detection,
   the hook script appends a JSON line to `.sage/.mcp-incidents.log`
   (timestamp, session_id, last_turn_id, error string). `decisions.md`
   is **not touched** — MCP is the only writer to that file in our
   design, and an MCP-down event is an infrastructure incident, not
   a project decision. `sage doctor` reads `.mcp-incidents.log` on
   every run and surfaces unread incidents to the user. The hook
   script writes this file directly via plain `echo >>` (no MCP
   dependency) — solves the "writer paradox" where the only writer
   to `.sage/` is the dead validator.
3. **No automatic respawn from Sage side.** Codex doesn't expose a
   respawn API; we do not try to work around this in v1. Restart-Codex
   is the documented recovery flow.

## Options considered

### Language

- **Python (chosen)** — stack consistency, MCP SDK is solid, junior-dev
  readable.
- **Node + `@modelcontextprotocol/sdk`** — canonical reference. Smaller
  server diff. Rejected because adds Node runtime to install
  prerequisites; Sage user has no other Node-based code.
- **Bash + JSON-RPC by hand** — zero deps. Rejected as
  unmaintainable for 4+ tools and unknown protocol edge cases.
- **Rust** — bulletproof, fast. Rejected as overkill (I/O-bound) and
  raises the bar for "vibe coder" maintenance.

### Installer

- **`uv` primary, `pipx` fallback, `pip --user` fallback (chosen)** —
  ladder of reliability; `uv` is fastest path when present.
- **`pipx` only** — simpler, but `uv` is now de facto standard and
  resolves dependencies more reliably.
- **Vendored binary (PyInstaller)** — zero-install. Rejected: binary
  size, platform matrix, debug-ability for junior-dev maintenance.
- **PyPI publication** — proper distribution. Out of v1 scope; we
  iterate the API too rapidly to commit to a public package.

### v1 tool surface

- **9 tools (full research base spec)** — comprehensive but doubles
  the v1 implementation cost and most aren't critical-path.
- **3 tools (status + validate + record)** — leanest. Misses
  `sage_audit_turn` which closes the Stop-hook loop (ADR-7).
- **4 tools (chosen)** — matches the foundational anchors; defers
  ergonomics to v2.

## Trade-offs

- **`required = true` is brittle by definition.** If MCP install
  breaks for any reason, Codex doesn't open. ADR-9 (`sage doctor`)
  must be runnable WITHOUT a working MCP — diagnostic from
  `bin/sage`, not via Codex. **Scope of doctor without MCP is
  intentionally narrow:** environment checks (Python version, `uv`
  presence, hooks installed, config file present) + "is the MCP
  process running and reachable?" probe. Doctor does **not**
  duplicate the predicate logic from ADR-1 — that lives only in MCP
  server code, single source of truth. If MCP is down, doctor's job
  is to tell the user *that it's down and why*, not to substitute
  for it. This puts more weight on the installer ladder being
  correct.
- **Python 3.10+ requirement** excludes very old systems but is
  reasonable in 2026. Documented in README.
- **Versioning drift:** Codex MCP SDK and Sage MCP SDK can drift.
  `sage doctor` reports actual versions; `pyproject.toml` pins.
- **Tests:** `runtime/platforms/codex/mcp/sage_server/tests/` runs
  via `uv run pytest`. Outcome harness (ADR-8) is integration-level;
  these are unit-level for predicates.
- **Latency:** MCP tool calls add ~10–50ms per invocation (subprocess
  IPC + filesystem reads). For `PreToolUse(apply_patch)` this is
  acceptable; for `Stop` hook, batched by definition.

## Failure modes

- **`uv` not installed and `pipx` not installed and `pip` not
  installed:** `sage init` fails with copyable install instructions
  for `uv` (cross-platform one-liner from astral.sh).
- **Python version too old:** init fails; user upgrades.
- **MCP server crash on tool call (mid-session):** PoC C1 T3
  empirically confirmed — Codex returns `Transport closed`, every
  subsequent tool call fails with the same error, no respawn. Hooks
  treat as deny by construction. Recovery is via D6: `sage doctor`
  surfaces the dead-validator state, Stop hook logs the gap to
  `.sage/decisions.md`, user restarts Codex.
- **`required = true` blocks Codex on first use** (e.g., user hasn't
  run `sage init`): expected. Codex error message points at `sage
  init`. We accept this as honest UX over silent fallback.
- **Drift between `core/` Python module and shared workflow
  definitions:** detected by `sage doctor` schema check; tests in
  `tests/` lock the schema.

## Consequences

- ADR-7 (Stop hook) wires `sage_audit_turn`.
- ADR-9 (`sage doctor`) needs CLI-only mode (no MCP dep) for
  diagnosing MCP failures. Scope: environment + "is MCP up?" probe.
  No predicate logic duplication. When MCP is down, the user gets a
  clear pointer + remediation; they do not get a second-class
  validator answer.
- `bin/sage init` grows installer ladder + `--mcp-only` flag for
  reinstalling just MCP, **plus the shim writer step (D2 step 5)**
  and the `~/.sage/install.json` record.
- New top-level `pyproject.toml` under `runtime/platforms/codex/mcp/`.
  Does NOT affect repo-root `pyproject.toml` (none exists today).
- v2 will add 5 more tools — manifest opt-in via `enabled_tools`
  prevents silent surface growth.
- **Files written outside MCP** (must be tracked because they
  bypass the validator's normal write path; declarative source
  of truth: `runtime/platforms/codex/audit/sage-writers.yaml`,
  introduced by ADR-7):
  - `~/.sage/bin/sage-mcp-server` (D2 shim, written by `bin/sage init`)
  - `~/.sage/install.json` (D2 install metadata, written by `bin/sage init`)
  - `.sage/.approval-pending` (ADR-2 W2 token, written by `UserPromptSubmit`
    hook only)
  - `.sage/.mcp-incidents.log` (D6 incident log, written by Stop hook
    when MCP is unreachable, AND by `pre-tool-validate.sh` PreToolUse
    hook when MCP is unreachable mid-session — per ADR-5 §`PreToolUse`
    action sequence step 3)
  - `.sage/.ups-hook.log` (ADR-7 D4 forge-detection pair, written by
    `UserPromptSubmit` hook only — every UPS firing logs one line
    with prompt hash + token-issued flag, session-scoped, truncated
    on SessionStart)
  - `.sage/.session-mutations.log` (ADR-7 C7 baseline, written by
    `pre-tool-validate.sh` only — accepted patches' file lists,
    session-scoped, truncated on SessionStart)
  - `.sage/.precommit.log` (ADR-7 C5 baseline, written by L5 pre-commit
    hook only — verdict line per invocation per the schema in ADR-7
    §"L5 hook line schema", project history, monthly rotation)
  - `.sage/.mcp-incidents-ack.log` (ADR-9 D6 acknowledgement log,
    written by `sage doctor --acknowledge` only — append-only,
    rotated alongside `.mcp-incidents.log`)
  - These are the only paths Sage tooling writes to without going
    through the validator MCP. Stop-hook audit (ADR-7 §C7) cross-checks
    that `git diff` doesn't show edits to other paths in `.sage/`
    that bypass the validator. Drift between this list and
    `sage-writers.yaml` is a `sage doctor --strict` S4 error.

## What happens when this fails

1. **Installer fails on user's machine** → `sage init` shows
   actionable error pointing at install instructions. User installs
   `uv`, retries.
2. **MCP server fails to start at session time** → Codex shows
   clear error ("Sage MCP server required but not running"). User
   runs `sage doctor`, which works without MCP and prints
   diagnosis: which environment piece is missing, whether the MCP
   process is reachable, and a copyable remediation command. Doctor
   does NOT attempt to validate workflow state in this mode — it
   says "MCP is down, here's why, fix it and retry" and stops.
3. **Tool returns malformed response** → MCP protocol layer rejects;
   hook treats as deny. Outcome harness includes "MCP tool returns
   garbage" as a regression case.
4. **Version skew between SDK and Sage MCP** → `sage doctor` reports
   the version diff with copyable upgrade command.

## Status: proposed
Awaiting user approval at design checkpoint after Batch 3 + spec.md.
