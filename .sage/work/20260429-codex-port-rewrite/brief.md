---
title: "Brief — Codex port rewrite (greenfield, in-tree)"
workflow: architect
status: completed
approved_at: 2026-04-29
approved_by: alexostl
phase: understand
created: 2026-04-29
owner: alexostl
supersedes: .sage/work/20260429-codex-port-architecture-redesign/
inputs:
  - .sage/work/20260429-claude-port-logic-map/map.md
  - /Users/alexostl/.codex/worktrees/sage-selfhost/wizardly-pascal-60eb8f/.sage/docs/research-codex-port-rewrite-base.md
  - .sage/decisions.md
---

# Brief — Codex Port Rewrite

## Refactor Intent

Greenfield rewrite of the Codex port **inside this repository**.
`runtime/platforms/codex/` is the only directory we treat as expendable.
`core/`, `bin/sage`, and the Claude port (`runtime/platforms/claude-code/`)
are out-of-scope by default and may be touched only with explicit
justification (modify-with-care).

This is not an incremental fix to the rejected redesign cycle
(`20260429-codex-port-architecture-redesign`). That cycle's brief, spec,
and 8 ADRs are preserved as reference, NOT as inputs. The new cycle is
anchored on:

1. **Claude port logic map** (8 logical capabilities) — input describing
   what the *equivalent* Codex port must achieve.
2. **Research base** (`research-codex-port-rewrite-base.md`) — official
   Codex docs synthesis + 20-row assumption audit + 6 don'ts + 11 do's.
3. **Postmortem caveat from M0–M3** — the "regex blind to Polish"
   diagnosis is correct as a strategy but may not be the proximate
   empirical cause. Diagnostic replay is part of v1 scope.

## Problem

The current Codex port is shaped by Claude assumptions (slash commands as
a concept, `PreToolUse` only matching `Bash`, hooks as a 4-event surface,
unverified silent-failure preconditions). The M0–M3 enforcement
activation cycle shipped 78/78 unit tests PASS, then failed on the first
real Polish build prompt — and was reverted at commit `a6f1391`. The
in-review redesign cycle (`20260429-codex-port-architecture-redesign`)
attempted a 6-layer architecture but inherited the same Claude-shaped
mental model and was rejected by the user before approval.

The product problem is not "make Codex stricter." It is: Sage on Codex
must feel like a coherent workflow product where the agent **behaves the
same as on Claude** (passes through gates, creates artifacts, respects
approval), even when the *mechanisms* differ. Failure mode to avoid:
shipping a port that works on unit tests but loses the active workflow
on the first real prompt.

## Users

**v1 — primary user:**
- **Alex** (sage-selfhost operator). Self-identifies as junior dev / vibe
  coder. UX implications: no jargon-heavy `sage status` output, error
  messages must be actionable, error paths must be self-recoverable
  (`sage doctor`).

**v2 — secondary users (out of v1 scope, but v1 surfaces must already
be solid because v2 reuses them):**
- Future sage-on-Codex adopters cloning the framework.
- Future sage-on-generic-port adopters (the `generic` port is a
  reference template, not an automated port — but downstream users
  exist; shared manifest must not break for them).
- Junior / less process-aware users who benefit from being routed into a
  workflow without memorizing Sage internals.

## Hard Anti-Pattern — Explicit For This Cycle

