---
title: "QA Report: Codex operating model v1.1 final checkpoint"
status: complete
tested: 2026-05-07 14:37 CEST
url: n/a
browser: code-only
scope: 20260507-codex-operating-model-v11
---

# QA Report: Codex operating model v1.1 final checkpoint

## Summary

**Tested:** 0 browser routes, 4 CLI/framework verification flows
**Results:** 4 pass, 0 fail, 1 warning
**Verdict:** PASS WITH WARNINGS
**Browser:** Code-only (no browser target; this cycle changes CLI hooks,
workflow docs, generated instructions, and harness behavior)

## Route results

No browser routes were tested. Lightpanda/browser QA is not applicable to this
cycle because there is no web application URL or browser-rendered product
surface in scope.

## Flow results

### Hook/setup/status/harness deterministic sweep — PASS

**Command:**

```bash
bats runtime/platforms/codex/hooks/tests runtime/platforms/codex/setup/tests/stage3-agents-md.bats runtime/platforms/codex/setup/tests/doctor.bats runtime/platforms/codex/setup/tests/status.bats runtime/platforms/codex/harness/tests/aggregate-signals.bats
```

**Result:** 184/184 passed.

**Evidence:** Fresh run completed with final lines:

```text
ok 181 aggregate-signals: v1.1 release blocker signal reports missing transcripts
ok 182 aggregate-signals: failed codex transcript does not satisfy release blocker evidence
ok 183 aggregate-signals: every v1.1 scenario prompt exists
ok 184 aggregate-signals: v1.1 release blocker signal is complete with all transcripts
```

### Bash syntax validation — PASS

**Command:**

```bash
bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh runtime/platforms/codex/hooks/lib/recovery_autofix.sh runtime/platforms/codex/setup/lib/agents-md.sh bin/sage runtime/platforms/codex/harness/run-harness.sh runtime/platforms/codex/harness/lib/aggregate-signals.sh
```

**Result:** exit 0.

### v1.1 harness scenario policy JSON — PASS

**Command:**

```bash
jq -e '.policy.release_rule and (.scenarios | length == 7) and all(.scenarios[]; .release_blocker == true and .verification_class == "real-codex-harness")' runtime/platforms/codex/harness/v11-scenarios.json
```

**Result:** `true`.

### Diff hygiene — PASS

**Command:**

```bash
git diff --check
```

**Result:** exit 0.

### Real Codex harness evidence — WARNING

The M6 real harness run completed successfully before this QA pass:

```text
/var/folders/6m/187_m0kd4w51zh6s2x95d0t40000gn/T/codex-v11-harness.XXXXXX.YGI9atJNaO/report-after-exit-fix.json
```

Key result: `v11_release_blocker_harness` was 7/7 present with
`complete=true`.

Warning: this QA pass did not re-run the full 10-prompt `codex exec --json`
harness because it had just been run during M6 and is expensive. The QA pass
did fresh deterministic validation of the harness aggregator, including the
failed-transcript guard.

## Bugs found

No new blocking bugs found in this QA round.

## Warnings / carry-forward

### QA-W1: Harness audit signals still need a follow-up cycle

- **Severity:** warning
- **Suggested fix classification:** Moderate
- **Evidence:** Follow-up intake captured at
  `.sage/work/20260507-codex-v11-harness-audit-followups/manifest.md`.
- **Details:** M6 harness surfaced `decisions_missing` 1/4,
  `l1_bypass` 10/10, and `predicate_loc` 103/85. These do not block the v1.1
  final checkpoint because they are explicitly captured, but they should be
  fixed or calibrated before relying on those legacy signals as release gates.

## Recommendations

Approve the v1.1 final checkpoint if the current scope is acceptable. Start a
separate `/sage:fix` cycle for
`20260507-codex-v11-harness-audit-followups` before treating
`decisions_missing`, `l1_bypass`, or predicate LOC as resolved quality gates.
