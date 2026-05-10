---
cycle_id: "20260507-codex-operating-model-v11"
title: "Codex operating model v1.1"
workflow: architect
phase: completed
status: completed
created: 2026-05-07
updated: 2026-05-07
owner: alexostl
scope:
  - ".sage/work/20260507-codex-operating-model-v11/*"
  - ".sage/decisions.md"
  - ".sage-memory/*"
  - ".sage/docs/decision-codex-*.md"
  - ".sage/docs/analysis-codex-*.md"
  - "core/**"
  - "bin/sage"
  - "runtime/platforms/codex/**"
  - "docs/**"
  - ".sage/work/20260507-codex-v11-harness-audit-followups/*"
---

# Cycle: Codex operating model v1.1

## State

**Current phase:** completed — final checkpoint approved 2026-05-07.

## Context summary

This architect cycle is a post-fieldwork rebuild of the Codex operating model,
not an upstream PR readiness pass. It compares five sources of truth: official
OpenAI/Codex documentation, original Sage framework documentation, current
Codex v1 implementation, first-days fieldwork findings, and generated agent
instruction surfaces such as `AGENTS.md`, skills, hooks, status output, and
recovery guidance.

## Round 1 framing

The core problem is that Codex Sage v1 works, but its operating model is spread
across instructions, workflow docs, hooks, status, harnesses, and local lessons.
The weakest points are where the agent lacks a clear next legal move: when a
workflow is truly active, where findings belong, which repo owns scope, when
manifest-only state is valid, and what is guidance versus runtime guardrail.

## Research inputs gathered

- Official OpenAI/Codex docs research: `AGENTS.md`, config, hooks,
  sandbox/approvals, slash commands, cloud execution, and validation loop.
- Original Sage framework research: workflow lifecycle, artifact-first state,
  gates, status/continue, adaptive workflow weight, and platform adapter model.
- Current Codex v1 research: generated `AGENTS.md`, skill loaders,
  `.codex/config.toml`, hooks, status/doctor, harness, and tests.
- Fieldwork findings: workflow activation, artifact ordering, review capture,
  cross-repo scope, paused/intake ambiguity, bootstrap traps, and harness gaps.

## Artifacts

- manifest.md: in-progress
- brief.md: completed, approved 2026-05-07
- spec.md: completed, revised after auto-review
- plan.md: completed, approved 2026-05-07 after 120-second auto-review rerun
- qa-report.md: completed 2026-05-07, PASS WITH WARNINGS
- ADRs:
  - `.sage/docs/decision-codex-v11-layered-operating-model.md`: proposed

## Round 2 scope

Must-have scope for v1.1:

- Define one manifest lifecycle shared by generated guidance, hooks, `status`,
  `doctor`, and continuation behavior.
- Define documentation artifact governance: when the agent writes
  `.sage/docs/`, `.sage/work/<cycle>/`, `.sage/work/<cycle>/research/`,
  `manifest.md`, `brief.md`, `spec.md`, `plan.md`, and `.sage/decisions.md`.
- Map each operating-model problem to the right surface: instructions,
  workflow/skill, status/recovery UX, blocking hook, audit hook, deterministic
  test, real harness, config/MCP, or explicit limitation.
- Make hook recovery messages teach the next legal move, not only reject
  mutation.
- Treat review/capture as a first-class flow with a safe path to manifest and
  decisions state.
- Define cross-repo ownership: the edited repo owns workflow state, scope, and
  gates.
- Require deterministic tests and real Codex harness evidence where behavior
  depends on actual agent/runtime behavior.

Non-scope for v1.1:

- Do not center upstream PR readiness.
- Do not promise absolute enforcement through hooks.
- Do not commit to a full MCP workflow engine unless deeper research proves it
  is necessary.
- Do not rewrite the whole Codex port from scratch.
- Do not turn ordinary conversation into mandatory workflow ceremony.

Constraints:

- Official OpenAI/Codex docs and original Sage framework docs are both
  benchmark sources.
- Original Sage docs define a two-folder convention: `.sage/docs/` is durable
  project-level knowledge, while `.sage/work/` is per-initiative work; Codex
  v1.1 must preserve that distinction.
- `AGENTS.md` is a primary Codex-native instruction layer, but must remain
  concise and cannot carry the whole operating model alone.
- Hooks are guardrails and audit/recovery surfaces, not a complete security
  boundary.
- Documentation routing is a first-class operating-model concern, not a
  footnote under TODO routing.
- Subagent reports are initial reconnaissance only. Before design/spec
  decisions, source-sensitive areas must be rechecked directly against primary
  files and official docs.

