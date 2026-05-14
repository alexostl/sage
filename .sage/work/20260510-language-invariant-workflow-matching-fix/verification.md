---
title: "Verification: Batch 5 harness/incidents/language-invariant matching"
cycle_id: "20260510-language-invariant-workflow-matching-fix"
workflow: fix
phase: completion-checkpoint
status: in-progress
created: 2026-05-14
updated: 2026-05-14
---

# Verification: Batch 5 harness/incidents/language-invariant matching

## Commands

```sh
bats runtime/platforms/codex/hooks/tests/session-init.bats \
  runtime/platforms/codex/hooks/tests/post-tool-check.bats \
  runtime/platforms/codex/hooks/tests/turn-audit.bats \
  runtime/platforms/codex/hooks/tests/sage_writers.bats \
  runtime/platforms/codex/harness/tests/aggregate-signals.bats \
  runtime/platforms/codex/setup/tests/stage5-6-hooks.bats \
  runtime/platforms/codex/setup/tests/stage3-agents-md.bats
bash -n runtime/platforms/codex/hooks/session-init.sh \
  runtime/platforms/codex/hooks/turn-audit.sh \
  runtime/platforms/codex/hooks/post-tool-check.sh \
  runtime/platforms/codex/hooks/lib/dirty_state.sh
git diff --check
```

## Output

```text
1..142
ok 1 session-init.sh: prints Sage banner to stdout (smoke §15.3)
ok 14 session-init.sh: records dirty state baseline for current session
ok 23 post-tool-check.sh: decisions.md is a journal, not a frontmatter artifact
ok 24 post-tool-check.sh: capture-only sage manifest no-op emits audit event instead of claim_no_op
ok 46 turn-audit.sh: dirty file present at session start does not emit bypass when unchanged
ok 47 turn-audit.sh: dirty file changed again during session still emits bypass
ok 48 turn-audit.sh: phase_jump_observed is deduplicated for same cycle file and status
ok 57 sage-writers.yaml: .session-baseline.log writers = [session-init]
ok 71 aggregate-signals: full-autonomous scenario accepts Polish stop/escalation wording without English plan phrases
ok 78 aggregate-signals: bug-report-no-fix fails if transcript mentions parent repo .sage writes
ok 89 stage6: deploys lib/ subdir helpers
ok 142 stage3: generated AGENTS.md supports cross-cycle capture-only routing
```

`bash -n` and `git diff --check` exited with code 0 and no output.

## Coverage notes

- Dirty baseline uses `.sage/.session-baseline.log` with path fingerprint, not
  `.session-mutations.log`.
- Same-file dirty-then-bypass is covered and still emits `bypass_mutation`.
- Capture/documentation-only `.sage/**` path emits
  `capture_documentation_mutation` instead of silently suppressing
  `claim_no_op`.
- `.sage/decisions.md` no longer participates in frontmatter health checks.
- Scenario 12 no longer requires exact English phrases.
- Scenario 11 parent-repo transcript assertion remains covered.
