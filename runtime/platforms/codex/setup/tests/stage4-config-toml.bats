#!/usr/bin/env bats
# T1.12 — Stage 4 .codex/config.toml composition contract.
#
# Plan contract (T1.12):
#   - Block-managed pattern with paired markers START/END.
#   - [features] hooks = true MUST be inside managed block.
#   - v1: NO [[mcp_servers]] (§8 deferred entirely).
#   - developer_instructions present as a top-level key before [history].
#   - [history] contains history settings only.
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

@test "stage4: config.toml contains 'hooks = true' inside [features]" {
    PRESET=base run_stage4
    grep -q '^\[features\]' "$TARGET/.codex/config.toml"
    grep -qE '^hooks[[:space:]]*=[[:space:]]*true' "$TARGET/.codex/config.toml"
    ! grep -qE '^codex_hooks[[:space:]]*=' "$TARGET/.codex/config.toml"
}

@test "stage4: v1 config.toml does NOT contain [[mcp_servers]] block" {
    PRESET=base run_stage4
    ! grep -qE '^\[\[mcp_servers\]\]' "$TARGET/.codex/config.toml"
}

@test "stage4: config.toml contains top-level developer_instructions field" {
    PRESET=base run_stage4
    grep -qE '^developer_instructions[[:space:]]*=' "$TARGET/.codex/config.toml"
}

@test "stage4: developer_instructions carries Alex-native compact enforcement" {
    PRESET=base run_stage4
    grep -q 'Bug reports/findings without an explicit fix mandate' "$TARGET/.codex/config.toml"
    grep -q 'write new .sage prose in Polish' "$TARGET/.codex/config.toml"
    grep -q '\[C\] Checkpointed implementation' "$TARGET/.codex/config.toml"
    grep -q '\[F\] Full autonomous implementation' "$TARGET/.codex/config.toml"
    grep -q 'Subagents/reviewers inherit the same Sage scope' "$TARGET/.codex/config.toml"
    grep -q 'source/runtime/test/instruction changes require proper Sage workflow' "$TARGET/.codex/config.toml"
    grep -q 'single-file config-only Add/Update may be Lightweight/Surgical' "$TARGET/.codex/config.toml"
    grep -q 'multi-file/security/hooks/instruction/generated config still needs workflow' "$TARGET/.codex/config.toml"
    grep -q 'same-turn self-created artifacts are not approval' "$TARGET/.codex/config.toml"
}

@test "stage4: [history] block does not contain developer_instructions" {
    PRESET=base run_stage4
    grep -q '^\[history\]' "$TARGET/.codex/config.toml"
    if awk '
        /^\[history\][[:space:]]*$/ { in_history=1; next }
        /^\[/ { in_history=0 }
        in_history && /^developer_instructions[[:space:]]*=/ { found=1 }
        END { exit found ? 0 : 1 }
    ' "$TARGET/.codex/config.toml"; then
        echo "developer_instructions must not be inside [history]"
        return 1
    fi
}

@test "stage4: [history] block has 'persistence' field (Codex 0.126 requires it)" {
    # T2.1 finding (2026-04-30): Codex 0.126.0-alpha.15 rejects config
    # with [history] block missing 'persistence' field (error: "missing
    # field persistence"). M1 tests passed because they parsed TOML
    # statically, but real Codex CLI use exposed this runtime requirement.
    PRESET=base run_stage4
    grep -qE '^persistence[[:space:]]*=' "$TARGET/.codex/config.toml"
}

@test "stage4: config.toml parses as valid TOML (yq -p toml)" {
    PRESET=base run_stage4
    yq -p toml eval '.' "$TARGET/.codex/config.toml" >/dev/null
}

@test "stage4: config.toml parses with strict tomllib when available" {
    command -v python3 >/dev/null 2>&1 || skip "python3 not available"
    python3 -c 'import tomllib' >/dev/null 2>&1 || skip "python3 tomllib not available"
    PRESET=base run_stage4
    python3 - "$TARGET/.codex/config.toml" <<'PY'
import pathlib
import sys
import tomllib

tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
PY
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

@test "stage4: re-run removes legacy postlude [features] fallback with only codex_hooks" {
    PRESET=base run_stage4
    cat >> "$TARGET/.codex/config.toml" <<'EOF'

# legacy fallback from older Sage installs
[features]
codex_hooks = true
EOF
    PRESET=base run run_stage4
    [ "$status" -eq 0 ]
    [ "$(grep -c '^\[features\]$' "$TARGET/.codex/config.toml")" = "1" ]
    grep -qE '^hooks[[:space:]]*=[[:space:]]*true' "$TARGET/.codex/config.toml"
    ! grep -qE '^codex_hooks[[:space:]]*=' "$TARGET/.codex/config.toml"
    if command -v python3 >/dev/null 2>&1 && python3 -c 'import tomllib' >/dev/null 2>&1; then
        python3 - "$TARGET/.codex/config.toml" <<'PY'
import pathlib
import sys
import tomllib

tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
PY
    fi
}

@test "stage4: re-run fails instead of deleting user-owned [features] keys" {
    PRESET=base run_stage4
    cat >> "$TARGET/.codex/config.toml" <<'EOF'

[features]
codex_hooks = true
experimental_widget = true
EOF
    PRESET=base run run_stage4
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi 'duplicate singleton TOML table'
    ls "$TARGET/.codex"/config.toml.singleton-table-backup-* >/dev/null 2>&1
    grep -q 'experimental_widget = true' "$TARGET/.codex/config.toml"
    grep -q 'codex_hooks = true' "$TARGET/.codex/config.toml"
}

@test "stage4: re-run fails on duplicate user-owned [history] table" {
    PRESET=base run_stage4
    cat >> "$TARGET/.codex/config.toml" <<'EOF'

[history]
extra = "keep"
EOF
    PRESET=base run run_stage4
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi 'duplicate singleton TOML table'
    ls "$TARGET/.codex"/config.toml.singleton-table-backup-* >/dev/null 2>&1
    grep -q 'extra = "keep"' "$TARGET/.codex/config.toml"
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