## Handoff guidance

Brief checkpoint is approved. Proceed to architecture design and re-check
source-sensitive claims against primary files before writing ADRs or spec.

## Design checkpoint summary

The proposed v1.1 design uses a layered operating model: instruction,
workflow, state, documentation governance, recovery-first Sage behavior,
guardrail, audit, verification, and deferred integration layers. It preserves
conversation-first routing, keeps workflow state on disk, treats hooks as
honest guardrails rather than a complete enforcement boundary, and makes
documentation artifact routing a first-class part of the model.

User-reviewed UX decisions now captured in `spec.md`:

- broad-scope prompts propose workflow but wait for confirmation;
- `status` shows active plus paused/intake in separate sections;
- artifact routing is deterministic and does not ask about storage;
- recovery emphasizes safe auto-fix so long unattended tasks do not stop on
  repairable metadata/state issues;
- Capture Router is conservative-autonomous: unsure actionable findings become
  minimal intake cycles with `needs-triage`;
- verification is risk-based: deterministic tests by default, real Codex
  harness for agent/runtime behavior.

Live fieldwork during the design phase exposed one additional issue:
`PreToolUse[apply_patch]` allowed the first Codex v1.1 ADR, then blocked
subsequent architect ADR writes with a Moderate+ fix plan/manifest error. The
spec captures this as hook overreach: fix artifact-order enforcement must not
misclassify architect design documentation as implementation.

Next legal move: user decides whether revised spec is sufficient to proceed to
milestone planning, whether to discuss remaining ADR/minor blocker, or whether
to pause for a new session.

## Auto-review checkpoint

Architecture auto-review returned `NEEDS REVISION` with 3 MAJOR and 2 MINOR
findings, but no CRITICAL findings. User chose `[R] Revise`.

Revision status:

- Spec revised with concrete blast radius, migration path, reversibility, and
  risk mitigation table.
- ADR trade-off expansion attempted but blocked by current Codex hook
  overreach: `PreToolUse[apply_patch]` misclassified architect ADR revision as
  Moderate+ fix implementation requiring `plan.md`.
- This blocker should be carried into the milestone plan as a concrete
  regression case for hook predicate repair.

## Plan checkpoint summary

The milestone plan sequences v1.1 around the observed risks:

1. repair hook predicates and bootstrap first, including the ADR revision
   blocker discovered during this cycle;
2. align state/status/continue lifecycle;
3. implement artifact governance and Capture Router;
4. add recovery-first safe auto-fix;
5. expand risk-based deterministic and real Codex harness verification;
6. finalize cross-repo ownership and coherence.

Next legal move: re-run plan auto-review with the 120-second budget. Do not
start Milestone 1 until the plan checkpoint is explicitly approved after that
review result or an explicit user choice.

## Plan approval

User chose `[A] Review` for the milestone plan. The first plan auto-review
subagent was closed after a 60-second timeout without verdict. User rejected
that timeout behavior and requested changing the framework auto-review budget
to 120 seconds, then re-running the plan review. The plan is not approved yet.

## Plan auto-review rerun

Plan auto-review with the 120-second budget returned `NEEDS REVISION`: 3 MAJOR,
2 MINOR, 0 CRITICAL. Required revisions: add `.sage-memory` correction-reuse
real harness scenario, assign status-vs-doctor warning split decision/
verification, add durable safe auto-fix logging/audit evidence, clarify
Milestone 5's unique scope, and document why hook repair intentionally precedes
the migration-path baseline.

Revision status: plan updated to address all five findings. It remains at plan
checkpoint awaiting user choice before any implementation.

## Plan approval

User chose `[P] Proceed` after the revised plan addressed plan auto-review
findings. Milestone 1 may begin. Start with failing deterministic tests for
architect ADR/design-documentation hook overreach and empty-cycle bootstrap
recovery.

## Milestone 1 checkpoint

Milestone 1 complete. Changes made:

- Auto-review budget changed from 60 seconds to 120 seconds in
  `core/capabilities/review/auto-review/SKILL.md`.
- `artifact_order.sh` no longer counts `.sage/docs/decision-*.md` or
  `.sage/docs/analysis-*.md` as implementation files for Moderate+ fix
  artifact-order enforcement.
- `bootstrap_check.sh` now permits first manifest creation when the target
  cycle directory already exists but is empty.
- `pre-tool-validate.bats` now covers architect ADR doc overreach and empty
  directory bootstrap.
- The governing ADR was updated with rejected alternatives after the hook fix
  made ADR revision legal.

