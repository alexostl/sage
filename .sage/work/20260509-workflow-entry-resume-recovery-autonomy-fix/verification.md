---
cycle_id: "20260509-workflow-entry-resume-recovery-autonomy-fix"
title: "Verification: workflow entry, resume, recovery i autonomia"
workflow: fix
phase: verification
status: completed
created: 2026-05-10
updated: 2026-05-10
---

# Verification

## Commands

### `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`

Result: PASS.

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

Result: PASS.

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

Result: PASS.

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

### `rg -n "Lightweight|Surgical|Standard\\+|active_session_id|Full autonomous|status/phase|recoverable hook|Next legal move" core runtime/platforms/codex`

Result: PASS. Key terms are present in workflow guidance, generated Codex
contract, hook implementation, hook tests, and harness scenario manifest.

## Notes

- `stage3-agents-md.bats` initially failed because a grep expected an unwrapped
  phrase. The assertion was narrowed to match generated line wrapping; rerun
  passed.
- No browser QA applies; this patch is workflow/runtime/test text and shell
  logic only.
