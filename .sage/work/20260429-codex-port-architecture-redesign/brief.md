---
title: "Brief — Codex port architecture redesign"
workflow: architect
status: rejected-superseded
superseded_by: .sage/work/20260429-codex-port-rewrite/
phase: understand
created: 2026-04-29
owner: alexostl
---

# Brief — Codex Port Architecture Redesign

## Refactor Intent

This is a complete refactor of the Codex adapter architecture, not an
incremental patch to the existing hook implementation. Existing Codex port
surfaces may be reused where they fit the new design, but the target design is
allowed to reorganize how `AGENTS.md`, `.agents/skills/`, `.codex/config.toml`,
hooks, generated docs, and Codex-specific status checks work together.

The refactor should stay scoped to the Codex port by default. Shared Sage
structures may change only when the design proves that the underlying concept
must be platform-agnostic, such as an internal skill library manifest.

## Problem

The Codex port of Sage currently carries too many Claude-shaped workarounds
instead of an architecture built around Codex-native surfaces. The previous
Codex enforcement activation cycle proved that mechanically green tests are
not enough: a regex-based prompt classifier failed on the first real Polish
build prompt and let Codex implement without Sage routing, artifacts, or
checkpoints.

The product problem is not merely "make Codex stricter." The goal is to make
Sage on Codex feel like a coherent workflow product:

- the user can choose from a small public set of workflow skills;
- the agent can still use the rest of Sage methodology without exposing all
  internal skills in the UI;
- casual conversation and read-only work remain possible;
- mutation work is steered into Sage gates before files are changed;
- enforcement is described honestly, especially in Skip Permissions mode.

## Users

Primary user:
- Alex / Sage self-host operator: wants fast trusted local work in Codex while
  preserving Sage's workflow discipline.

Secondary users:
- Future Sage-on-Codex users who need the framework to guide them without
  memorizing dozens of internal skills.
- Junior or less process-aware users who benefit from being put into a clear
  workflow rather than relying on prompt discipline.

## Success Criteria

The redesign is successful if:

- Codex exposes only the public workflow skill surface in the UI, expected to
  be roughly 16 workflow skills.
- Internal Sage skills remain available to the agent through lazy-loaded
  library access, not through the public skill palette.
- `AGENTS.md` becomes a compact static contract rather than a large duplicate
  methodology document.
- `SessionStart` supplies dynamic project state without repeating the whole
  constitution.
- `UserPromptSubmit` acts as a micro-router with a hard cap of 200 tokens per
  turn.
- Write/edit attempts without valid Sage workflow state are intercepted through
  best-effort hook guardrails and later backstops.
- The system clearly reports whether it is running in `fast-trusted` mode
  (behavioral guardrails, Skip Permissions) or `strict` mode (sandbox and
  permission boundaries available).
- Verification includes outcome-driven pilot prompts, not only unit tests of
  hook mechanics.

## Scope

### Must Have

- Public UI contract: only workflow skills are visible to users in Codex skill
  selection.
- Internal Sage library: non-public skills are available by manifest/path and
  loaded lazily only when a workflow phase needs them.
- No regex intent gate as a source of truth.
- Lightweight soft navigator:
  - `AGENTS.md` holds static rules.
  - `SessionStart` injects dynamic state.
  - `UserPromptSubmit` injects a small per-turn routing nudge.
- Mutation guardrails:
  - `PreToolUse` covers common write/edit paths such as `apply_patch`, `Edit`,
    `Write`, and selected MCP write tools.
  - `PostToolUse`, `Stop`, and pre-commit catch missed or completed mutations.
- Two enforcement profiles:
  - `fast-trusted`: optimized for Skip Permissions and trusted local repos;
    behavioral enforcement only.
  - `strict`: uses sandbox/permissions where available for stronger
    boundaries.

### Nice To Have

- Diagnostic temporary writes may be allowed if the implementation is simple
  and unambiguous, such as a narrow allowlist for `.sage/tmp/`, `.tmp/`, or a
  known temp directory.
- If diagnostic write detection requires semantic classification or complex
  policy, v1 should block all repo writes consistently instead.

### Won't Have In V1

- Semantic subagent as the main gate on every prompt.
- Regex keyword classifier for build/fix/architect intent.
- Full native exposure of all internal Sage skills in Codex UI.
- Bulk-loading internal skill bodies at session start.
- Claiming OS-level hard enforcement in Skip Permissions mode.

## Key Flow

1. User starts or resumes Codex in a Sage-managed project.
2. Codex loads the compact `AGENTS.md` static contract.
3. `SessionStart` injects current Sage project state: active initiatives,
   phase, next gate, and recent decisions.
4. On each prompt, `UserPromptSubmit` injects a micro-router under 200 tokens.
5. If the request appears to be Standard+ work, the agent should enter a Sage
   workflow before implementation.
6. If the agent tries to mutate files without valid workflow state,
   `PreToolUse` blocks common write/edit paths and redirects to Sage.
7. In Skip Permissions / `fast-trusted`, this is a behavioral guardrail, not a
   complete security boundary.
8. `PostToolUse`, `Stop`, and pre-commit provide backstops for mutations that
   bypassed or completed before earlier checks.
9. The selected workflow skill loads fully only after workflow entry.
10. Internal Sage library skills are loaded lazily by workflow phase.

## Constraints

- The user normally works in Skip Permissions, so the architecture cannot rely
  on approval prompts as the main enforcement mechanism.
- Codex docs describe `PreToolUse` as a guardrail rather than a complete
  enforcement boundary.
- `UserPromptSubmit` matcher is not supported, so any per-prompt hook must be
  tiny because it runs on every prompt.
- The per-turn micro-router hard cap is 200 tokens.
- `SessionStart` may be richer but should not duplicate static rules.
- Shared Sage structures should not be changed casually. Platform-specific
  Codex changes are preferred unless a platform-agnostic skill library manifest
  is genuinely required.

## High Risk Areas

- The agent loses the active initiative and starts fresh despite `.sage/work/`
  state.
- The agent performs pseudo-Sage: says the right words but does not create or
  update real `.sage` artifacts.
- The agent fails to write or update Sage documentation and decisions at
  checkpoints.
- The system over-blocks casual conversation or read-only analysis.
- The system under-blocks writes in Skip Permissions and gives a false sense of
  hard enforcement.
- Internal library skills drift from workflow manifests and stop being loaded
  at the right phase.
- Verification focuses on unit tests instead of behavioral outcome tests.

## Open Questions For Design Phase

- What is the exact public workflow skill list and naming contract?
- Where should the internal skill manifest live if it needs to be shared across
  platforms?
- What is the minimal artifact/state predicate for "valid Sage workflow state"
  before a write?
- Which write paths can Codex hooks reliably cover today, and which require
  backstops or honest caveats?
- How should `sage status` report `fast-trusted` versus `strict` enforcement
  so users understand the guarantee level?
- What is the final pilot corpus: likely 12-15 prompts covering casual chat,
  read-only analysis, Polish build requests with typos, fix, architect, explicit
  workflow invocation, invalid writes, valid writes, and optional temp writes?