**No keyword-based prompt classification, in any language.** User's
primary language is Polish. Polish nouns and verbs inflect heavily by
case (przypadek), conjugation, and declension — one logical concept
maps to dozens of surface forms ("zbudować / zbuduj / buduję / zbudujemy
/ buduj"). Any regex or keyword list is structurally blind. The Codex
rewrite enforces compliance through **deterministic surfaces only**:
`PreToolUse(apply_patch)` mutation gate, MCP-backed validators,
disk-persisted approval proof, L5 commit-time backstop. Antigravity's
multi-layer keyword classifier is mental-model input only — NOT a
template. Out of scope.

## Vision (V1–V4)

**V1 — Headline:** "Make Sage on Codex feel like a coherent workflow
product." (Inherited from prior brief; user confirmed valid.)

**V2 — Parity strategy: outcome parity, mechanism divergence.** The
agent's observable behavior must match Claude's (workflow entry,
artifact creation, gate respect, approval persistence). Mechanisms are
free to diverge where Codex has better primitives — `apply_patch` as a
mutation anchor, MCP as a workflow engine, `Stop` hook for end-of-turn
recovery. Some Claude-specific mechanisms disappear (no slash commands;
skill mentions `$skillname` instead).

**V3 — Enforcement framing: hard-where-possible, two named profiles.**
- `strict` — uses native granular `approval_policy` +
  `[permissions.<name>]` + sandbox where available.
- `fast-trusted` — user's normal mode (Skip Permissions). Behavioral
  guardrails (PreToolUse + MCP validators) + commit-time backstop (L5
  pre-commit). Honest framing: this is a guardrail, not a hard boundary.
- Both profiles are named honestly. `sage status` reports active profile
  and guarantee level.

**V4 — Users:** v1 = Alex only (junior-dev UX constraint applies).
v2 = downstream adopters (must be solid in v1 because surfaces are
shared).

## Constraints (C1–C5)

**C1 — Sequencing: PoC + design in parallel.** Mutation-anchor PoC,
3-tool MCP spike, and diagnostic replay run alongside design. Design
adapts if PoC findings diverge. Faster than serial; accepts rework risk.

**C2 — Reuse posture: boundary-by-boundary.** No across-the-board reuse
or rewrite. Each existing file in `runtime/platforms/codex/` (and shared
helpers like `runtime/mcp/json_to_toml.py`) is judged on alignment with
the new anchors. Self-learning gate: every reused file must be read
linearly before inclusion — comments may lie about behavior.

**C3 — Maintenance budget:** Bash + Python + whatever the task needs.
No hard ban on Node if the MCP SDK significantly simplifies the server.
Quality > simplicity-of-stack. Junior-dev readability remains a goal.

**C4 — Frozen vs negotiable:**
- `core/workflows/*.workflow.md`, `core/gates/scripts/*.sh`, `bin/sage`,
  Claude port, `.sage/` schema → **modify-with-care.**
- **Sage MCP server → Codex-port-only in v1.** Lives under
  `runtime/platforms/codex/mcp/` (or similar). Cross-platform extraction
  is a v2 concern at earliest.

**C5 — Test gate: hard outcome harness.** v1 not done until 12–15-prompt
pilot harness PASSES on `codex exec --json`. **Harness must be runnable
autonomously by Claude Code** (Claude Code orchestrates `codex exec` and
evaluates output structurally). User does not need to be in the loop per
prompt. Implication: harness is part of v1 scope, not deferred.

## Gaps Resolved (G1–G5)

**G1 — Diagnostic replay:** Run if Claude Code agent can fully
automate it. Otherwise minimal replay: verify only whether `codex_hooks`
was active in the loaded config during the M0–M3 dummy-project test.
Increases confidence in mutation-anchor commitment.

**G2 — Mutation matcher list (v1):** `apply_patch` only. Bash write
paths accepted as a known leak (caught by L5 pre-commit). Keeps
validator surface small. v2 may add Bash heuristic or MCP write-tool
list once v1 outcome harness proves the leak's real-world rate.

**G3 — Public skill list (the 16): not hardcoded.** Source of truth is
the Claude command set. **Codex visible skills must equal Claude
visible commands**, generated from one shared manifest. The 16-skill
baseline (build, fix, architect, research, design, analyze, reflect,
continue, qa, map, autoresearch, design-review, status, review, learn,
sage-navigator) is the *current* set; the architecture must support
add/remove with a single edit feeding both platforms.

**G4 — MCP `required = true`:** Hard fail on startup. Generator +
`bin/sage init` guarantee MCP boots ≈100% via installer + version check
+ dependency check. Failure mode: clear error pointing to `sage doctor`.
Honest: if env is broken, Codex doesn't pretend to work.

**G5 — `trust_level` automation:** Interactive prompt in `sage init`,
`git config --global` style: "Add this project to trusted projects in
your global Codex config? [y/N]". Yes → atomic edit of
`~/.codex/config.toml` with Sage-managed markers. No → copy-paste line
printed. `sage status` always verifies trust state at runtime.

## Success Criteria

The rewrite is successful when:

- Codex agent enters Sage workflow on Standard+ prompts (build, fix,
  architect) without depending on prompt-text intent classification.
- Mutation attempts (`apply_patch`) without valid workflow state are
  blocked by `PreToolUse` consulting MCP `sage_validate_mutation`.
- Approval proof persists to disk (frontmatter + decisions.md), survives
  compaction and fresh subagents.
- Public skill set in Codex UI = Claude command set, driven by one
  shared manifest.
- `sage status` honestly reports active profile + guarantee level +
  hook flag + trust state + MCP health.
- 12–15-prompt outcome harness PASSES via autonomous Claude Code
  orchestration of `codex exec --json`.
- v1 complete without modifying Claude port behavior.

## Scope

### Must Have (v1)

- Greenfield rewrite of `runtime/platforms/codex/`.
- `PreToolUse(apply_patch)` mutation gate consulting MCP.
- Sage MCP server (Codex-port-only in v1) with `required = true`,
  exposing the 9-tool surface from research base §4.7-bis.
- Two enforcement profiles (`strict`, `fast-trusted`), honestly framed.
- `sage status` reporting profile + hook flag + trust state + MCP health.
- Shared manifest driving both Claude commands and Codex visible skills.
- `bin/sage init` interactive prompt for global trust config.
- Autonomous outcome harness on `codex exec --json` orchestrated by
  Claude Code.
- Updated framework docs: `HOOKS.md`, `runtime/platforms/codex/README.md`
  corrected against research base assumption audit (drop "slash command"
  framing, drop "PreToolUse only Bash", add 6-event hook list).
- **Preamble extraction to `core/preambles/<workflow>.md`.** Cross-port
  refactor (touches Claude + Antigravity generators), but in v1 scope
  because: (a) Claude's per-workflow PREAMBLE is the strongest current
  enforcement channel for Sage workflows, (b) emulating that enforcement
  on Codex via deterministic primitives is part of the rewrite intent,
  (c) tight bash-case coupling is a confirmed pain point in 3 ports.
  Justified deviation from C4 modify-with-care: the change is mechanical
  (text relocation), and the Codex rewrite needs *short, focused*
  preambles that are too cumbersome to maintain inline.

### Nice To Have (v1)

- `sage doctor` command (separate from `sage status`) for actionable
  diagnostics with copyable fixes.
- Diagnostic temp-write allowlist (e.g., `.sage/tmp/`) — only if
  trivial; otherwise block all repo writes consistently.

### Won't Have In v1

- Bash mutation matching with content-aware heuristics (deferred to v2).
- MCP write-tool list as additional mutation matcher (deferred to v2).
- Cross-platform Sage MCP server (v2 concern).
- `.rules` Starlark policy files (evaluation deferred; L5 pre-commit
  remains primary commit-time backstop).
- Codex Cloud / app-only surfaces (Worktrees composer, Automations).
  CLI scope only for v1.
- Claiming OS-level hard enforcement in `fast-trusted` mode.

## Key Flow

1. User runs `sage init` in a project.
2. `sage init` prompts about adding the project to
   `~/.codex/config.toml` trusted list. User accepts → atomic edit;
   declines → copy-paste line.
3. Generator emits Codex-specific surfaces in `runtime/platforms/codex/`-
   shaped output: `AGENTS.md` (compact contract), `.agents/skills/`
   (the 16 visible skills, manifest-driven), `.codex/config.toml` (with
   `[features].codex_hooks = true`, MCP server registered as
   `required = true`), `<repo>/.codex/hooks.json` (PreToolUse on
   `apply_patch`, SessionStart, Stop).
4. User starts Codex. Session-start hook injects current `.sage/work/`
   state. AGENTS.md is loaded once; static rules.
5. On user prompt, Codex sees the 16 visible skills. Casual chat /
   read-only Q passes through unchanged.
6. On Standard+ prompt (build/fix/architect), agent should invoke
   `$build`, `$fix`, or `$architect`. Skill body loads its workflow.
7. Agent attempts mutation (`apply_patch`). `PreToolUse` calls
   `sage_validate_mutation` via MCP. Validator reads `.sage/work/`:
   - spec.md + plan.md exist → allow.
   - missing → deny with clear redirect to Sage workflow.
8. After approval at any gate, agent calls `sage_record_approval` —
   approval state persists to frontmatter + decisions.md. Survives
   compaction.
9. `Stop` hook calls `sage_audit_turn` — checks turn integrity, logs
   gaps.
10. In `fast-trusted` mode, every layer is a behavioral guardrail; L5
    pre-commit is the commit-time backstop.
11. `sage status` and `sage doctor` honestly report what's active and
    what's at risk.

## High Risk Areas

- The diagnostic replay reveals the M0–M3 proximate cause was
  hooks-silent or trust-untrusted, not regex. The mutation-anchor pivot
  is still correct strategy, but confidence in *why* the prior cycle
  failed must be calibrated.
- `apply_patch`-only mutation matching leaks via Bash writes more often
  than the L5 backstop catches. Outcome harness must include "agent
  writes via Bash" prompts to measure leak rate.
- `required = true` UX brittleness: if MCP fails to start (Python
  version, missing dependency, port collision), Codex doesn't open in
  the project at all. Installer + `sage doctor` must be bulletproof.
- The shared skill manifest (G3) is a new cross-platform abstraction.
  Risk: it bleeds Codex-specific concerns into shared `core/` (violates
  C4 modify-with-care for `core/`). Design must isolate the manifest
  schema cleanly.
- Outcome harness must run autonomously (C5). If `codex exec --json`
  output is non-deterministic across runs, structural evaluation breaks.
- Junior-dev UX: error messages, `sage status` output, `sage doctor`
  guidance must avoid jargon. Easy to slip into "agent-grade" prose.

## Open Questions For Design Phase

1. **Shared skill manifest location and schema** — `core/skills/manifest.yaml`?
   `core/workflows/<name>.workflow.md` frontmatter `public: true`? Per-
   platform exclusion list (e.g., `apply-prefix` makes no sense on
   Codex; manifest must allow per-platform override).
2. **Sage MCP server stack** — Python (consistent with rest of Sage)
   or Node (`@modelcontextprotocol/sdk` is canonical reference)? Pick
   based on smallest server diff for the 9 tools.
3. **MCP server installer** — `pip install` from local source, `pipx`,
   `uv`, vendored binary? Affects `sage init` complexity and
   `required = true` reliability.
4. **`sage_validate_mutation` semantics** — what counts as "valid
   workflow state" for an `apply_patch` to be allowed? Active initiative
   in `.sage/work/`? Spec exists? Plan exists? Plan in-progress with
   approved status field? Need explicit predicate.
5. **`sage_record_approval` schema** — frontmatter fields
   (`approved_at`, `approved_by`, `approval_gate`)? decisions.md entry
   shape? Both? Cross-reference?
6. **`Stop` hook v1 scope** — warn-only on missed gates, or attempt
   automatic recovery (e.g., scaffold missing artifact)?
7. **Outcome harness corpus** — exact 12–15 prompts: casual chat (PL/EN),
   read-only analysis, build with typos, fix, architect, explicit `$build`,
   invalid write attempt, valid write after spec, Bash-write attempt
   (leak measurement).
8. **`sage doctor` command surface** — separate binary entry point or
   `sage status --diagnose`? What checks exactly?
9. **`AGENTS.override.md` (user-global) usage** — for self-host
   maintainer-only directives? What goes there vs in project AGENTS.md
   vs in `developer_instructions` config key?
10. **Diagnostic replay automation feasibility (G1)** — can Claude Code
    actually replay `codex exec` against `dummy-project` with hooks
    instrumented enough to distinguish (a)/(b)/(c) from research base
    §3? Spike before committing to "always run replay".

## Out Of Scope For This Cycle

- Modifications to Claude port behavior beyond what the shared skill
  manifest forces.
- Codex Cloud / app-only / IDE-extension surface coverage.
- v2 mutation coverage (Bash heuristic, MCP write tools).
- Cross-platform Sage MCP server (v2).
- Memories integration (geo-restricted; Sage stays disk-of-record).
