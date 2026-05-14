---
title: "Verification: Batch 6 subagents, approval boundary, self-learning recall"
status: completed
created: 2026-05-14
workflow: fix
cycle_id: "20260510-subagent-self-learning-recall-fix"
---

# Verification: Batch 6 subagents, approval boundary, self-learning recall

## Red Phase

Added source-level and generated-output regression tests first.

```text
1..3
not ok 1 subagent review checkpoints do not approve the next phase implicitly
#   `assert_not_contains "core/workflows/fix.workflow.md" "to verify diagnosis, then proceed"' failed
ok 2 subagent review checkpoints preserve separate approval and autonomy paths
not ok 3 auto-review prompts include targeted SageMemory recall contract
#   `assert_contains "$file" "Targeted Recall For Subagent Review"' failed
```

```text
not ok 42 stage3: generated AGENTS.md carries compact targeted subagent recall contract
#   `grep -q 'Targeted Recall For Subagent Review' "$TARGET/AGENTS.md"' failed
```

## Green Phase

```text
$ bats runtime/platforms/codex/setup/tests/subagent-review-policy.bats \
  runtime/platforms/codex/setup/tests/stage3-agents-md.bats \
  runtime/platforms/codex/setup/tests/alex-native-core-text.bats

1..58
ok 1 subagent review checkpoints do not approve the next phase implicitly
ok 2 subagent review checkpoints preserve separate approval and autonomy paths
ok 3 auto-review prompts include targeted SageMemory recall contract
...
ok 45 stage3: generated AGENTS.md carries compact targeted subagent recall contract
ok 46 stage3: generated AGENTS.md stays compact and points to skills/workflows
...
ok 58 alex-native core: templates preserve framework terms while preferring Polish prose
```

```text
$ bash develop/validators/contracts/validate-workflows.sh

── Workflow Contract Validation ──
  Found 0
0 workflows to validate

  Workflows: 0 passed, 0 failed, 0 warnings
```

Note: the workflow validator exited 0 but reported zero discovered workflows,
so the effective workflow regression coverage for this patch is the Bats
source-level test.

```text
$ bash -n runtime/platforms/codex/setup/lib/agents-md.sh && git diff --check
```

No output; command exited 0.

## Sanity Checks

Forbidden legacy approval phrases no longer appear in the source surfaces.
The only matches for those strings are the negative assertions in
`subagent-review-policy.bats`.

Generated Codex `AGENTS.md` now contains:

- `Targeted Recall Before Work`;
- `Targeted Recall For Subagent Review`;
- `sage_memory_set_project`;
- `filter_tags: ["self-learning"]`;
- `.sage-memory/self-learning.md`;
- `prevention rules`;
- explicit guidance not to run broad `sage_memory_search` as a session-start
  preload.
