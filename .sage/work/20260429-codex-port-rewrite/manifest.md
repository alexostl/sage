---
cycle_id: "20260429-codex-port-rewrite"
title: "Codex port rewrite (greenfield, in-tree)"
workflow: architect
phase: completed
status: completed
m2_status: completed
m2_completed_at: "2026-04-30"
m2_completed_by: "alexostl"
m1_status: completed
m1_completed_at: "2026-04-30"
m1_completed_by: "alexostl"
plan_status: approved
plan_approved_at: "2026-04-30"
plan_approved_by: "alexostl"
m0_status: completed
m0_completed_at: "2026-04-30"
m0_completed_by: "alexostl"
elicitation_round: 3-complete
spec_status: completed
spec_approved_at: "2026-04-30"
spec_approved_by: "alexostl"
created: 2026-04-29
updated: 2026-04-30 (CYCLE CLOSED — v1 ship-ready. M1 + M2 GREEN against real Codex 0.126.0-alpha.15. Bats 223/223. 4 cuts confirmed deferred per §13.2 with explicit v2 triggers (Cut A UPS, Cut B MCP, Cut C githooks, Cut D tier-aware predicate). Harness signal 3 (bypass_mutation) post-fix baseline = 3 LEGITIMATE shell-bypass detections — exactly the v2-promotion evidence §13.2 was designed to capture. T2.4/T2.5/T2.6 absorbed into M1 smoke. Ontology: proj_codexplt1 + docu_codharn1 linked. v1 cutover entry in decisions.md.)
owner: alexostl
supersedes: .sage/work/20260429-codex-port-architecture-redesign/
inputs:
  - .sage/work/20260429-claude-port-logic-map/map.md
  - /Users/alexostl/.codex/worktrees/sage-selfhost/wizardly-pascal-60eb8f/.sage/docs/research-codex-port-rewrite-base.md
  - .sage/decisions.md
  - sage-memory (project + global self-learnings)
artifacts:
  - manifest.md
  - brief.md
  - poc-c1-results.md
  - cross-port-survey.md
  - spec.md  # SIGNED OFF 2026-04-30 — v1 contract for plan.md authoring
  - plan.md  # APPROVED 2026-04-30 — 3-milestone implementation contract
  - poc-c2-c3-results.md  # M0 EMPIRICAL CLOSURE 2026-04-30 — Codex 0.126.0-alpha.15 verification + 4 surgical spec amendments
  - review-2026-04-30/synthesis.md  # 3-axis design review (2026-04-30) — GREEN with conditions
  - review-2026-04-30/agent-A1-hooks-feasibility.md
  - review-2026-04-30/agent-A2-config-instructions.md
  - review-2026-04-30/agent-A3-mcp-state.md
  - review-2026-04-30/agent-A4-cli-doctor-profiles.md
  - review-2026-04-30/agent-B-claude-parity.md
  - review-2026-04-30/agent-C-gap-detection.md
  - review-2026-04-30/recon-claude-bootstrap.md
  - review-2026-04-30/poc-A1-uncertainties.md
  - review-2026-04-30/spec-confrontation.md  # 2nd round review of post-cuts spec — GREEN-WITH-RESIDUAL-GAPS, 3 blockers identified + closed
  - .sage/docs/decision-codex-validate-mutation-predicate.md  # ADR-1 — proposed-amended (v1 narrowed scope)
  - .sage/docs/decision-codex-approval-proof-schema.md  # ADR-2 — DEFERRED-TO-V2 (Cut A)
  - .sage/docs/decision-codex-mcp-stack.md  # ADR-3 — DEFERRED-TO-V2 (Cut B)
  - .sage/docs/decision-codex-workflow-state-machine.md  # ADR-4
  - .sage/docs/decision-codex-instruction-surfaces.md  # ADR-5
  - .sage/docs/decision-codex-public-workflows-internal-library.md  # ADR-6
  - .sage/docs/decision-codex-stop-hook-scope.md  # ADR-7 (proposed; spec §6.5 narrows scope, ADR file NOT amended — read spec for v1 truth)
  - .sage/docs/decision-codex-doctor-and-status.md  # ADR-8
  - .sage/docs/decision-codex-cli-surface.md  # ADR-9 — created 2026-04-30 (was missing; bin/sage status bash impl)
  - .sage/docs/decision-codex-posttool-hallucination-check.md  # ADR-10 (proposed; spec §6.4 narrows scope, ADR file NOT amended — read spec for v1 truth)
