---
cycle_id: "20260511-surgical-config-workflow-threshold-fix"
title: "Verification: pojedyncza zmiana config nie wymusza Sage workflow"
workflow: fix
phase: completion-gate
status: passed
created: 2026-05-13
updated: 2026-05-13
qa_follow_up_verified: 2026-05-13
---

# Verification

## Commands

```text
bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
bats runtime/platforms/codex/hooks/tests/active_init.bats
bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats
bats runtime/platforms/codex/setup/tests/stage4-config-toml.bats
bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh
bash -n runtime/platforms/codex/hooks/lib/active_init.sh
git diff --check
rg -n "source/runtime/test/config/instruction|Source/runtime/test/config|config/instruction behavior changes" core/constitution/sage-process.constitution.md runtime/platforms/codex/setup/lib/agents-md.sh runtime/platforms/codex/setup/lib/config-toml.sh runtime/platforms/codex/setup/tests/stage3-agents-md.bats runtime/platforms/codex/setup/tests/stage4-config-toml.bats
```

## Actual Output

```text
1..67
ok 23 pre-tool-validate.sh: lightweight single top-level config update allowed with parked cycles
ok 24 pre-tool-validate.sh: lightweight config allowance rejects two config files without active cycle
ok 25 pre-tool-validate.sh: lightweight config allowance rejects .codex/config.toml
ok 26 pre-tool-validate.sh: lightweight config allowance rejects delete
ok 27 pre-tool-validate.sh: lightweight config allowance rejects high-risk config basenames
ok 28 pre-tool-validate.sh: lightweight config allowance rejects nested config path
ok 29 pre-tool-validate.sh: lightweight single config file_change update allowed without active cycle
ok 30 pre-tool-validate.sh: lightweight config file_change rejects multi-file config change
ok 31 pre-tool-validate.sh: lightweight config file_change rejects high-risk basename
ok 67 pre-tool-validate.sh: absolute path outside target repo hard-stops as out-of-scope ownership issue

1..15
ok 15 resolve_cycle_for_patch: parked capture path beats unrelated active cycle

1..47
ok 37 stage3: generated AGENTS.md defines target-repo ownership
ok 47 stage3: generated AGENTS.md supports cross-cycle capture-only routing

1..17
ok 7 stage4: developer_instructions carries Alex-native compact enforcement
ok 17 stage4: missing markers -> backup + regenerate
```

`bash -n` commands exited `0` with no output.

`git diff --check` exited `0` with no output.

The old unconditional guidance search exited `1` with no matches, which is the
expected result for `rg` when no old phrase remains.

## Result

Passed.

## QA Follow-Up Verification

After the approved QA report, the minor same-turn guard wording warning was
fixed in-cycle and retested.

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
git diff --check
```

All checks exited `0`. Search for
`source/runtime/test/config/instruction` now returns only the negative
assertion in `pre-tool-validate.bats`.
