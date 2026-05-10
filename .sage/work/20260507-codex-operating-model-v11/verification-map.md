---
title: "Verification Map: Codex operating model v1.1"
workflow: architect
phase: deliver
status: completed
created: 2026-05-07
updated: 2026-05-07
cycle_id: "20260507-codex-operating-model-v11"
---

# Verification Map: Codex operating model v1.1

## Policy

Use deterministic tests for framework behavior: generated instructions, hook
predicates, status/doctor output, artifact routing text, and audit log schemas.

Use real Codex harness evidence for agent/runtime behavior: workflow routing,
recovery behavior, Capture Router behavior, memory reuse across sessions, and
cross-repo state ownership.

v1.1 cannot be marked complete unless deterministic tests pass and every
release-blocker scenario in
`runtime/platforms/codex/harness/v11-scenarios.json` has a real
`codex exec --json` transcript from the current harness run with exit code `0`.

## Deterministic Coverage

| Claim | Evidence |
|---|---|
| Architect ADR/docs do not count as Moderate+ implementation | `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` |
| Empty-cycle bootstrap is recoverable | `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` |
| Paused/intake are visible but not implementation-active | `runtime/platforms/codex/setup/tests/status.bats`, `runtime/platforms/codex/hooks/tests/session-init.bats`, `runtime/platforms/codex/setup/tests/stage3-agents-md.bats` |
| Actionable docs in `.sage/docs` are diagnosed by doctor | `runtime/platforms/codex/setup/tests/doctor.bats` |
| Artifact Router and Capture Router guidance is generated consistently | `runtime/platforms/codex/setup/tests/stage3-agents-md.bats` |
| Safe auto-fix boundaries are generated consistently | `runtime/platforms/codex/setup/tests/stage3-agents-md.bats` |
| Same-cycle architect doc scope auto-fix is reversible and audited | `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` |
| Implementation out-of-scope remains hard-stop | `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` |
| `.sage/.auto-fixes.log` has declared writer ownership | `runtime/platforms/codex/hooks/tests/sage_writers.bats` |
| Doctor surfaces safe auto-fix audit entries | `runtime/platforms/codex/setup/tests/doctor.bats` |
| v1.1 harness release-blocker completeness is computed | `runtime/platforms/codex/harness/tests/aggregate-signals.bats` |
| Generated instructions define target-repo ownership | `runtime/platforms/codex/setup/tests/stage3-agents-md.bats` |
| Absolute paths outside the target repo hard-stop out of scope | `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` |

## Real Codex Harness Scenarios

Defined in `runtime/platforms/codex/harness/v11-scenarios.json`:

| Scenario | Claim |
|---|---|
| `05-readonly-no-workflow-state` | Conversational/read-only prompt does not create workflow state |
| `06-action-creates-or-resumes-manifest` | Explicit action prompt creates or resumes the correct manifest |
| `03-blocked-mutation-next-legal-move` | Blocked mutation returns a recovery message with next legal move |
| `07-capture-router-minimal-intake` | Capture Router creates minimal intake for unrelated actionable findings |
| `08-safe-autofix-metadata` | Safe auto-fix keeps a reversible metadata/state issue moving |
| `09-memory-correction-reuse` | Documentation-routing correction is captured in `.sage-memory` and reused |
| `10-cross-repo-target-state` | Cross-repo task uses the target repo's state |

## Release Interpretation

Harness failures block release claims when the changed behavior depends on
Codex following the operating model. They are advisory for unrelated text-only
changes if deterministic tests for the touched surface pass and the checkpoint
calls out that no agent/runtime behavior claim is being made.

## M6 Real Harness Evidence

Run:
`/var/folders/6m/187_m0kd4w51zh6s2x95d0t40000gn/T/codex-v11-harness.XXXXXX.YGI9atJNaO/report-after-exit-fix.json`

Summary:

| Signal | Result | Interpretation |
|---|---:|---|
| `1_workflow_entry` | 9/10 | Harness saw Sage workflow-entry text in most prompts; read-only prompt should be the likely non-entry case. |
| `2_phase_jump` | 0 | No phase-jump incidents. |
| `3_bypass_mutation` | 0 | Stop hook did not report unclaimed git diff incidents. |
| `4_doctor_s1` | 0 | No S1 doctor failures. |
| `6a_predicate_loc` | 103/85 | Predicate exceeds the historical seed ceiling; carry forward as a promotion/refactor signal, not a hidden pass. |
| `7_l1_bypass` | 10/10 | Existing L1-bypass metric does not align with current harness commit/log behavior; carry forward as metric calibration before using it as a release blocker. |
| `8_decisions_missing` | 1/4 | One frontmatter flip lacked same-commit decisions evidence; carry forward as audit signal. |
| `v11_release_blocker_harness` | 7/7 complete | All v1.1 release-blocker scenarios have successful real Codex transcripts with exit code 0. |

The v1.1 behavior-level release blocker is satisfied by the M6 harness run.
The legacy §13.2 signals still surface follow-up work around predicate size,
L1 metric calibration, and decisions-coupling audits.
