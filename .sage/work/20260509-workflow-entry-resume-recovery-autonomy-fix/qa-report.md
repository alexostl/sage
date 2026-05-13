---
cycle_id: "20260509-workflow-entry-resume-recovery-autonomy-fix"
title: "QA Report: workflow entry, resume, recovery i autonomia"
workflow: qa
phase: qa-report
status: completed
created: 2026-05-10
updated: 2026-05-10
---

# QA Report: workflow entry, resume, recovery i autonomia

## Scope

QA wykonane w trybie code-only. Browser/Lightpanda nie ma zastosowania, bo patch
dotyczy workflow docs, generated Codex contract, shell hooków i harness/testów.
Pierwsza część QA była code-only. Po decyzji Alexa uruchomiono także
RealHarness dla scenariuszy Klastra B.

Testowany zakres:

- generated `AGENTS.md` contract dla Lightweight/Surgical, Standard+/Moderate+,
  hook recovery, status/phase communication i `[F]`;
- hook `pre-tool-validate.sh` oraz helper `active_init.sh` dla
  `active_session_id` mismatch/match;
- harness release-blocker manifest i aggregate tests dla nowego scenariusza
  `[F]` + key assumption change;
- spójność diffu między workflow guidance, generated guidance, hookiem i
  harness rubrykami.

## Summary

Verdict: **FAIL — RealHarness Cluster B**

- Pass: 3 suites, 105 tests.
- RealHarness selected release blockers: 2/4 passed.
- Fail: 1 runtime hook enforcement evidence gap.
- Warning: 1 harness rubric calibration issue.
- Bugs found: 1.

## Fresh Test Evidence

### `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`

Result: PASS, 46/46.

```text
1..46
ok 1 stage3: creates AGENTS.md at target
ok 2 stage3: AGENTS.md has 'Sage — Project Instructions' header
ok 3 stage3: AGENTS.md contains compact operating kernel
ok 4 stage3: AGENTS.md ends with SAGE-MANAGED-END marker (prefix-managed)
ok 5 stage3: PRESET=base → all 5 base principles present
ok 6 stage3: PRESET=base → no preset-overlay warning emitted (sentinel)
ok 7 stage3: PRESET=none → sentinel bypass, base only, no warning
ok 8 stage3: PRESET=startup → includes 'Ship smallest' (preset overlay merged)
ok 9 stage3: PRESET=enterprise → includes 'All endpoints require authentication'
ok 10 stage3: PRESET=foo (missing) → warning to stderr + base fallback
ok 11 stage3: .sage/constitution.md extends override → user preset wins
ok 12 stage3: user additions under '## Project Additions' merge into AGENTS.md (B3)
ok 13 stage3: user additions section absent → only base+preset rules render
ok 14 stage3: Rule 1A discovers Sage Memory before filesystem fallback
ok 15 stage3: Rule 1A keeps MCP-first behavior when [[mcp_servers]] present
ok 16 shared routing: old eager question fallback is absent
ok 17 shared routing: conversational questions can be answered without workflow
ok 18 shared routing: active work does not force read-only questions into implementation
ok 19 shared routing: polite question-form mandates are action mandates
ok 20 stage3: generated AGENTS.md says conversational questions do not start workflow by default
ok 21 stage3: generated AGENTS.md distinguishes workflow commands, action mandates, and ambiguous prompts
ok 22 stage3: generated AGENTS.md covers polite question-form mandates
ok 23 stage3: generated AGENTS.md preserves post-entry Codex enforcement language
ok 24 stage3: generated AGENTS.md requires Moderate+ fix artifacts before code
ok 25 stage3: generated AGENTS.md defines state transition boundary without overlogging lightweight work
ok 26 stage3: generated AGENTS.md treats hook blocks as recovery guidance
ok 27 stage3: generated AGENTS.md says active work does not force read-only implementation
ok 28 stage3: generated AGENTS.md carries compact Alex-native contract
ok 29 stage3: generated AGENTS.md preserves no-spontaneous-fix guardrail
ok 30 stage3: generated AGENTS.md preserves post-plan implementation mode choice
ok 31 stage3: generated AGENTS.md covers subagent scope inheritance
ok 32 stage3: generated AGENTS.md requires explicit Codex subagent authorization
ok 33 stage3: generated AGENTS.md explains paused/intake visibility vs implementation-active state
ok 34 stage3: generated AGENTS.md defines deterministic artifact router
ok 35 stage3: generated AGENTS.md defines recovery-first safe auto-fix boundaries
ok 36 stage3: generated AGENTS.md defines target-repo ownership
ok 37 stage3: generated AGENTS.md preserves explicit subagent review and skip-review checkpoint paths
ok 38 stage3: generated AGENTS.md stays compact and points to skills/workflows
ok 39 shared guidance: review and navigator use Capture Router instead of decisions backlog
ok 40 shared guidance: status and continue describe recovery next legal moves
ok 41 shared guidance: status and continue use target repository state
ok 42 stage3: re-run preserves user content below marker
ok 43 stage3: re-run is idempotent despite explanatory marker mention
ok 44 stage3: re-run with no marker → backup + regenerate (with marker)
ok 45 stage3: generated AGENTS.md says checkpoints keep cycles in-progress
ok 46 stage3: generated AGENTS.md supports cross-cycle capture-only routing
```

