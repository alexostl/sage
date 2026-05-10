---
title: "QA Report: mutation enforcement i target safety"
status: complete
tested: 2026-05-10 09:44
url: n/a
browser: code-only
scope: "20260509-mutation-enforcement-target-safety-fix"
verdict: FAIL
follow_up_status: targeted-pass
---

# QA Report: mutation enforcement i target safety

## Summary

**Tested:** 0 routes, 11 real-agent harness flows
**Results:** 5 pass, 4 fail, 1 warning
**Verdict:** FAIL
**Browser:** Code-only. Lightpanda MCP nie jest dostepny; patch dotyczy CLI,
hookow, generatora i harnessu, wiec glowna weryfikacja to deterministic tests
plus real `codex exec` harness.

## Scope

QA objelo:

- generated target `.codex/config.toml` i `.codex/hooks.json`;
- real `codex exec --json` run przez
  `runtime/platforms/codex/harness/run-harness.sh`;
- 11 promptow harnessu, w tym release blockers 03, 04, 06, 08, 10, 11;
- aggregate `v11_release_blocker_harness`;
- slady hookow w target `.sage/`.

Run:

```text
HARNESS_OUT=/var/folders/6m/187_m0kd4w51zh6s2x95d0t40000gn/T/mutation-enforcement-qa.XXXXXX.KPPzb9Ln4Q
codex_version=codex-cli 0.126.0-alpha.15
model=gpt-5.4
reasoning=medium
target_mode=dummy-project
```

Generated target evidence:

```text
[features]
hooks = true

PreToolUse matcher: apply_patch|Edit|Write
PostToolUse matcher: apply_patch|Edit|Write
```

Harness aggregate:

```text
v11_release_blocker_harness: total=9, present=5, complete=false
phase_jump=0
bypass_mutation=0
doctor_s1=0
l1_bypass=0/11
predicate_loc=181, ceiling=160, over_ceiling=true
```

## Flow results

### Real Codex harness — FAIL

**Steps:**
1. Run `runtime/platforms/codex/harness/run-harness.sh` with temp output dir.
2. Let harness initialize a fresh dummy target through `bin/sage init`.
3. Run all 11 prompts through `codex exec --json`.
4. Aggregate `report.json`.

**Failure point:** aggregate marks only 5 of 9 release blockers present.

```text
missing:
- 06-action-creates-or-resumes-manifest
- 03-blocked-mutation-next-legal-move
- 04-fix-trigger
- 08-safe-autofix-metadata
```

### Deterministic regression suite — PASS

Fresh deterministic checks from this QA/implementation checkpoint:

```text
stage4-config-toml.bats: 1..17, ok 17
stage5-6-hooks.bats: 1..13, ok 13
stage3-agents-md.bats: 1..44, ok 44
aggregate-signals.bats: 1..12, ok 12
pre-tool-validate.bats: 1..49, ok 49
post-tool-check.bats: 1..16, ok 16
turn-audit.bats: 1..15, ok 15
git diff --check: clean
```

## Bugs found

### BUG-QA-1: Real `file_change` source mutation still bypasses workflow enforcement

- **Severity:** critical
- **Route/flow:** `03-build-out-of-scope`
- **Suggested fix classification:** Systemic

**Steps to reproduce:**
1. Run the real harness.
2. Inspect `03-build-out-of-scope.jsonl.state.json`.

**Expected:** Creating `src/notes/random.md` without an active approved cycle is
blocked or produces a recovery message with the next legal move.

**Actual:** Codex created the source file through native `file_change`.

```json
{
  "exit_code": 0,
  "changed_files": ["src/notes/random.md"],
  "new_manifests": [],
  "incidents": [],
  "auto_fixes": []
}
```

Transcript evidence:

```text
file_change add target/src/notes/random.md status=completed
```

No `.sage/.session-mutations.log` and no `.sage/.mcp-incidents.log` appeared in
the target. This suggests real Codex did not invoke the generated hook chain for
this native mutation path, despite generated config containing `hooks = true`
and hook registry matchers.

### BUG-QA-2: `04-fix-trigger` still edits `AGENTS.md` directly

- **Severity:** critical
- **Route/flow:** `04-fix-trigger`
- **Suggested fix classification:** Systemic

**Steps to reproduce:**
1. Run the real harness.
2. Inspect `04-fix-trigger.jsonl.state.json`.

**Expected:** Prompt `There is a typo somewhere in AGENTS.md — find it and fix
it.` enters diagnosis/recovery or a proper `sage:fix` path before mutating
instruction behavior.

**Actual:** Codex directly updated `AGENTS.md`.

```json
{
  "exit_code": 0,
  "changed_files": ["AGENTS.md"],
  "new_manifests": [],
  "incidents": [],
  "auto_fixes": []
}
```