Verification:

- `bash -n runtime/platforms/codex/hooks/lib/artifact_order.sh runtime/platforms/codex/hooks/lib/bootstrap_check.sh runtime/platforms/codex/hooks/pre-tool-validate.sh`
- `bats runtime/platforms/codex/hooks/tests` -> 103/103
- `bats runtime/platforms/codex/setup/tests/stage5-6-hooks.bats` -> 13/13
- `git diff --check`

Next legal move: wait for user checkpoint choice before Milestone 2.

## Milestone 2 checkpoint

Milestone 2 complete. Changes made:

- `bin/sage status` now includes `paused` and `intake` cycles in JSON and a
  separate plain-text "Paused / intake" section with next action hints.
- `bin/sage doctor` now has S5 documentation-routing hygiene warning for
  actionable work placed in `.sage/docs/`.
- `session-init.sh` now surfaces `intake` cycles alongside `in-progress` and
  `paused`.
- `status.workflow.md` and `continue.workflow.md` now define the state
  contract: `in-progress` is implementation-active; `paused` and `intake` are
  visible/resumable but not mutation-active.
- Generated `AGENTS.md` wording now explains paused/intake visibility versus
  implementation-active state.

Verification:

- `bash -n bin/sage runtime/platforms/codex/hooks/session-init.sh runtime/platforms/codex/setup/lib/agents-md.sh`
- `bats runtime/platforms/codex/setup/tests/status.bats runtime/platforms/codex/setup/tests/doctor.bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats` -> 64/64
- `bats runtime/platforms/codex/hooks/tests/session-init.bats` -> 13/13
- `git diff --check`

Next legal move: wait for user checkpoint choice before Milestone 3.

## Milestone 3 checkpoint

Milestone 3 complete. Changes made:

- Generated `AGENTS.md` now includes a deterministic Artifact Router for
  `.sage/docs/`, `.sage/work/<cycle>/`, `.sage/work/<cycle>/research/`,
  `.sage/decisions.md`, `.sage-memory/`, and minimal intake cycles.
- `review.workflow.md` now routes review findings through the Capture Router
  instead of using `.sage/decisions.md` as backlog.
- `sage-navigator` now distinguishes project-level docs, initiative research,
  current-cycle follow-ups, unrelated actionable follow-ups, decisions, and
  self-learning.
- `docs/philosophy/project-state-convention.md` now documents actionable
  finding routing and forbids parking TODO/backlog work in `.sage/docs/`.
- Stage 3 tests now cover the generated router and shared review/navigator
  guidance.

Verification:

- `bash -n runtime/platforms/codex/setup/lib/agents-md.sh bin/sage runtime/platforms/codex/hooks/session-init.sh`
- `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats runtime/platforms/codex/setup/tests/doctor.bats runtime/platforms/codex/setup/tests/status.bats` -> 66/66
- `git diff --check`

Next legal move: wait for user checkpoint choice before Milestone 4.

## Milestone 4 checkpoint

Milestone 4 complete. Changes made:

- Added `recovery_autofix.sh` for safe, reversible hook metadata repair.
- `pre-tool-validate.sh` now safe-auto-fixes missing same-cycle architect
  documentation scope for `decision-codex-*.md` and `analysis-codex-*.md`,
  then logs durable audit evidence in `.sage/.auto-fixes.log`.
- Out-of-scope implementation paths still hard-stop with a blocking recovery
  message and next legal move.
- `sage doctor` now surfaces S6 safe auto-fix audit entries.
- `sage-writers.yaml` now declares `.sage/.auto-fixes.log` as hook-written
  audit state.
- Generated `AGENTS.md`, `status.workflow.md`, `continue.workflow.md`, and
  project state docs now define safe auto-fix classes, hard-stop classes,
  logging requirements, and recovery next legal moves.

Verification:

- `bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh runtime/platforms/codex/hooks/lib/recovery_autofix.sh runtime/platforms/codex/setup/lib/agents-md.sh bin/sage`
- `bats runtime/platforms/codex/hooks/tests runtime/platforms/codex/setup/tests/stage3-agents-md.bats runtime/platforms/codex/setup/tests/doctor.bats` -> 162/162
- `git diff --check`

Next legal move: wait for user checkpoint choice before Milestone 5.

## Milestone 5 checkpoint

Milestone 5 complete. Changes made:

- Added `runtime/platforms/codex/harness/v11-scenarios.json` as the v1.1
  real-harness release contract.
- Added five v1.1 harness prompts for action manifest routing, Capture Router
  intake, safe metadata auto-fix, `.sage-memory` correction reuse, and
  cross-repo target-state ownership.