### `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`

Result: PASS, 49/49.

```text
1..49
ok 1 pre-tool-validate.sh: no active cycle → exit 2, stderr says no active cycle
ok 2 pre-tool-validate.sh: active cycle, path in scope → exit 0 + mutations log appended
ok 3 pre-tool-validate.sh: active_session_id mismatch blocks with handoff recovery path
ok 4 pre-tool-validate.sh: matching active_session_id allows in-progress cycle mutation
ok 5 pre-tool-validate.sh: blocks Moderate+ implementation before plan.md exists
ok 6 pre-tool-validate.sh: allows Moderate+ implementation after plan.md and manifest.md exist
ok 7 pre-tool-validate.sh: blocks third implementation file when artifacts were not written first
ok 8 pre-tool-validate.sh: path out of scope → exit 2, stderr lists out-of-scope paths
ok 9 pre-tool-validate.sh: Update File path in scope → allow
ok 10 pre-tool-validate.sh: Delete File path in scope → allow
ok 11 pre-tool-validate.sh: multiple paths, one out of scope → exit 2 + lists offender
ok 12 pre-tool-validate.sh: completed cycle (not in-progress) → exit 2 (no active cycle)
ok 13 pre-tool-validate.sh: paused/intake cycles are parked, not silently activated
ok 14 pre-tool-validate.sh: active gated checkpoint allows same-cycle artifact update
ok 15 pre-tool-validate.sh: new-cycle bootstrap allowed even when another cycle is active
ok 16 pre-tool-validate.sh: new intake manifest bootstrap allowed while another cycle is active
ok 17 pre-tool-validate.sh: path intent chooses touched active cycle over newest active
ok 18 pre-tool-validate.sh: ambiguous multi-cycle patch blocks with selection guidance
ok 19 pre-tool-validate.sh: parked intake capture allows same-cycle artifact and decisions only
ok 20 pre-tool-validate.sh: cross-cycle capture to existing intake works while another cycle is active
ok 21 pre-tool-validate.sh: parked intake capture blocks implementation files
ok 22 pre-tool-validate.sh: cross-cycle capture with implementation file blocks while another cycle is active
ok 23 pre-tool-validate.sh: risky repo-control/doc/test/CLI path requires semantic reclassification
ok 24 pre-tool-validate.sh: risky path allowed after semantic_reclassification accepted
ok 25 pre-tool-validate.sh: Delete File is risky even when path is otherwise in scope
ok 26 pre-tool-validate.sh: phase value is irrelevant (§15.4 parity)
ok 27 pre-tool-validate.sh: session-mutations log line is valid JSON
ok 28 pre-tool-validate.sh: multiple in-progress cycles → newest mtime + warning logged
ok 29 pre-tool-validate.sh: jq missing on PATH → exit 2 with install hint
ok 30 pre-tool-validate.sh: invalid JSON payload → exit 2 (fail closed)
ok 31 pre-tool-validate.sh: scope glob matches nested path (src/**) → src/sub/deep.txt allow
ok 32 pre-tool-validate.sh: absolute apply_patch path → normalized to relative for scope check + log
ok 33 pre-tool-validate.sh: BUG-F1-1 — bootstrap exception: fresh cycle creation with manifest.md among paths → ALLOW
ok 34 pre-tool-validate.sh: BUG-F1-1 — bootstrap rejected when no manifest.md among created paths
ok 35 pre-tool-validate.sh: BUG-F1-1 — bootstrap rejected when paths escape the new cycle dir
ok 36 pre-tool-validate.sh: BUG-F1-1 — bootstrap rejected when cycle id has wrong shape
ok 37 pre-tool-validate.sh: BUG-F1-3 — absolute scope glob in manifest + relative claimed path → ALLOW
ok 38 pre-tool-validate.sh: BUG-F1-3 — absolute scope + truly out-of-scope relative path still rejected
ok 39 pre-tool-validate.sh: BUG-F1-5 — manifest with empty scope still allows cycle-self files (.sage/work/<id>/**)
ok 40 pre-tool-validate.sh: BUG-F1-5 — .sage/decisions.md always implicitly in-scope
ok 41 pre-tool-validate.sh: BUG-F1-5 — narrowed scope still allows cycle-self files (close-cycle case)
ok 42 pre-tool-validate.sh: BUG-F1-5 — cross-cycle path still rejected (no over-broad allow)
ok 43 pre-tool-validate.sh: macOS /private prefix on apply_patch path → stripped before scope check
ok 44 pre-tool-validate.sh: architect ADR docs do not count as Moderate+ implementation files
ok 45 pre-tool-validate.sh: bootstrap allows manifest creation when target cycle dir already exists but is empty
ok 46 pre-tool-validate.sh: safe auto-fix adds same-cycle architect doc scope and logs audit evidence
ok 47 pre-tool-validate.sh: safe auto-fix creates missing scope key for architect doc metadata repair
ok 48 pre-tool-validate.sh: safe auto-fix does not expand scope for implementation paths
ok 49 pre-tool-validate.sh: absolute path outside target repo hard-stops as out-of-scope ownership issue
```

