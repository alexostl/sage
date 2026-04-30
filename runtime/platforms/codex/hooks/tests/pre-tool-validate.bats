#!/usr/bin/env bats
# T1.5 — pre-tool-validate.sh: PreToolUse hook (apply_patch matcher).
#
# Plan contract (T1.5): §15.3 4 cases + §15.4 parity.
#
# §15.3 cases:
#   - No active cycle → exit 2, stderr message present.
#   - Active cycle, path in scope → exit 0, append to
#     .sage/.session-mutations.log.
#   - Active cycle, path out of scope → exit 2, stderr lists
#     out-of-scope paths.
#   - jq/yq missing on PATH → exit 2 with install hint.
#
# §15.4 parity (vs sage_validate_mutation MCP tool):
#   - Phase value irrelevant in v1 (cycle-scope-only predicate).

setup() {
    HOOK="$BATS_TEST_DIRNAME/../pre-tool-validate.sh"
    [ -f "$HOOK" ] || skip "pre-tool-validate.sh not found at $HOOK"
    [ -x "$HOOK" ] || skip "pre-tool-validate.sh not executable"
    PROJECT_ROOT="$(mktemp -d -t pre_tool_validate_bats.XXXXXX)"
    mkdir -p "$PROJECT_ROOT/.sage/work"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

# Helper: build an apply_patch DSL command string.
make_patch_cmd() {
    local op="$1"   # Add|Update|Delete
    local path="$2"
    printf '*** Begin Patch\n*** %s File: %s\n+content\n*** End Patch\n' "$op" "$path"
}

# Helper: build full PreToolUse payload as JSON. Pipes cmd through
# `jq -Rs .` to produce a properly-escaped JSON string (jq's --arg
# does NOT escape newlines, which makes downstream `jq -e .` reject).
make_payload() {
    local cmd="$1"
    local cwd="${2:-$PROJECT_ROOT}"
    local cmd_json
    cmd_json="$(printf '%s' "$cmd" | jq -Rs .)"
    jq -nc --arg cwd "$cwd" --argjson cmd "$cmd_json" '{
        session_id: "test-uuid",
        turn_id: "turn-1",
        transcript_path: "/tmp/transcript",
        cwd: $cwd,
        hook_event_name: "PreToolUse",
        model: "test-model",
        permission_mode: "default",
        tool_name: "apply_patch",
        tool_input: { command: $cmd },
        tool_use_id: "tool-1"
    }'
}

# Helper: write a manifest with frontmatter + scope array.
make_cycle_with_scope() {
    local cycle="$1"
    local status="$2"
    shift 2
    local cycle_dir="$PROJECT_ROOT/.sage/work/$cycle"
    mkdir -p "$cycle_dir"
    {
        printf -- '---\n'
        printf 'cycle_id: "%s"\n' "$cycle"
        printf 'status: %s\n' "$status"
        printf 'phase: implement\n'
        printf 'scope:\n'
        local g
        for g in "$@"; do
            printf '  - "%s"\n' "$g"
        done
        printf -- '---\n'
        printf '# %s\n' "$cycle"
    } > "$cycle_dir/manifest.md"
}

@test "pre-tool-validate.sh: no active cycle → exit 2, stderr says no active cycle" {
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 2 ]
    echo "$stderr" "$output" | grep -qi "no active cycle"
}

@test "pre-tool-validate.sh: active cycle, path in scope → exit 0 + mutations log appended" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**" "tests/**"
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    grep -q "src/foo.txt" "$log"
}

@test "pre-tool-validate.sh: path out of scope → exit 2, stderr lists out-of-scope paths" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    cmd="$(make_patch_cmd Add docs/oops.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "docs/oops.md"
    echo "$output" | grep -qi "scope"
}

@test "pre-tool-validate.sh: Update File path in scope → allow" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    cmd="$(make_patch_cmd Update src/existing.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: Delete File path in scope → allow" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    cmd="$(make_patch_cmd Delete src/old.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: multiple paths, one out of scope → exit 2 + lists offender" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    cmd="$(printf '*** Begin Patch\n*** Add File: src/ok.txt\n+x\n*** Add File: docs/bad.md\n+y\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "docs/bad.md"
}

@test "pre-tool-validate.sh: completed cycle (not in-progress) → exit 2 (no active cycle)" {
    make_cycle_with_scope "20260101-done" "completed" "src/**"
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 2 ]
}

@test "pre-tool-validate.sh: phase value is irrelevant (§15.4 parity)" {
    # phase=design is "earlier" than implement, but predicate is
    # cycle-scope-only — must allow regardless.
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: design
scope:
  - "src/**"
---
EOF
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: session-mutations log line is valid JSON" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    line="$(tail -n1 "$log")"
    echo "$line" | jq -e '.' >/dev/null
    echo "$line" | jq -e '.session_id' >/dev/null
    echo "$line" | jq -e '.files | length' >/dev/null
    echo "$line" | jq -e '.ts' >/dev/null
}

@test "pre-tool-validate.sh: multiple in-progress cycles → newest mtime + warning logged" {
    make_cycle_with_scope "20260101-old" "in-progress" "src/**"
    sleep 1
    make_cycle_with_scope "20260102-newer" "in-progress" "tests/**"
    cmd="$(make_patch_cmd Add tests/new_test.sh)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    # newer cycle scope = tests/** → allow
    [ "$status" -eq 0 ]
    skip_log="$PROJECT_ROOT/.sage/.skipped-checks.log"
    [ -f "$skip_log" ]
    grep -qi "multiple" "$skip_log"
}

@test "pre-tool-validate.sh: jq missing on PATH → exit 2 with install hint" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    # Strip jq + yq from PATH; keep coreutils available.
    empty_path="$(mktemp -d)"
    for tool in bash sh cat sed grep awk head tail printf mktemp date stat dirname basename; do
        if command -v "$tool" >/dev/null 2>&1; then
            ln -sf "$(command -v "$tool")" "$empty_path/$tool" 2>/dev/null || true
        fi
    done
    run bash -c "PATH='$empty_path' '$HOOK' < <(echo '$payload') 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "jq\|yq"
    rm -rf "$empty_path"
}

@test "pre-tool-validate.sh: invalid JSON payload → exit 2 (fail closed)" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    run bash -c "echo 'not-json' | '$HOOK'"
    [ "$status" -eq 2 ]
}

@test "pre-tool-validate.sh: scope glob matches nested path (src/**) → src/sub/deep.txt allow" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    cmd="$(make_patch_cmd Add src/sub/deep.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}
