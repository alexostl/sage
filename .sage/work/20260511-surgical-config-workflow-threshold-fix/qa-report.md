---
title: "QA Report: pojedyncza zmiana config nie wymusza Sage workflow"
status: complete
approved: 2026-05-13
approved_by: alexostl
retested: 2026-05-13
tested: 2026-05-13 18:38
url: n/a
browser: code-only
scope: 20260511-surgical-config-workflow-threshold-fix
---

# QA Report: pojedyncza zmiana config nie wymusza Sage workflow

## Summary

**Tested:** 0 routes, 4 code flows
**Results:** 4 pass, 0 fail, 0 warning
**Verdict:** PASS
**Browser:** Code-only. Lightpanda MCP was not available in this session, and
the change under test is a Codex hook/generator path rather than a web UI.

## Test Scope

Routes to test: none. This cycle does not modify a browser application.

Flows to test:

1. PreToolUse allows a single top-level `config/*.toml` Add/Update without an
   active implementation cycle, even when paused/intake cycles exist.
2. PreToolUse still blocks multi-file config edits, `.codex/**`, deletes,
   nested config paths, and high-risk config basenames.
3. Stop/turn-audit accepts the empty-cycle mutation log produced by the
   lightweight config allowance without a false `bypass_mutation`.
4. Generated `AGENTS.md` and `.codex/config.toml` guidance no longer states
   unconditionally that every config change requires workflow.

Acceptance criteria verified:

- Single-file `config/codex-config.toml` update passes and writes
  `cycle_id:""` to `.sage/.session-mutations.log`.
- Risky config shapes remain blocked.
- Generated guidance preserves workflow requirements for
  source/runtime/test/instruction while calibrating config changes.
- No old generated guidance phrase remains in the generator outputs/tests.

## Route Results

No browser routes tested. Not applicable for this hook/runtime cycle.

## Flow Results

### PreToolUse lightweight config path — PASS

**Steps:**

1. Run Bats regression for parked cycles plus one
   `config/codex-config.toml` update -> expected exit `0` -> actual pass.
2. Verify mutation log contains `config/codex-config.toml` and empty
   `cycle_id` -> expected audit trail -> actual pass.

**Evidence:**

```text
ok 23 pre-tool-validate.sh: lightweight single top-level config update allowed with parked cycles
ok 29 pre-tool-validate.sh: lightweight single config file_change update allowed without active cycle
```

### PreToolUse negative boundaries — PASS

**Steps:**

1. Run Bats cases for two config files, `.codex/config.toml`, delete,
   denylisted basenames, nested config path, and multi-file `file_change`.
2. Expect exit `2` with existing no-active-cycle block semantics.

**Evidence:**

```text
ok 24 pre-tool-validate.sh: lightweight config allowance rejects two config files without active cycle
ok 25 pre-tool-validate.sh: lightweight config allowance rejects .codex/config.toml
ok 26 pre-tool-validate.sh: lightweight config allowance rejects delete
ok 27 pre-tool-validate.sh: lightweight config allowance rejects high-risk config basenames
ok 28 pre-tool-validate.sh: lightweight config allowance rejects nested config path
ok 30 pre-tool-validate.sh: lightweight config file_change rejects multi-file config change
ok 31 pre-tool-validate.sh: lightweight config file_change rejects high-risk basename
```

### Stop/turn-audit integration — PASS

**Steps:**

1. Create a temporary git repo with committed `config/codex-config.toml`.
2. Add a parked paused cycle.
3. Run `pre-tool-validate.sh` with a single config update payload.
4. Simulate the file mutation.
5. Run `turn-audit.sh` for the same session.

**Evidence:**

```text
--- mutation log ---
{"session_id":"qa-session","turn_id":"turn-1","ts":"2026-05-13T16:37:58Z","cycle_id":"","files":["config/codex-config.toml"]}
--- incidents ---
none
```

Additional fresh regression:

```text
bats runtime/platforms/codex/hooks/tests/turn-audit.bats
1..16
ok 16 turn-audit.sh: plan+manifest before Moderate+ implementation -> no artifact_order_violation
```

### Generated guidance — PASS

**Steps:**

1. Run Stage 3 and Stage 4 generator tests.
2. Confirm assertions now check `source/runtime/test/instruction` and
   `single-file config-only` calibration instead of the old unconditional
   `source/runtime/test/config/instruction` rule.

**Evidence:**

```text
bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats
1..47
ok 47 stage3: generated AGENTS.md supports cross-cycle capture-only routing

bats runtime/platforms/codex/setup/tests/stage4-config-toml.bats
1..17
ok 17 stage4: missing markers -> backup + regenerate
```

## Bugs Resolved

### BUG-1: Stale same-turn guard wording still mentions config as workflow-only boundary — RESOLVED

- **Severity:** minor
- **Route:** n/a
- **File:** `runtime/platforms/codex/hooks/pre-tool-validate.sh`
- **Steps to reproduce:**
  1. Search hook/guidance text for old config-boundary wording.
  2. Observe the same-turn guard error text still contains
     `source/runtime/test/config/instruction files`.
- **Expected:** Runtime-facing guidance should match the new calibrated
  contract: source/runtime/test/instruction are workflow boundaries; config is
  calibrated by the structural allowlist.
- **Actual:** The hook's same-turn guard message still includes `config` in the
  old phrase. This does not block the new config allowlist because that guard
  is reached only for implementation boundary paths, but the wording can still
  steer agents toward the old mental model.
- **Suggested fix classification:** Surgical
- **Evidence:**

```text
runtime/platforms/codex/hooks/pre-tool-validate.sh:248:
... not approval to edit source/runtime/test/config/instruction files ...
```

**Resolution:** Fixed in-cycle after QA approval. The same-turn guard message
now says `source/runtime/test/instruction files` and explicitly notes that
config changes are calibrated separately by the lightweight structural
allowlist.

**Retest evidence:**

```text
ok 14 pre-tool-validate.sh: same-turn manifest cannot authorize source file_change
```

## Fresh Verification Commands

```text
bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
1..67
ok 67 pre-tool-validate.sh: absolute path outside target repo hard-stops as out-of-scope ownership issue

bats runtime/platforms/codex/hooks/tests/turn-audit.bats
1..16
ok 16 turn-audit.sh: plan+manifest before Moderate+ implementation -> no artifact_order_violation

bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats
1..47
ok 47 stage3: generated AGENTS.md supports cross-cycle capture-only routing

bats runtime/platforms/codex/setup/tests/stage4-config-toml.bats
1..17
ok 17 stage4: missing markers -> backup + regenerate
```

```text
bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh
bash -n runtime/platforms/codex/hooks/turn-audit.sh
bash -n runtime/platforms/codex/setup/lib/agents-md.sh
bash -n runtime/platforms/codex/setup/lib/config-toml.sh
git diff --check
```

All syntax/diff checks exited `0` with no output.

## Recommendations

The implementation is functionally ready and the QA warning has been resolved.
No browser claim is made; this was code-only QA by workflow fallback.

## Approval

Approved by Alex on 2026-05-13.
