#!/usr/bin/env bats
# T1.11 — Stage 3 AGENTS.md composition contract.
#
# Plan contract (T1.11):
#   - Prefix-managed pattern with `<!-- SAGE-MANAGED-END -->` marker
#   - 3-layer constitution merge (base → preset overlay → user overlay)
#   - Rule 1A v1 filesystem variant (no MCP) vs MCP variant
#   - T1.9 preset sentinel-bypass: PRESET ∈ {base, none, "", unset}
#   - Re-run preserves user territory below marker; missing marker → backup
#
# v1 spec ref: §4 Stage 3, §5 Tier A.

setup() {
    GEN="$BATS_TEST_DIRNAME/../generate-codex.sh"
    [ -x "$GEN" ] || skip "generate-codex.sh not executable"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    TARGET="$(mktemp -d -t stage3_agents.XXXXXX)"
}

teardown() {
    rm -rf "$TARGET"
}

run_stage3() {
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" \
        --target "$TARGET" --preset "${PRESET:-base}" --stage 3 "$@"
}

@test "stage3: creates AGENTS.md at target" {
    PRESET=base run run_stage3
    [ "$status" -eq 0 ]
    [ -s "$TARGET/AGENTS.md" ]
}

@test "stage3: AGENTS.md has 'Sage — Project Instructions' header" {
    PRESET=base run_stage3
    grep -q '^# Sage — Project Instructions' "$TARGET/AGENTS.md"
}

@test "stage3: AGENTS.md contains '## Constitution' section" {
    PRESET=base run_stage3
    grep -q '^## Constitution' "$TARGET/AGENTS.md"
}

@test "stage3: AGENTS.md ends with SAGE-MANAGED-END marker (prefix-managed)" {
    PRESET=base run_stage3
    grep -q '<!-- SAGE-MANAGED-END' "$TARGET/AGENTS.md"
}

@test "stage3: PRESET=base → all 5 base principles present" {
    PRESET=base run_stage3
    grep -qi 'Tests before code'    "$TARGET/AGENTS.md"
    grep -qi 'No silent failures'   "$TARGET/AGENTS.md"
    grep -qi 'Secrets never in code' "$TARGET/AGENTS.md"
    grep -qi 'Dependencies explicit' "$TARGET/AGENTS.md"
    grep -qi 'Changes reversible'   "$TARGET/AGENTS.md"
}

@test "stage3: PRESET=base → no preset-overlay warning emitted (sentinel)" {
    PRESET=base run run_stage3
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -qi 'Preset overlay missing'
    ! echo "$output" | grep -qi 'falling back to base'
}

@test "stage3: PRESET=none → sentinel bypass, base only, no warning" {
    PRESET=none run run_stage3
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -qi 'Preset overlay missing'
    grep -qi 'Tests before code' "$TARGET/AGENTS.md"
}

@test "stage3: PRESET=startup → includes 'Ship smallest' (preset overlay merged)" {
    PRESET=startup run_stage3
    grep -qi 'Ship smallest viable' "$TARGET/AGENTS.md"
}

@test "stage3: PRESET=enterprise → includes 'All endpoints require authentication'" {
    PRESET=enterprise run_stage3
    grep -qi 'All endpoints require authentication' "$TARGET/AGENTS.md"
}

@test "stage3: PRESET=foo (missing) → warning to stderr + base fallback" {
    PRESET=foo run run_stage3
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi 'Preset overlay missing'
    grep -qi 'Tests before code' "$TARGET/AGENTS.md"
    # Should NOT contain startup/enterprise principles since fallback is base.
    ! grep -qi 'All endpoints require authentication' "$TARGET/AGENTS.md"
}

@test "stage3: .sage/constitution.md extends override → user preset wins" {
    mkdir -p "$TARGET/.sage"
    cat > "$TARGET/.sage/constitution.md" <<'EOF'
---
extends: enterprise
---
EOF
    PRESET=base run_stage3
    # User extends: enterprise overrides PRESET=base on the command line.
    grep -qi 'All endpoints require authentication' "$TARGET/AGENTS.md"
}

@test "stage3: Rule 1A renders 'v1 filesystem variant' when no [[mcp_servers]]" {
    # No .codex/config.toml at all → fallback variant.
    PRESET=base run_stage3
    grep -q 'v1 filesystem variant' "$TARGET/AGENTS.md"
}

@test "stage3: Rule 1A renders MCP variant when [[mcp_servers]] present" {
    mkdir -p "$TARGET/.codex"
    cat > "$TARGET/.codex/config.toml" <<'EOF'
[[mcp_servers]]
name = "sage-memory"
command = "node"
EOF
    PRESET=base run_stage3
    grep -q 'sage_memory_search' "$TARGET/AGENTS.md"
    ! grep -q 'v1 filesystem variant' "$TARGET/AGENTS.md"
}

@test "stage3: re-run preserves user content below marker" {
    PRESET=base run_stage3
    # Append user content below marker.
    cat >> "$TARGET/AGENTS.md" <<'EOF'

## My Custom Section

This is user territory — preserve me on update.
EOF
    PRESET=base run_stage3
    grep -q 'My Custom Section' "$TARGET/AGENTS.md"
    grep -q 'preserve me on update' "$TARGET/AGENTS.md"
}

@test "stage3: re-run with no marker → backup + regenerate (with marker)" {
    cat > "$TARGET/AGENTS.md" <<'EOF'
# User-only AGENTS.md without Sage marker.

Important user content here.
EOF
    PRESET=base run run_stage3
    [ "$status" -eq 0 ]
    # Backup should exist with user-backup-<ts> suffix.
    ls "$TARGET"/AGENTS.md.user-backup-* >/dev/null 2>&1
    # Regenerated AGENTS.md has the marker now.
    grep -q '<!-- SAGE-MANAGED-END' "$TARGET/AGENTS.md"
}