codex_min_version: "0.126.0-alpha.15"
handoff: |
  STATE (handoff for Sage Build in next session/thread — read this FIRST):

  ## Current state (2026-04-30)

  - Phase: PLAN. spec.md SIGNED OFF (status: completed, approved_at:
    2026-04-30, approved_by: alexostl). Next artifact: plan.md.
  - This cycle is `architect` workflow. plan.md = milestone breakdown
    with exit criteria. Per user: "v1 in one go" — expect 1-2
    implementation milestones + final cutover, NOT 6 fine-grained ones.

  ## Read-this-order for plan.md authoring

  1. spec.md (THE v1 contract — single source of truth where it
     disagrees with any ADR; 2322 lines, monolithic by user request)
  2. brief.md (user's vision; what plan.md must serve)
  3. review-2026-04-30/spec-confrontation.md (independent review of
     post-cuts spec; identifies risk surfaces plan.md should sequence)
  4. .sage/decisions.md (most recent 5-6 entries — context on 4 cuts
     A/B/C/D + 3 blocker fixes B1/B2/B3 + ADR amendments)

  ## ADR status (post 2026-04-30 amendments)

  - **proposed (active in v1):** ADR-4, ADR-5, ADR-6, ADR-8, ADR-9
  - **proposed-amended (v1 amendment block in ADR file):** ADR-1
    (P3 tier-1 N/A, P4 N/A, bash impl)
  - **deferred-to-v2 (DEFERRED block in ADR file):** ADR-2 (approval-
    proof, Cut A), ADR-3 (MCP stack, Cut B)
  - **proposed but spec narrows scope (ADR file NOT amended; read
    spec.md for v1 truth):** ADR-7 (Stop hook — spec §6.5 narrows),
    ADR-10 (post-write check — spec §6.4 narrows)

  ## Critical constraints for plan.md

  - Greenfield baseline: `runtime/platforms/codex/` empty (commit 970aa8d).
    plan.md does NOT need to plan deletion of legacy Codex code — it's
    already gone. Cross-platform code under `runtime/cli/`, `runtime/mcp/`,
    `runtime/tools/` and sibling platforms (claude-code, antigravity,
    generic) is preserved — plan.md MUST NOT plan touches there unless
    explicitly required.
  - Codex hard requirement: ≥ 0.126.0-alpha.15 (PoC C1 anchored).
  - v1 ships NO Python runtime (Cut B). All hooks bash. No MCP server.
    No `[[mcp_servers]]` block in generated config.toml.
  - 4 cuts (A/B/C/D) and their v2 promotion triggers (§13.2) are the
    CONTRACT — plan.md must NOT silently expand v1 scope past these.
  - 3 blockers (B1/B2/B3) closed in spec.md §4 — plan.md milestones
    must include each as verifiable deliverable.

  ## Acceptance gate for plan.md (per Sage Build workflow gates)

  - plan.md frontmatter: status: completed, approved_at, approved_by
    once user signs off [A] at plan checkpoint.
  - Each milestone has explicit exit criteria (not vague "milestone
    done when implemented").
  - Each milestone references which spec §X it implements.
  - Verification harness scope is explicit (per §15 spec checklist).

  ## What user is junior-dev / vibe-coder

  Avoid jargon. Don't assume he remembers ADR section names — refer
  by the actual concern in plain Polish. Communication style file:
  .sage/docs/comm-style.md.

  ---
  HISTORICAL handoff (Batch 2/3 design phase — preserved for context;
  no longer the active state):

  - Phase: DESIGN, between Batch 2 and Batch 3.
  - Batch 1 (ADR-1/2/3) COMPLETE — PoC-validated + second-pass-reviewed.
    ADR-3 was amended in Batch 2: §"Files written outside MCP" now lists
    `pre-tool-validate.sh` as an authorised writer of `.mcp-incidents.log`
    (per ADR-5 review concern 3a). All other Batch 1 anchors unchanged.
  - Batch 2 (ADR-4/5/6) COMPLETE 2026-04-29:
    - ADR-4 (shared skill manifest) — `manifest:` block in workflow
      frontmatter, compiled to `core/_compile/skills.compiled.json`,
      generators read JSON via jq. mention_aliases REJECTED entirely
      (not even v2). registry.yaml left untouched (out of scope).
      display.codex carries only `allow_implicit_invocation`.
    - ADR-6 (preamble extraction) — `core/preambles/<wf>.md` with YAML
      teaser frontmatter (≤300 chars) + body. teaser is canonical
      source for SKILL.md description (Codex). All 3 generators read
      same file. Char budget: 16 × ~310 = ~4960 / 8000 (38% headroom).
    - ADR-5 (instruction surfaces) v3 — TWO project-scoped surfaces:
      AGENTS.md (full contract, user-role channel) +
      `<repo>/.codex/config.toml` developer_instructions (5 pre-action
      rules, developer-role channel — empirically VERIFIED in Codex
      source as `input[0]` developer-role API message; OpenAI Model
      Spec ASSUMES higher compliance weight, ADR-8 will measure).
      Append-below model with separator `## --- USER ADDITIONS BELOW ---`
      preserves user content across `sage update`. v1 hooks: 4 wired
      (SessionStart, UPS-token, PreToolUse(apply_patch), Stop);
      PermissionRequest + PostToolUse deferred to v2. All hook scripts
      thin bash shims to MCP per ADR-3. UPS vocabulary hard-locked
      English literal (`[A]/[a]/approve/continue` whole-word
      case-insensitive). LR-1..LR-6 imperative-tone contract closes
      2026-04-28 enforcement gap.
  - Codex hard requirement: ≥ 0.126 (custom-tool hook support).
    Pinned in ADR-1 + ADR-3 + ADR-5 frontmatter.

  NEXT STEP: Batch 3 — ADR-7 (Stop hook scope — consumes turn-audit.sh
  shim contract from ADR-5 §Stop, must lock audit logic: stale-token
  detection, forge detection via mtime, gate-state check; v1 NEVER
  hard-blocks continuation), ADR-8 (outcome harness — must wire
  developer_instructions toggle for control/treatment runs per ADR-5
  Step 7; 12-15-prompt pilot per C5; runnable by Claude Code
  autonomously), ADR-9 (sage doctor + status — consumes FM-1..FM-9
  + LR-3 strict-mode lint + skills.compiled.json drift check + AGENTS.md
  separator preservation check + v2 deferred verification snapshot
  artifact per ADR-5 cross-check status). Then spec.md integrating all
  9 + diagnostic replay plan + verification harness.

  Open questions deferred from Batch 2 to spec.md or ADR-9:
  - ADR-5 Q1: Stop hook v1 scope (locked surface, ADR-7 locks logic;
    if user wants full defer-to-v2, that's a 1-line hooks.json change)
  - ADR-5 Q2: PermissionRequest/PostToolUse stub scripts (default no)
  - ADR-5 Q3: developer_instructions size budget (default 700-1000)
  - ADR-5 Q4: tone-lint forbidden-phrase list (seed: "agents should",
    "consider", "it is recommended"; expand in spec.md cross-check)
  - ADR-5 Q5: INSTALL.md framing for native Codex escape hatches

  Risks for next agent to watch:
  - Don't redesign Batch 1 or Batch 2 anchors. If something seems
    wrong, check decisions.md + poc-c1-results.md + cross-ADR refs
    before proposing changes.
  - ADR-5 v3 explicitly defers verification snapshot artifact to v2.
    DO NOT bring it into v1 scope without explicit user signal.
  - W2 (UPS-token) mechanism schema is now FULLY locked in ADR-5
    §UserPromptSubmit. ADR-7 must NOT redefine vocabulary or token
    schema; it owns ONLY audit semantics (stale token, forge detection,
    gate-state at turn end).
  - User is junior-dev / vibe-coder. Avoid jargon. Don't assume he
    remembers ADR section names — refer by the actual concern in
    plain Polish.

  Required process: each Batch 3 ADR through user-review checkpoint
  (or [S] skip review) before moving to next ADR. After Batch 3 +
  spec.md, design checkpoint [A] runs auto-review sub-agent.
---

# Manifest — Codex Port Rewrite

## Context Summary

User decision (2026-04-29): the in-review architect cycle
`20260429-codex-port-architecture-redesign` is a dead end — close it,
restart from scratch as a greenfield port in this same repository.

Rationale (user's framing): the previous cycle compounded six months
of Claude-shaped assumptions. Even with a fresh elicitation pass, the
spec inherited mental models that the [research-codex-port-rewrite-base.md](file:///Users/alexostl/.codex/worktrees/sage-selfhost/wizardly-pascal-60eb8f/.sage/docs/research-codex-port-rewrite-base.md)
shows are wrong (e.g. "PreToolUse only matches Bash", "custom slash commands",
"hooks are 4 events not 6"). A clean architect cycle, anchored on confirmed
Codex primitives + the `claude-port-logic-map` capability list, produces a
better starting point than another revision pass.

## Current Phase

PLAN (Architecture Design). Brief approved 2026-04-29. Cross-port
survey complete (`cross-port-survey.md`, 244 lines). Brief updated with
preamble-extraction in scope + Polish anti-pattern explicit + generic v2
users.

**PoC C1 complete (2026-04-29):** see `poc-c1-results.md`. All three
architectural anchors empirically validated on Codex 0.126.0-alpha.15
(target version, matches Codex Desktop App):
- `PreToolUse(apply_patch)` fires + `exit 2` blocks ✅
- `required = true` hard-fails session on broken MCP ✅
- MCP crash mid-session = deny-fail-closed (no respawn, clean error) ✅

Initial run on 0.117 found PreToolUse(apply_patch) broken — superseded
by 0.126 retest. Spec must pin **Codex ≥ 0.126** as a hard requirement.

## ADR Sequence (3 batches × 3 ADRs + spec.md)

**Batch 1 — Foundations (written, user-reviewed, PoC-validated, second-pass-reviewed 2026-04-29):**
- ADR-1 `decision-codex-validate-mutation-predicate.md` (anchor) —
  Tier-1 honest framing, P2.2 forge risk accepted, version pin
  (Codex ≥ 0.126), failure-mode for mid-session crash documented,
  **W1 worktree scope made explicit, #3 cold-start failure mode
  added, #11 L5 `--no-verify` bypass honestly framed**.
- ADR-2 `decision-codex-approval-proof-schema.md` (paired with ADR-1) —
  schema validated, **W2 Approval Authority section added** (one-shot
  token via UserPromptSubmit hook, empirically validated by PoC C1
  extension), **W3 single-writer assumption added**, **B1 status
  alias normalization added**, **#8 migration plan acceptance
  criteria added**.
- ADR-3 `decision-codex-mcp-stack.md` (tech for both above) —
  `sage doctor` scope narrowed (no predicate duplication), version
  pin, **D6 (mid-session recovery path) revised** to use
  `.sage/.mcp-incidents.log` (no decisions.md pollution), **D2 + D5
  shim-based dispatcher** so `command` in config.toml is invariant
  across installer outcomes. `enabled_tools` verified real in
  research base.

**Batch 2 — Surfaces (COMPLETE 2026-04-29, all user-approved + ADR-5 independent-review-passed):**
- ADR-4 `decision-codex-shared-skill-manifest.md` ✓
- ADR-5 `decision-codex-instruction-surfaces.md` ✓ (v3 final; 9-concern review applied)
- ADR-6 `decision-codex-preamble-extraction.md` ✓
- ADR-3 amended: pre-tool-validate.sh added to authorised writers list

**Batch 3 — Operations (ADRs COMPLETE 2026-04-29):**
- ADR-7 `decision-codex-stop-hook-scope.md` ✓
- ADR-8 `decision-codex-outcome-harness.md` ✓
- ADR-9 `decision-codex-doctor-and-status.md` ✓

**Batch 3 closeout — COMPLETE 2026-04-30 (3 amendments applied):**
1. ✓ ADR-3 §"Files written outside MCP" — 4 new writers added,
   sage-writers.yaml referenced as declarative source of truth.
2. ✓ ADR-7 §Consequences — L5 hook line schema locked
   (JSON Lines: ts, commit_hash_pending, verdict, checks_run,
   duration_ms, sage_version).
3. ✓ ADR-5 §Open questions — all 5 Batch 2 Qs marked CLOSED
   with references to ADR-7/9 resolutions.

**Next step:** Independent review of full design (9 ADRs +
brief + cross-port-survey + manifest + decisions.md) BEFORE
spec.md. Review-agent runs on consistent doc state.

**Then:** `spec.md` integrating all 9 ADRs + diagnostic replay plan +
mermaid architecture diagram + verification harness scope.

## Round 3 — Gaps (answered 2026-04-29)

**G1 — Diagnostic replay:** (a) **Run replay if it can be automated by
Claude Code agent** (no manual user intervention). Otherwise (c) minimal
replay: verify only whether `codex_hooks` was active in the loaded config
during the M0–M3 dummy-project test. Goal: increase confidence in root
cause before committing fully to mutation-anchor architecture.

**G2 — Mutation matcher list (v1):** (a) **`apply_patch` only.** Bash
write paths (`echo > file`, `sed -i`, etc.) accepted as a known leak —
caught by L5 pre-commit backstop instead. Keeps validator surface small
and false-positive risk low. Future: (c) or (d) may be added in v2 once
v1 outcome harness proves the leak is rare in practice.

**G3 — Public skill list:** (a) accept the 16 baseline, **but with a
critical constraint:** the list is NOT hardcoded in the Codex generator.
Source of truth: Claude command set. **Codex visible skills must equal
Claude visible commands**, generated from one shared source. Implication
for design: generator reads a manifest (likely `core/workflows/*` or
`core/skills/<name>/manifest.yaml`) that drives BOTH platforms' public
surface. Adding/removing a public skill is a one-place edit.

**G4 — MCP `required = true`:** (a) **Hard fail on startup.** Generator +
`bin/sage init` guarantee MCP boots ≈100% (installer, version check,
dependency check). Failure mode: clear error message pointing at
`sage doctor`. Honest: if env is broken, Codex doesn't pretend to work.

**G5 — `trust_level` automation:** (c) **Interactive prompt during
`sage init`.** Style: `git config --global` flow. "Add this project to
trusted projects in your global Codex config? [y/N]". Yes → atomic edit
of `~/.codex/config.toml` with Sage-managed markers. No → printed
copy-paste line. `sage status` always verifies trust state at runtime.

## Round 2 — Constraints (answered 2026-04-29)

**C1 — Sequencing:** (b) **PoC + design in parallel.** Mutation-anchor PoC,
3-tool MCP spike, and diagnostic replay run alongside design. Design adapts
if PoC fails. Faster than serial, accepts rework risk.

**C2 — Reuse posture:** (b) **Boundary-by-boundary decision.** No
across-the-board reuse or rewrite. Each part of the existing
`runtime/platforms/codex/` is judged on alignment with the new anchors
(`PreToolUse(apply_patch)`, MCP-as-engine, honest framing). Files like
`runtime/mcp/json_to_toml.py` (research base: "mechanically correct")
likely stay; enforcement-related files likely don't. **Self-learning gate:**
read every reused file linearly before including — comments may lie about
behavior.

**C3 — Maintenance budget:** (b)+(c) **Bash + Python + whatever serves
the task best.** No hard ban on Node if the MCP SDK significantly
simplifies the server. Quality > simplicity-of-stack. Junior-dev
readability remains a goal but not a hard cap on tooling.

**C4 — Frozen vs negotiable:**
  - `core/workflows/*.workflow.md` → **modify-with-care** (negotiable,
    but cross-platform impact must be considered).
  - `core/gates/scripts/*.sh` → **modify-with-care.**
  - `bin/sage` → **modify-with-care.**
  - Port Claude (`runtime/platforms/claude-code/`) → **modify-with-care.**
  - `.sage/` schema → **modify-with-care.**
  - **Sage MCP server → Codex-port-only in v1.** Lives under
    `runtime/platforms/codex/mcp/` (or similar). Not designed as
    cross-platform shared infrastructure for v1. Cross-platform extraction
    is a v2 concern at earliest.

**C5 — Test gate:** (a) **Hard gate.** v1 not done until 12–15-prompt
pilot harness PASSES on `codex exec --json`. Plus user requirement: harness
must be **runnable autonomously by Claude Code** (Claude Code orchestrates
`codex exec` and evaluates output). User does not need to be in the loop
for each prompt. Implication for design: harness is part of v1 scope, not
deferred to build phase.

## Round 1 — Vision (answered 2026-04-29)

**V1 — Headline:** "make Sage on Codex feel like a coherent workflow
product." (Inherited from previous brief; still valid.)

**V2 — Parity strategy:** **Outcome parity, mechanism divergence.** The
agent on Codex must behave the same as on Claude (passes through gates,
creates artifacts, respects approval). Mechanisms may differ where Codex
has better primitives (e.g., `PreToolUse(apply_patch)` for mutation
gating, which Claude lacks). Some Claude-only mechanisms may disappear
(e.g., `apply-prefix` — Codex has no slash commands).

**V3 — Enforcement framing:** **Hard-where-possible, two named
profiles.**
  - `strict` profile: native granular `approval_policy` +
    `[permissions.<name>]` + sandbox where available.
  - `fast-trusted` profile (user's normal mode, Skip Permissions):
    behavioral guardrails + commit-time backstop.
  - Both profiles named honestly. `sage status` reports which is active
    and what guarantee level it provides.

**V4 — Users:**
  - **v1: only Alex (sage-selfhost operator).** Note: Alex self-identifies
    as junior dev / vibe coder — design must avoid jargon-heavy UX, error
    messages, and `sage status` output.
  - **v2: downstream sage-on-Codex adopters.** Honest framing (V3) and
    `sage status` clarity must already be solid in v1 because v2 reuses
    v1's surfaces.

## Inputs (read-only references)

- **Claude port capability map** — what the Claude port DOES (8 logical
  capabilities). Material for "what must Codex achieve", not "what to copy".
- **Research base** — assumption audit (20 rows), Codex platform truth
  (compressed from official docs), 6 don'ts, 11 do's, 10 open scope decisions.
- **`decisions.md`** — postmortem caveat: M0–M3 empirical failure may have
  had hooks-silent or trust-untrusted as proximate cause, not regex.
- **Self-learnings** — pseudo-Sage, regex dead end, line-count proxy,
  premature completion, false alternatives.

## Next Step

Run elicitation Round 1 (Vision) with user. Output: vision summary
visible in this manifest + saved into brief.md after Round 3.

## Constraints On This Cycle (process-level)

- Three rounds, sequential, each with a visible artifact. No compression.
- brief.md created only after Round 3. Until then artifacts live here in
  manifest.md as round-by-round visible state.
- Design phase blocked until elicitation gate is approved.
- `[A]` at design or plan checkpoint = run independent ADR/Plan review
  via sub-agent before proceeding.
- Diagnostic replay of M0–M3 dummy-project failure is a candidate
  Milestone 0 — to be confirmed in Round 3 (gaps).
