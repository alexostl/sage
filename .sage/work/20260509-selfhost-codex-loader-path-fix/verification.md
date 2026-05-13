---
cycle_id: "20260509-selfhost-codex-loader-path-fix"
title: "Verification: Batch 4 Codex surface reachability"
workflow: fix
phase: completion-checkpoint
status: completed
created: 2026-05-13
updated: 2026-05-13
---

# Verification: Batch 4 Codex surface reachability

## Commands

```text
bats runtime/platforms/codex/setup/tests/stage7-skills.bats
1..12
ok 1 stage7: creates .agents/skills/ directory
ok 2 stage7: deploys 15 workflow loader skills
ok 3 stage7: every public workflow has a loader stub
ok 4 stage7: each SKILL.md has name field matching sage:<wf>
ok 5 stage7: each SKILL.md has non-empty description (≤300 chars)
ok 6 stage7: SKILL.md body references the source workflow path
ok 7 stage7: does not generate duplicate sage:sage workflow loader
ok 8 stage7: deploys public sage router with target-repo navigator path
ok 9 stage7: deploys sage-navigator from core source
ok 10 stage7: selfhost target uses framework-root paths
ok 11 stage7: re-run produces identical output (idempotent)
ok 12 stage7: fails when SAGE_FRAMEWORK invalid
```

```text
bats runtime/platforms/codex/setup/tests/stage4-config-toml.bats
1..17
ok 1 stage4: creates .codex/config.toml at target
ok 2 stage4: config.toml has SAGE MANAGED BLOCK START marker
ok 3 stage4: config.toml has SAGE MANAGED BLOCK END marker
ok 4 stage4: config.toml contains 'hooks = true' inside [features]
ok 5 stage4: v1 config.toml does NOT contain [[mcp_servers]] block
ok 6 stage4: config.toml contains top-level developer_instructions field
ok 7 stage4: developer_instructions carries Alex-native compact enforcement
ok 8 stage4: [history] block does not contain developer_instructions
ok 9 stage4: [history] block has 'persistence' field (Codex 0.126 requires it)
ok 10 stage4: config.toml parses as valid TOML (yq -p toml)
ok 11 stage4: config.toml parses with strict tomllib when available
ok 12 stage4: re-run preserves user content above START marker
ok 13 stage4: re-run preserves user content below END marker
ok 14 stage4: re-run removes legacy postlude [features] fallback with only codex_hooks
ok 15 stage4: re-run fails instead of deleting user-owned [features] keys
ok 16 stage4: re-run fails on duplicate user-owned [history] table
ok 17 stage4: missing markers → backup + regenerate
```

```text
bats runtime/platforms/codex/setup/tests/stage10-tighten.bats
1..14
ok 1 stage10: passes on a fully generated target (3→9a then 10)
ok 2 stage10: fails when gates scripts dir is missing (src has scripts)
ok 3 stage10: fails when gates scripts dir is empty (src has scripts)
ok 4 stage10: fails when gates scripts count mismatches source
ok 5 stage10: empty source preset → info message, ok
ok 6 stage10: PASSED output includes a summary section
ok 7 stage10: summary mentions AGENTS.md
ok 8 stage10: summary mentions hooks (count or names)
ok 9 stage10: summary reports hooks=true and not codex_hooks=true
ok 10 stage10: summary mentions skills loaders
ok 11 stage10: summary mentions gates
ok 12 stage10: summary mentions constitution preset
ok 13 stage10: B1 still enforced — missing Sage Memory discovery/fallback wording → fail
ok 14 stage10: B3 still enforced — missing extends: in constitution → fail
```

```text
bash runtime/mcp/tests/run-regression.sh
== json_to_toml scaffold uses current hooks feature flag ==

== summary ==
PASS: MCP regression checks
```

```text
targeted selfhost checks
OK_no_sage_sage
OK_selfhost_loader_paths
OK_navigator_synced
OK_router_navigator_path
OK_hooks_true
OK_no_active_codex_hooks
```

```text
git diff --check
# no output
```