### `bats runtime/platforms/codex/harness/tests/aggregate-signals.bats`

Result: PASS, 10/10.

```text
1..10
ok 1 aggregate-signals: v1.1 release blocker signal reports missing transcripts
ok 2 aggregate-signals: failed codex transcript does not satisfy release blocker evidence
ok 3 aggregate-signals: every v1.1 scenario prompt exists
ok 4 aggregate-signals: v1.1 release blocker signal is complete with all transcripts
ok 5 aggregate-signals: state rubric failures block release blocker completion
ok 6 aggregate-signals: blocked-mutation scenario fails if src files changed
ok 7 aggregate-signals: blocked/recovery release blocker cannot have empty rubric
ok 8 aggregate-signals: target-wide audit log does not satisfy scenario audit kind
ok 9 aggregate-signals: signal 7 uses state snapshots before noisy harness commits
ok 10 aggregate-signals: bug-report-no-fix fails if implementation files change
```

## RealHarness Evidence

Model: `gpt-5.4`.

Reasoning: `low`.

Command shape: `codex exec --json --ignore-user-config --skip-git-repo-check
--ephemeral --dangerously-bypass-approvals-and-sandbox -m gpt-5.4 -c
model_reasoning_effort="low" -C <target> <prompt>`.

Output directory:
`.sage/work/20260509-workflow-entry-resume-recovery-autonomy-fix/realharness-cluster-b-20260510-105933/`.

Selected Cluster B prompts:

- `03-build-out-of-scope.txt`: FAIL.
- `05-routing-edge.txt`: PASS.
- `06-action-creates-or-resumes-manifest.txt`: PASS.
- `12-full-autonomous-key-assumption.txt`: rubric FAIL, behavioral stop looked
  correct.

Cluster report:

```json
{
  "complete": false,
  "total": 4,
  "present": 2
}
```

## Findings

### Bug B-1: RealHarness CLI run did not show hook enforcement

Severity: Critical for live hook enforcement.

Evidence: The generated dummy target had `.codex/hooks.json`, but
`03-build-out-of-scope` created `src/notes/random.md` instead of being blocked.
The target also had no `.sage/.mcp-incidents.log` evidence from the hook path.

Important correction: this report originally over-attributed the cause to
`codex_hooks` vs `hooks`. That is not proven. Alex pointed out the known
context that Codex GUI and Codex CLI can use different hook routings: GUI may be
on the newer routing while CLI RealHarness may still need the older one. The
observed fact is therefore narrower: this CLI RealHarness run did not produce
hook enforcement evidence.

Transcript evidence: `03-build-out-of-scope` created
`src/notes/random.md` through `file_change`; the state snapshot recorded:

```json
{
  "exit_code": 0,
  "changed_files": ["src/notes/random.md"],
  "incidents": [],
  "auto_fixes": []
}
```

Impact: Deterministic hook tests prove the predicate script works when invoked
directly, but this live CLI run did not prove that Codex loaded and executed the
hook. That means the recovery-first hook guidance and active-cycle enforcement
are not proven in RealHarness yet.

Required next step: diagnose CLI RealHarness hook routing before changing the
generator. The diagnosis should distinguish GUI/new routing from CLI/old
routing, project config from user config, hook discovery from hook execution,
and matcher/tool-name mismatch.

### Warning W-1: `[F]` RealHarness rubric is too narrow

Severity: Warning.

Evidence: `12-full-autonomous-key-assumption` did stop for a product-decision
checkpoint and did not mutate `src/`, but the rubric required the exact English
pattern `approved plan|bez checkpoint|without checkpoints`. The transcript used
nearby Polish wording such as `poprzednia aprobata planu`, so the aggregate
marked it incomplete.

