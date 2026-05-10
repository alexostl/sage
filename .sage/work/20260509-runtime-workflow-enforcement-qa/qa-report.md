---
title: "QA Report: runtime workflow enforcement hardening"
status: complete
tested: 2026-05-09 22:13 CEST
url: n/a
browser: code-only
scope: "20260509-runtime-workflow-enforcement-hardening"
---

# QA Report: runtime workflow enforcement hardening

## Summary

**Tested:** 0 browser routes, 7 functional CLI/hook flows
**Results:** 13 pass, 0 fail, 1 warning
**Verdict:** PASS WITH WARNINGS
**Browser:** Code-only. Lightpanda/browser testing was not applicable because
this fix changes Sage CLI, generated instructions, shell hooks, and harness
rubrics rather than a browser application.

## Scope

QA targeted commit `37bdf28` and the closed fix cycle
`20260509-runtime-workflow-enforcement-hardening`.

Surfaces tested:

- `runtime/platforms/codex/hooks/lib/active_init.sh`
- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
- `bin/sage status`
- `runtime/platforms/codex/setup/lib/agents-md.sh`
- `runtime/platforms/codex/setup/lib/hooks-deploy.sh`
- `runtime/platforms/codex/harness/lib/aggregate-signals.sh`
- `runtime/platforms/codex/harness/v11-scenarios.json`

## Route Results

Not applicable. No web routes exist for this CLI/hook/runtime patch.

## Flow Results

### Fresh regression suite - PASS

Commands run:

```text
bats runtime/platforms/codex/hooks/tests/active_init.bats
bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
bats runtime/platforms/codex/setup/tests/status.bats
bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats
bats runtime/platforms/codex/setup/tests/stage5-6-hooks.bats
bats runtime/platforms/codex/harness/tests/aggregate-signals.bats
```

Observed output:

```text
active_init.bats: 1..15, ok 15
pre-tool-validate.bats: 1..47, ok 47
status.bats: 1..15, ok 15
stage3-agents-md.bats: 1..44, ok 44
stage5-6-hooks.bats: 1..13, ok 13
aggregate-signals.bats: 1..10, ok 10
```

### Generated AGENTS guidance - PASS

Steps:

1. Created a temporary git target.
2. Ran `generate-codex.sh --target <tmp> --preset base`.
3. Checked generated `AGENTS.md`.

Evidence:

```text
PASS generated AGENTS contains checkpoint and cross-cycle capture guidance
```

Verified that generated instructions include:

- checkpoints update `phase` and do not pause the cycle;
- cross-cycle capture must stay capture-only.

### `sage status` parked/intake guidance - PASS

Steps:

1. Seeded a temporary target with one `paused` and one `intake` cycle.
2. Ran `bin/sage status` against the temporary target.
3. Checked recovery guidance.

Evidence:

```text
PASS sage status shows parked/intake as manifest-only with sage:continue guidance
```

### No active implementation cycle recovery - PASS

Steps:

1. Seeded a temporary target with only parked work.
2. Sent an implementation `apply_patch` payload to the deployed
   `pre-tool-validate.sh`.
3. Expected a block with actionable recovery.

Evidence:

```text
PASS no active implementation blocks with sage:continue recovery
```

### Cross-cycle capture to existing intake - PASS

Steps:

1. Seeded active cycle A and intake cycle B.
2. Sent a capture-only patch for B's `manifest.md` plus `.sage/decisions.md`.
3. Checked `.sage/.session-mutations.log`.

Evidence:

```text
PASS cross-cycle capture to existing intake is allowed and attributed to intake cycle
```

### Cross-cycle capture mixed with implementation - PASS

Steps:

1. Seeded active cycle A and intake cycle B.
2. Sent a patch that updated B's manifest and added `src/nope.sh`.
3. Expected the hook to block the mixed patch.

Evidence:

```text
PASS cross-cycle capture mixed with implementation is blocked
```

### New minimal intake bootstrap while another cycle is active - PASS

Steps:

1. Seeded an active cycle.
2. Sent a patch creating a new `.sage/work/<id>/manifest.md` with
   `status: intake` plus `.sage/decisions.md`.
3. Checked `.sage/.session-mutations.log`.

Evidence:

```text
PASS new minimal intake bootstrap is allowed while another cycle is active
```

### Ambiguous multi-cycle artifact patch - PASS

Steps:

1. Seeded two `in-progress` cycles.
2. Sent a patch touching artifacts in both cycles.
3. Expected the hook to block ambiguous ownership.

Evidence:

```text
PASS ambiguous multi-cycle patch is blocked
```

## Bugs Found

No bugs found in the tested scope.

## Warnings

### WARN-1: Browser testing not applicable

- **Severity:** minor
- **Route:** n/a
- **Suggested fix classification:** n/a
- **Evidence:** This patch modifies CLI/hook/harness behavior and generated
  markdown instructions, not a browser app. `/qa` therefore used code-only and
  functional CLI smoke testing.

## Recommendations

The fix passes QA for the tested runtime/hook/status/harness surfaces.

Next useful QA target is the follow-up intake
`20260509-active-cycle-lease-lock` after its implementation, because active
session lease/lock behavior is explicitly outside this closed patch.