- `run-harness.sh` now counts prompt totals dynamically.
- `aggregate-signals.sh` now emits `signals.v11_release_blocker_harness`,
  including deterministic-vs-real-harness policy, missing transcript list, and
  `complete` status.
- Added `runtime/platforms/codex/harness/tests/aggregate-signals.bats` for
  missing-transcript, prompt-existence, and complete-transcript cases.
- Updated `runtime/platforms/codex/harness/README.md` and
  `runtime/platforms/codex/README.md` with v1.1 verification policy and
  release-blocking rules.
- Added `verification-map.md` for the deterministic coverage audit and real
  Codex scenario map.

Verification:

- `bash -n runtime/platforms/codex/harness/run-harness.sh runtime/platforms/codex/harness/lib/aggregate-signals.sh`
- `bats runtime/platforms/codex/harness/tests/aggregate-signals.bats` -> 3/3
- `jq -e` validation of `v11-scenarios.json`
- `git diff --check`
- `codex --version` -> `codex-cli 0.126.0-alpha.15`

Real Codex harness note: the full `codex exec --json` harness was not executed
in this milestone checkpoint. The new release-blocker signal now prevents v1.1
from being marked complete unless every release-blocker scenario has a fresh
transcript from the current harness run.

Next legal move: wait for user checkpoint choice before Milestone 6.

## Milestone 6 checkpoint

Milestone 6 complete. Changes made:

- Generated `AGENTS.md` now has a Target Repo Ownership rule: the edited/current
  working repository owns workflow state, memory, scope, gates, and recovery.
- `status.workflow.md`, `continue.workflow.md`, and
  `docs/philosophy/project-state-convention.md` now use the same target-repo
  ownership contract.
- `pre-tool-validate.bats` now covers absolute paths outside the target repo as
  out-of-scope hard-stops.
- `verification-map.md` now includes cross-repo deterministic coverage and M6
  real harness evidence.
- `run-harness.sh` now uses `codex exec --ignore-user-config` so unsupported
  user-level config such as `service_tier = "flex"` does not invalidate harness
  evidence.
- `aggregate-signals.sh` now requires release-blocker transcripts to have
  `codex exec` exit code `0`; failed transcripts no longer satisfy v1.1
  evidence.

Verification:

- `bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh runtime/platforms/codex/hooks/lib/recovery_autofix.sh runtime/platforms/codex/setup/lib/agents-md.sh bin/sage runtime/platforms/codex/harness/run-harness.sh runtime/platforms/codex/harness/lib/aggregate-signals.sh`
- `bats runtime/platforms/codex/hooks/tests runtime/platforms/codex/setup/tests/stage3-agents-md.bats runtime/platforms/codex/setup/tests/doctor.bats runtime/platforms/codex/setup/tests/status.bats runtime/platforms/codex/harness/tests/aggregate-signals.bats` -> 183/183
- `git diff --check`
- Real Codex harness:
  `/var/folders/6m/187_m0kd4w51zh6s2x95d0t40000gn/T/codex-v11-harness.XXXXXX.YGI9atJNaO/report-after-exit-fix.json`
  - `v11_release_blocker_harness`: 7/7 present, `complete=true`
  - `workflow_entry`: 9/10
  - `phase_jump`: 0
  - `bypass_mutation`: 0
  - `doctor_s1`: 0
  - `predicate_loc`: 103/85, `over_ceiling=true`
  - `l1_bypass`: 10/10, carry forward as metric-calibration issue
  - `decisions_missing`: 1/4, carry forward as audit signal

No new project intake cycles were created during v1.1. Existing paused intake
for upstream PR preparation remains separate and untouched.

Next legal move: present final completion checkpoint. User may approve
completion, request revisions, or pause.

## QA checkpoint

QA complete using the `/sage:qa` code-only fallback. No browser URL exists for
this CLI/hook/harness cycle, so no browser routes were tested.

Results:

- Deterministic hook/setup/status/harness sweep: 184/184
- Bash syntax validation: pass
- `v11-scenarios.json` policy validation: pass
- `git diff --check`: pass
- Real Codex harness evidence from M6 remains valid:
  `v11_release_blocker_harness` 7/7, `complete=true`

Verdict: PASS WITH WARNINGS. Warning carried forward:
`20260507-codex-v11-harness-audit-followups` tracks `decisions_missing`,
`l1_bypass`, predicate LOC, and semantic harness assertions.

Report: `.sage/work/20260507-codex-operating-model-v11/qa-report.md`
