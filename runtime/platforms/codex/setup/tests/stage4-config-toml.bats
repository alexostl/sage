#!/usr/bin/env bats
# T1.12 — Stage 4 .codex/config.toml composition contract.
#
# Plan contract (T1.12):
#   - Block-managed pattern with paired markers START/END.
#   - [features] codex_hooks = true MUST be inside managed block.
#   - v1: NO [[mcp_servers]] (§8 deferred entirely).
#   - [history] developer_instructions present (Tier B, second surface).
#   - Re-run preserves user content outside markers.
#   - Missing markers → backup user file + regenerate.
#
# v1 spec ref: §4 Stage 4, §5 Tier B.

setup() {
    GEN="$BATS_TEST_DIRNAME/../generate-codex.sh"
    [ -x "$GEN" ] || skip "generate-codex.sh not executable"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../../.." && pwd)"
    TARGET="$(mktemp -d -t stage4_config.XXXXXX)"
}

teardown() {
    rm -rf "$TARGET"
}

run_stage4() {
    env SAGE_FRAMEWORK="$REPO_ROOT" "$GEN" \
        --target "$TARGET" --preset "${PRESET:-base}" --stage 4 "$@"
}

@test "stage4: creates .codex/config.toml at target" {
    PRESET=base run run_stage4
    [ "$status" -eq 0 ]
    [ -s "$TARGET/.codex/config.toml" ]
}

@test "stage4: config.toml has SAGE MANAGED BLOCK START marker" {
    PRESET=base run_stage4
    grep -q '# >>> SAGE MANAGED BLOCK START' "$TARGET/.codex/config.toml"
}

@test "stage4: config.toml has SAGE MANAGED BLOCK END marker" {
    PRESET=base run_stage4
    grep -q '# <<< SAGE MANAGED BLOCK END' "$TARGET/.codex/config.toml"
}

@test "stage4: config.toml contains 'codex_hooks = true' inside [features]" {
    PRESET=base run_stage4
    grep -q '^\[features\]' "$TARGET/.codex/config.toml"
    grep -qE '^codex_hooks[[:space:]]*=[[:space:]]*true' "$TARGET/.codex/config.toml"
}

@test "stage4: v1 config.toml does NOT contain [[mcp_servers]] block" {
    PRESET=base run_stage4
    ! grep -qE '^\[\[mcp_servers\]\]' "$TARGET/.codex/config.toml"
}

@test "stage4: config.toml contains [history] developer_instructions field" {
    PRESET=base run_stage4
    grep -q '^\[history\]' "$TARGET/.codex/config.toml"
    grep -qE '^developer_instructions[[:space:]]*=' "$TARGET/.codex/config.toml"
}

@test "stage4: config.toml parses as valid TOML (yq -p toml)" {
    PRESET=base run_stage4
    yq -p toml eval '.' "$TARGET/.codex/config.toml" >/dev/null
}

@test "stage4: re-run preserves user content above START marker" {
    PRESET=base run_stage4
    # Prepend user content above the managed block.
    cp "$TARGET/.codex/config.toml" "$TARGET/.codex/config.toml.orig"
    {
        echo '# user prelude line'
        echo '[user_section]'
        echo 'mykey = "mine"'
        echo ''
        cat "$TARGET/.codex/config.toml.orig"
    } > "$TARGET/.codex/config.toml"
    rm "$TARGET/.codex/config.toml.orig"

    PRESET=base run_stage4
    grep -q 'user prelude line' "$TARGET/.codex/config.toml"
    grep -q '\[user_section\]' "$TARGET/.codex/config.toml"
    grep -q 'mykey = "mine"' "$TARGET/.codex/config.toml"
}

@test "stage4: re-run preserves user content below END marker" {
    PRESET=base run_stage4
    # Append user content below the END marker.
    cat >> "$TARGET/.codex/config.toml" <<'EOF'

[my_postlude]
favorite_color = "purple"
EOF
    PRESET=base run_stage4
    grep -q 'my_postlude' "$TARGET/.codex/config.toml"
    grep -q 'favorite_color = "purple"' "$TARGET/.codex/config.toml"
}

@test "stage4: missing markers → backup + regenerate" {
    mkdir -p "$TARGET/.codex"
    cat > "$TARGET/.codex/config.toml" <<'EOF'
# user-only config without Sage markers
trust_level = "trusted"
EOF
    PRESET=base run run_stage4
    [ "$status" -eq 0 ]
    ls "$TARGET/.codex"/config.toml.user-edit-backup-* >/dev/null 2>&1
    grep -q '# >>> SAGE MANAGED BLOCK START' "$TARGET/.codex/config.toml"
}