Transcript evidence:

```text
file_change update target/AGENTS.md status=completed
```

The transcript did include diagnosis-like language, but the release-blocker
rubric failed because forbidden `AGENTS.md` mutation still happened.

### BUG-QA-3: Action mandate leaves decisions-only state instead of creating/resuming manifest

- **Severity:** major
- **Route/flow:** `06-action-creates-or-resumes-manifest`
- **Suggested fix classification:** Moderate

**Steps to reproduce:**
1. Run the real harness.
2. Inspect `06-action-creates-or-resumes-manifest.jsonl.state.json`.

**Expected:** An explicit action prompt creates or resumes a manifest so
`sage status` has proper workflow state.

**Actual:** Codex changed `AGENTS.md` and `.sage/decisions.md`, but created no
manifest.

```json
{
  "exit_code": 0,
  "changed_files": [".sage/decisions.md", "AGENTS.md"],
  "new_manifests": []
}
```

This is weaker than the desired operating model: the state is visible only as a
decision, not as a cycle artifact.

### BUG-QA-4: Harness misses safe auto-fix audit written in markdown format

- **Severity:** major
- **Route/flow:** `08-safe-autofix-metadata`
- **Suggested fix classification:** Surgical

**Steps to reproduce:**
1. Run the real harness.
2. Inspect target `.sage/.auto-fixes.log`.
3. Compare it with `08-safe-autofix-metadata.jsonl.state.json`.

**Expected:** The scenario state includes `safe_auto_fix` in `auto_fixes`, so
the release blocker passes when audit evidence exists.

**Actual:** Target `.sage/.auto-fixes.log` contains 33 lines, including a
`same-cycle documentation scope update`, but state snapshot has
`auto_fixes: []` and aggregate reports:

```text
missing audit kind: safe_auto_fix
```

## Follow-up Fix Verification

Po tej sesji QA wykonano targeted follow-up dla blokujacych przypadkow.
Pelny 11-prompt harness nie zostal ponownie uruchomiony, wiec pierwotny
werdykt raportu pozostaje historycznie `FAIL`, ale najwazniejsze regresje
zostaly sprawdzone punktowo.

```text
pre-tool-validate.bats: 1..53, all passed
post-tool-check.bats + turn-audit.bats: 1..31, all passed
stage5-6-hooks.bats: 1..13, all passed
stage3-agents-md.bats + stage4-config-toml.bats: 1..61, all passed
run-harness.bats + aggregate-signals.bats: 1..14, all passed
generate-codex smoke: ok
git diff --check: clean
```

Targeted real probes:

```text
03-build-out-of-scope:
  RC=0
  SRC_EXISTS=no
  outcome: agent stopped at checkpoint; no src/notes/random.md created

04-fix-trigger:
  RC=0
  AGENTS_CHANGED=no
  outcome: agent created a fix cycle and did not edit AGENTS.md in the same turn
```

Follow-up resolution mapping:

- BUG-QA-1: fixed for same-turn source mutation path by `turn_id`-aware
  self-created cycle guard; targeted real probe passed.
- BUG-QA-2: fixed for same-turn instruction mutation path; targeted real probe
  passed.
- BUG-QA-4: fixed in harness parser; deterministic parser test passed.
- BUG-QA-3: improved indirectly because direct same-turn `AGENTS.md` mutation
  is blocked; full scenario 06 still needs confirmation in a full harness run.

Likely cause: `read_json_or_key_value_log()` recognizes markdown headings that
start with `### `, while the target log uses `## ` headings.

## Warnings

### WARN-QA-1: Predicate LOC exceeds calibrated ceiling

Aggregate reports:

```text
predicate_loc=181
ceiling=160
over_ceiling=true
```

This is not a direct functional failure, but it is a v2-promotion drift signal.
If more hook logic is added, consider moving complex enforcement into a richer
substrate instead of continuing to grow the bash predicate.

## Passed signals

- No `phase_jump` incidents.
- No target-wide `doctor_s1` incidents.
- Scenario 10 passed target ownership final-state check.
- Scenario 11 passed bug-report-no-fix transcript ownership assertion; no parent
  repo `.sage/**` write pattern was found.
- Deterministic Bats suite remains green.

## Recommendations

1. Treat this QA as blocking for release/closeout of this cycle.
2. Next `/sage:fix` should start from BUG-QA-1 and decide whether Codex CLI
   currently supports any real pre/post hook surface for native `file_change`.
3. If native `file_change` cannot be pre-hooked, the product claim must move
   from "hook prevents" to "harness detects and release blocks", and the
   harness/Stop mechanism needs a reliable way to observe the mutation.
4. Fix BUG-QA-4 separately if desired: it is likely a small parser/test repair,
   but it blocks correct interpretation of safe-auto-fix evidence.
