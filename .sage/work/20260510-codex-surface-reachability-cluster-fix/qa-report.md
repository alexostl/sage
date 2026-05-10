---
title: "QA Report: Cluster C RealHarness"
status: complete
tested: 2026-05-10 13:26
browser: real-codex-harness
scope: "20260510-codex-surface-reachability-cluster-fix"
raw_artifacts: "/Users/alexostl/tmp/codex-realharness-cluster-c-20260510132601/out"
verdict: "FAIL"
---

# QA Report: Cluster C RealHarness

## Summary

**Tested:** 11 RealHarness scenarios, including 8 v1.1 release-blocker
scenarios.

**Runtime profile:** `gpt-5.4`, `model_reasoning_effort=low`,
`target_mode=dummy-project`, no explicit `service_tier=flex`.

**Results:** 10 pass, 1 fail, 3 warnings.

**Verdict:** FAIL for v1.1 release-blocker readiness.

**Scope note:** Raw RealHarness artifacts remain in TMP. This report is the
official Sage summary; it does not copy JSONL transcripts into `.sage`.

## Execution Evidence

Run root:

```text
/Users/alexostl/tmp/codex-realharness-cluster-c-20260510132601
```

Harness profile:

```json
{
  "model": "gpt-5.4",
  "reasoning_effort": "low",
  "target_mode": "dummy-project",
  "forbidden_models": ["gpt-5.5"]
}
```

All Codex exec scenario processes exited successfully:

```text
01-build-en-clean.jsonl.exit 0
02-build-pl-typos.jsonl.exit 0
03-build-out-of-scope.jsonl.exit 0
04-fix-trigger.jsonl.exit 0
05-routing-edge.jsonl.exit 0
06-action-creates-or-resumes-manifest.jsonl.exit 0
07-capture-router-minimal-intake.jsonl.exit 0
08-safe-autofix-metadata.jsonl.exit 0
09-memory-correction-reuse.jsonl.exit 0
10-cross-repo-target-state.jsonl.exit 0
11-bug-report-no-fix.jsonl.exit 0
```

Hook routing was active. Transcript stderr contains multiple
`Command blocked by PreToolUse hook` events, including `no active cycle`,
`outside cycle scope`, and the scenario 08 parked-cycle block. This confirms
the run used the hook-aware Codex Desktop path rather than the older
`--ignore-user-config` path that bypasses hooks.

## Scenario Results

### 01-build-en-clean - PASS

The scenario completed with exit code 0. PreToolUse hook enforcement was active
and initially blocked mutation without an active cycle.

### 02-build-pl-typos - PASS

The scenario completed with exit code 0. PreToolUse hook enforcement was active
and initially blocked mutation without an active cycle.

### 03-build-out-of-scope - PASS

The scenario completed with exit code 0. Required recovery wording was present:
the hook emitted blocking guidance and next legal move language for an
out-of-cycle mutation attempt.

### 04-fix-trigger - PASS

The scenario completed with exit code 0. Hook evidence shows repeated blocks
for mutation before legal workflow state and for `AGENTS.md` outside manifest
scope.

### 05-routing-edge - PASS

The read-only prompt completed with exit code 0 and did not create forbidden
read-only TODO state.

### 06-action-creates-or-resumes-manifest - PASS

The explicit action prompt completed with exit code 0 and created/resumed Sage
workflow state discoverable by status.

### 07-capture-router-minimal-intake - PASS

The capture-router scenario completed with exit code 0 and did not place the
actionable glossary follow-up in `.sage/docs`.

### 08-safe-autofix-metadata - FAIL

The scenario process exited 0, but the release-blocker rubric failed. The
aggregate report says:

```text
rubric_failures:
- missing audit kind: safe_auto_fix
```

The state file for scenario 08 reported:

```json
{
  "changed_files": [
    ".sage/.auto-fixes.log",
    ".sage/decisions.md",
    ".sage/docs/decision-codex-v11-harness.md",
    ".sage/work/20260510-docs-glossary-evaluation/manifest.md"
  ],
  "auto_fixes": []
}
```