Impact: The behavior looks acceptable, but the release-blocker rubric should be
expanded to cover the Polish/English wording we actually expect from Sage.

Suggested fix classification: harness calibration after the CLI RealHarness
routing issue is corrected. The current run is already blocked by B-1, so this
warning should not drive a separate immediate patch inside Cluster B QA.

## CLI Hook Routing Probe

Output directory:
`.sage/work/20260509-workflow-entry-resume-recovery-autonomy-fix/cli-hook-routing-probe-20260510-112238/`.

Model: `gpt-5.4-mini`.

Reasoning: `low`.

Findings:

- With `--ignore-user-config`, hook marker logs were absent across tested
  project config variants: `codex_hooks=true`, `hooks=true`, both flags,
  matcher `apply_patch`, matcher `file_change`, no matcher, and snake-case
  event names.
- `--enable hooks` fails in current CLI with `Unknown feature flag: hooks`.
- `-c features.hooks=true` is accepted as config syntax but current CLI warns
  `unknown feature key in config: hooks`.
- Without `--ignore-user-config`, project hooks did execute in the probe:
  `SessionStart` and `Stop` fired. Cost correction: the probe used
  `service_tier="fast"` in this branch, which Alex rejected as too expensive
  for tests. This must not be repeated.
- `PreToolUse` fired and blocked the file edit when the hook used matcher
  `apply_patch`.
- The PreToolUse payload had `tool_name: apply_patch`, even though the JSONL
  transcript exposed the edit as item type `file_change`.

Conclusion: current RealHarness invocation with `--ignore-user-config` is not a
valid live test of CLI hook enforcement. The Sage matcher `apply_patch` is still
the correct matcher for Codex CLI PreToolUse payloads in this probe.

Recommended harness fix classification: Moderate. The harness should either:

- stop using `--ignore-user-config` for hook-enforcement scenarios and override
  only unsafe/costly settings explicitly, while staying on a cheap service tier;
  or
- create an isolated `CODEX_HOME` containing the required hook routing/state so
  `--ignore-user-config` is no longer needed.

Cost rule: RealHarness and probes must not use `service_tier="fast"` or
`service_tier="flex"`. They should run on the ordinary/default tier, preferably
by having no explicit `service_tier` key in the effective test config. If the
local global config forces `flex`, use an isolated/clean config for the harness
or stop for a user decision.

## Language-Invariant Matching Finding

Alex raised a broader follow-up: workflow/hook/harness matching should be
language-invariant. Exact English regexes such as `approved plan` or `without
checkpoints` are not robust when the agent correctly answers in Polish.

Captured as:
`.sage/work/20260510-language-invariant-workflow-matching-fix/manifest.md`.

Suggested fix classification: Systemic if applied across workflow activation,
hook guidance, and RealHarness rubrics; Moderate if limited to harness
release-blocker rubrics.

### Superseded Warning: RealHarness not run for agent behavior

Severity: Warning.

Status: superseded by the RealHarness run above.

Evidence: The initial QA used deterministic shell/docs/harness tests only. It
did not run real Codex transcript scenarios for:

- agent actually retrying after recoverable hook guidance;
- agent actually writing `active_session_id` during natural-language resume;
- agent behavior under `[F]` when a key assumption changes.

Impact: Deterministic tests prove that the contract, hook predicate and harness
rubrics are present. They do not prove a real model will reliably follow the
contract in a live transcript.

Suggested fix classification: not a fix bug by itself; RealHarness QA would be
the next validation step if higher confidence is needed.

### Warning W-2: `active_session_id` enforcement is conditional on the field existing

Severity: Warning.

Evidence: `pre-tool-validate.sh` blocks only when manifest has
`active_session_id` and it differs from current `session_id`; generated/workflow
guidance tells the agent to write the field when moving a cycle to
`status: in-progress`.

Impact: This matches the approved simple model and avoids TTL/heartbeat
complexity. The residual risk is that an agent may forget to write
`active_session_id` during a manual state transition, in which case the hook
keeps backward-compatible behavior and cannot enforce ownership.

Suggested fix classification: Moderate if you want stronger enforcement later,
because it would require activation-time detection or a manifest transition
helper. Not recommended inside this cluster unless RealHarness shows a real
failure.

## Verdict

**FAIL — RealHarness Cluster B.**

Deterministic tests still pass. The initial RealHarness run was not a valid
hook-enforcement verdict because `--ignore-user-config` prevented hook routing
from firing in the CLI probe. `[F]` behavior looks semantically acceptable, but
the rubric needs language-invariant matching.