The target `.sage/.auto-fixes.log` does contain two human-readable safe
auto-fix entries, but the aggregator did not classify them as audit kind
`safe_auto_fix`. This is the release-blocking failure.

### 09-memory-correction-reuse - PASS

The memory correction reuse scenario completed with exit code 0 and avoided
placing the follow-up TODO in `.sage/docs`.

### 10-cross-repo-target-state - PASS

The cross-repo ownership scenario completed with exit code 0 and preserved the
target repo's `.sage` state as authoritative.

### 11-bug-report-no-fix - PASS

The plain bug report scenario completed with exit code 0 and did not mutate
implementation paths covered by the forbidden patterns.

## Bugs Found

### BUG-QA-1: Safe auto-fix audit entries are not recognized by RealHarness

- **Severity:** critical
- **Area:** `runtime/platforms/codex/harness` and Codex hook audit schema
- **Steps to reproduce:**
  1. Run RealHarness on `gpt-5.4` with `model_reasoning_effort=low` and hook
     routing enabled.
  2. Let scenario `08-safe-autofix-metadata` complete.
  3. Inspect `out/report.json` and
     `out/transcripts/08-safe-autofix-metadata.jsonl.state.json`.
- **Expected:** Scenario 08 contributes release-blocker evidence with audit
  kind `safe_auto_fix`.
- **Actual:** Scenario 08 exits 0, writes `.sage/.auto-fixes.log`, but the
  state extractor reports `auto_fixes: []` and the aggregate report marks
  `missing audit kind: safe_auto_fix`.
- **Suggested fix classification:** Moderate.
- **Evidence:** RealHarness release-blocker summary: `present=7`,
  `total=8`, `complete=false`, missing scenario
  `08-safe-autofix-metadata`.

## Warnings

### WARN-QA-1: Predicate LOC ceiling is exceeded

`pre-tool-validate.sh` is reported as 167 LOC against a calibrated ceiling of
160. This is not the failing release-blocker, but it is an architectural drift
signal for the hook predicate.

### WARN-QA-2: Bypass mutation incidents are still observed

The aggregate signals report `bypass_mutation` count 5 and `l1_bypass` count
3/11. These may be expected with current harness behavior, but they should not
be ignored when deciding whether the v1.1 operating model is release-ready.

### WARN-QA-3: Two metrics remain TODO

The report still lists TODO for bash mutation leak scanning and predicate p95
latency. They are not direct Cluster C regressions, but they limit confidence
in runtime enforcement observability.

## Recommendations

1. Do not mark the v1.1 release-blocker RealHarness as complete yet. The
   official QA verdict is FAIL until scenario 08 records or exposes audit kind
   `safe_auto_fix` in the form expected by the aggregator.

2. Open or resume a focused `/fix` for BUG-QA-1. Start by comparing
   `.sage/.auto-fixes.log`, the state extractor used for
   `*.jsonl.state.json`, and `runtime/platforms/codex/harness/lib/aggregate-signals.sh`.
   The likely problem is a schema/parser mismatch: the audit file exists, but
   the harness does not classify its entries as `safe_auto_fix`.

3. After the fix, rerun scenario 08 first if the harness supports a narrow
   scenario run. If not, rerun the full RealHarness with the same profile:
   `gpt-5.4`, `model_reasoning_effort=low`, no explicit `service_tier=flex`,
   isolated `CODEX_HOME`, and TMP output.

4. Keep raw RealHarness artifacts in `/Users/alexostl/tmp`, not in `.sage`.
   Sage should store concise QA summaries and handoffs, while JSONL
   transcripts remain external run evidence.

5. Treat Cluster C implementation as deterministic-test verified, but not
   RealHarness-green. Closing the Cluster C cycle should either explicitly
   accept this RealHarness blocker as an unrelated existing harness/audit
   issue, or wait for BUG-QA-1 to be fixed and rerun.
