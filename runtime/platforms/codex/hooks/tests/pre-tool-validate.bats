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

make_bash_payload() {
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
        tool_name: "Bash",
        tool_input: { command: $cmd },
        tool_use_id: "tool-1"
    }'
}

make_file_change_payload() {
    local kind="$1"
    local path="$2"
    local cwd="${3:-$PROJECT_ROOT}"
    jq -nc --arg cwd "$cwd" --arg kind "$kind" --arg path "$path" '{
        session_id: "test-uuid",
        turn_id: "turn-1",
        transcript_path: "/tmp/transcript",
        cwd: $cwd,
        hook_event_name: "PreToolUse",
        model: "test-model",
        permission_mode: "default",
        tool_name: "file_change",
        tool_input: { changes: [{kind: $kind, path: $path}] },
        tool_use_id: "tool-1"
    }'
}

make_file_change_multi_payload() {
    local kind1="$1"
    local path1="$2"
    local kind2="$3"
    local path2="$4"
    local cwd="${5:-$PROJECT_ROOT}"
    jq -nc --arg cwd "$cwd" --arg kind1 "$kind1" --arg path1 "$path1" --arg kind2 "$kind2" --arg path2 "$path2" '{
        session_id: "test-uuid",
        turn_id: "turn-1",
        transcript_path: "/tmp/transcript",
        cwd: $cwd,
        hook_event_name: "PreToolUse",
        model: "test-model",
        permission_mode: "default",
        tool_name: "file_change",
        tool_input: { changes: [
            {kind: $kind1, path: $path1},
            {kind: $kind2, path: $path2}
        ] },
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
        if [ "$status" = "closed" ] || [ "$status" = "completed" ]; then
            printf 'phase: closed\n'
            printf 'resolution: shipped\n'
        else
            printf 'phase: implement\n'
        fi
        [ "$status" = "in-progress" ] && printf 'active_session_id: test-uuid\n'
        printf 'scope:\n'
        local g
        for g in "$@"; do
            printf '  - "%s"\n' "$g"
        done
        printf -- '---\n'
        printf '# %s\n' "$cycle"
    } > "$cycle_dir/manifest.md"
}

make_cycle_with_writable_scope() {
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
        [ "$status" = "in-progress" ] && printf 'active_session_id: test-uuid\n'
        printf 'scope:\n'
        printf '  writable: ['
        local first=1
        local g
        for g in "$@"; do
            [ "$first" -eq 0 ] && printf ', '
            printf '"%s"' "$g"
            first=0
        done
        printf ']\n'
        printf '  frozen: []\n'
        printf -- '---\n'
        printf '# %s\n' "$cycle"
    } > "$cycle_dir/manifest.md"
}

add_implementation_approval() {
    local cycle="$1"
    local mode="${2:-approved}"
    local revision="${3:-}"
    local cycle_dir="$PROJECT_ROOT/.sage/work/$cycle"
    local tmp="$cycle_dir/manifest.tmp"
    awk -v cycle="$cycle" -v mode="$mode" -v revision="$revision" '
        /^scope:/ && !done {
            print "implementation_approval:"
            print "  mode: " mode
            print "  approved_by: alexostl"
            print "  approved_at: \"2026-05-14\""
            print "  gate: fix-scope-gate"
            print "  artifact: \".sage/work/" cycle "/plan.md\""
            print "  scope: manifest"
            if (mode == "conditional_revision") {
                print "  revision: \"" revision "\""
            }
            done=1
        }
        { print }
    ' "$cycle_dir/manifest.md" > "$tmp"
    mv "$tmp" "$cycle_dir/manifest.md"
}

@test "pre-tool-validate.sh: no active cycle → exit 2, stderr says no active cycle" {
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 2 ]
    echo "$stderr" "$output" | grep -qi "no active cycle"
}

@test "pre-tool-validate.sh: Bash read command is allowed without active cycle" {
    payload="$(make_bash_payload "pwd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: Bash read command with stderr to /dev/null is allowed" {
    payload="$(make_bash_payload "sed -n '1,160p' runtime/platforms/codex/hooks/hooks.json 2>/dev/null || true")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: Bash shell edit to manifest active_session_id is blocked" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    payload="$(make_bash_payload "perl -0pi -e 's/active_session_id: unknown/active_session_id: test-uuid/' .sage/work/20260101-alpha/manifest.md")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 2 ]
    echo "$stderr" "$output" | grep -q "mutating Bash command"
    echo "$stderr" "$output" | grep -q "Next legal move"
}

@test "pre-tool-validate.sh: Bash write to project path is blocked" {
    payload="$(make_bash_payload "mkdir -p src/notes && cat > src/notes/random.md <<'EOF'\nhello\nEOF")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 2 ]
    echo "$stderr" "$output" | grep -q "use apply_patch"
}

@test "pre-tool-validate.sh: Bash write outside repo is allowed even with guarded-looking path segments" {
    payload="$(make_bash_payload "mkdir -p /tmp/sage-outside/runtime && cat > /tmp/sage-outside/runtime/random.md <<'EOF'\nhello\nEOF")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: Bash write to local ignored hook log is allowed" {
    payload="$(make_bash_payload "printf '%s\n' event >> .sage/.mcp-incidents.log")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: Bash write to managed gitignored hooks json is blocked" {
    payload="$(make_bash_payload "printf '%s\n' '{}' > .codex/hooks.json")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 2 ]
    echo "$stderr" "$output" | grep -q "use apply_patch"
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

@test "pre-tool-validate.sh: active cycle, inline scope.writable exact path → exit 0" {
    make_cycle_with_writable_scope "20260101-alpha" "in-progress" "AGENTS.md" ".sage/work/20260101-alpha/**" ".sage/decisions.md"
    cmd="$(make_patch_cmd Update AGENTS.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    grep -q '"AGENTS.md"' "$PROJECT_ROOT/.sage/.session-mutations.log"
}

@test "pre-tool-validate.sh: active_session_id mismatch blocks with handoff recovery path" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: implement
active_session_id: other-session
scope:
  - "src/**"
---
EOF
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "active cycle owned by another session"
    echo "$output" | grep -q "return to the original session"
    echo "$output" | grep -q "handoff/parking"
    echo "$output" | grep -q "separate intake"
}

@test "pre-tool-validate.sh: matching active_session_id allows in-progress cycle mutation" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: implement
active_session_id: test-uuid
scope:
  - "src/**"
---
EOF
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: active_session_id update to another UUID is blocked even when old lock matches" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: implement
active_session_id: test-uuid
scope:
  - ".sage/work/20260101-alpha/*"
---
EOF
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-alpha/manifest.md\n@@\n-active_session_id: test-uuid\n+active_session_id: other-session\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "active_session_id"
    echo "$output" | grep -q "current session_id"
}

@test "pre-tool-validate.sh: active_session_id update to codex thread URL is blocked" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: implement
active_session_id: test-uuid
scope:
  - ".sage/work/20260101-alpha/*"
---
EOF
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-alpha/manifest.md\n@@\n-active_session_id: test-uuid\n+active_session_id: \"codex://threads/019e2fba-7253-7ee0-90c5-17637ab688bd\"\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "active_session_id"
    echo "$output" | grep -q "current session_id"
}

@test "pre-tool-validate.sh: active_session_id removal by owning session is allowed" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: completion-checkpoint
active_session_id: test-uuid
scope:
  - ".sage/work/20260101-alpha/*"
---
EOF
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-alpha/manifest.md\n@@\n-status: in-progress\n-phase: completion-checkpoint\n-active_session_id: test-uuid\n+status: closed\n+phase: closed\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: active cycle without active_session_id blocks scoped mutation" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: implement
scope:
  - "src/**"
---
EOF
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "unbound active cycle"
    echo "$output" | grep -q "manifest-only claim/handoff"
}

@test "pre-tool-validate.sh: unbound active cycle allows root-cause artifact update without lock" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: root-cause-gate
scope:
  - ".sage/work/20260101-alpha/*"
  - ".sage/decisions.md"
---
EOF
    cmd="$(printf '*** Begin Patch\n*** Add File: .sage/work/20260101-alpha/root-cause.md\n+# Root cause\n*** Update File: .sage/decisions.md\n@@\n+diagnosis note\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    grep -q '"sage_capture_without_lock"' "$PROJECT_ROOT/.sage/.session-mutations.log"
}

@test "pre-tool-validate.sh: unbound active cycle blocks manifest lifecycle field change" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: root-cause-gate
scope:
  - ".sage/work/20260101-alpha/*"
---
EOF
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-alpha/manifest.md\n@@\n-status: in-progress\n+status: closed\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "ownership/lifecycle"
}

@test "pre-tool-validate.sh: active cycle owned by another session allows manifest body capture" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: plan
active_session_id: other-session
scope:
  - ".sage/work/20260101-alpha/*"
---

# Alpha

## Captured Findings
EOF
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-alpha/manifest.md\n@@\n ## Captured Findings\n+\n+- Finding from another cycle.\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    grep -q '"sage_capture_without_lock"' "$PROJECT_ROOT/.sage/.session-mutations.log"
}

@test "pre-tool-validate.sh: placeholder active_session_id current blocks non-claim mutation" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: implement
active_session_id: current
scope:
  - "AGENTS.md"
---
EOF
    cmd="$(make_patch_cmd Update AGENTS.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "unbound active cycle"
}

@test "pre-tool-validate.sh: unbound active cycle allows single-file manifest claim" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: implement
scope:
  - "src/**"
---
EOF
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-alpha/manifest.md\n@@\n status: in-progress\n+active_session_id: test-uuid\n phase: implement\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    grep -q '"active_cycle_claim_or_handoff"' "$PROJECT_ROOT/.sage/.session-mutations.log"
}

@test "pre-tool-validate.sh: unbound active cycle allows single-file manifest handoff parking" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: implement
scope:
  - "src/**"
---
EOF
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-alpha/manifest.md\n@@\n-status: in-progress\n+status: paused\n phase: implement\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: unbound active cycle blocks manifest-only closed closeout" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: implement
scope:
  - "src/**"
---
EOF
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-alpha/manifest.md\n@@\n-status: in-progress\n+status: closed\n phase: implement\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "unbound active cycle"
}

@test "pre-tool-validate.sh: blocks Moderate+ implementation before plan.md exists" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**" "tests/**"
    cmd="$(printf '*** Begin Patch\n*** Add File: src/a.sh\n+x\n*** Add File: src/b.sh\n+y\n*** Add File: src/c.sh\n+z\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "Moderate+ fix"
    echo "$output" | grep -q "plan.md"
    echo "$output" | grep -q "manifest.md"
}

@test "pre-tool-validate.sh: allows Moderate+ implementation after plan.md and manifest.md exist" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**" "tests/**"
    touch "$PROJECT_ROOT/.sage/work/20260101-alpha/plan.md"
    cmd="$(printf '*** Begin Patch\n*** Add File: src/a.sh\n+x\n*** Add File: src/b.sh\n+y\n*** Add File: src/c.sh\n+z\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: blocks third implementation file when artifacts were not written first" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    printf '{"session_id":"test-uuid","cycle_id":"20260101-alpha","files":["src/a.sh"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    printf '{"session_id":"test-uuid","cycle_id":"20260101-alpha","files":["src/b.sh"]}\n' >> "$PROJECT_ROOT/.sage/.session-mutations.log"
    cmd="$(make_patch_cmd Add src/c.sh)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "Moderate+ fix"
    echo "$output" | grep -qi "scope amputation"
    echo "$output" | grep -qi "required"
}

@test "pre-tool-validate.sh: binary Bash mutation without explicit intent is blocked" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "runtime/assets/**"
    payload="$(make_bash_payload "rm runtime/assets/old.png")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "binary asset"
    echo "$output" | grep -q "SAGE_BINARY_MUTATION=1"
}

@test "pre-tool-validate.sh: explicit binary Bash mutation in scope is allowed and logged" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "runtime/assets/**"
    mkdir -p "$PROJECT_ROOT/runtime/assets"
    printf 'png' > "$PROJECT_ROOT/runtime/assets/old.png"
    payload="$(make_bash_payload "SAGE_BINARY_MUTATION=1 rm runtime/assets/old.png")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    grep -q '"runtime/assets/old.png"' "$log"
    tail -n1 "$log" | jq -e '.cycle_id == "20260101-alpha"' >/dev/null
}

@test "pre-tool-validate.sh: explicit binary Bash mutation outside scope is blocked" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "runtime/assets/**"
    payload="$(make_bash_payload "SAGE_BINARY_MUTATION=1 rm docs/old.png")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "docs/old.png"
    echo "$output" | grep -q "outside cycle scope"
}

@test "pre-tool-validate.sh: explicit binary Bash mutation with compound shell is fail-closed" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "runtime/assets/**"
    payload="$(make_bash_payload "SAGE_BINARY_MUTATION=1 rm runtime/assets/old.png && touch runtime/assets/new.png")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "binary asset"
    echo "$output" | grep -qi "simple"
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

@test "pre-tool-validate.sh: file_change-shaped payload in scope → exit 0 + mutations log appended" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    payload="$(make_file_change_payload add "$PROJECT_ROOT/src/from-file-change.txt")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    grep -q '"src/from-file-change.txt"' "$log"
}

@test "pre-tool-validate.sh: file_change-shaped payload out of scope → exit 2" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    payload="$(make_file_change_payload add "$PROJECT_ROOT/docs/from-file-change.md")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "docs/from-file-change.md"
}

@test "pre-tool-validate.sh: same-turn manifest cannot authorize source file_change" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    printf '{"session_id":"test-uuid","turn_id":"turn-1","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/manifest.md",".sage/decisions.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload add "$PROJECT_ROOT/src/from-self-created-manifest.txt")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "implementation approval contract"
    echo "$output" | grep -q "src/from-self-created-manifest.txt"
    echo "$output" | grep -q "source/runtime/test/instruction"
    ! echo "$output" | grep -q "source/runtime/test/config/instruction"
}

@test "pre-tool-validate.sh: same-turn plan still cannot authorize source file_change" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    touch "$PROJECT_ROOT/.sage/work/20260101-alpha/plan.md"
    printf '{"session_id":"test-uuid","turn_id":"turn-1","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/manifest.md",".sage/work/20260101-alpha/plan.md",".sage/decisions.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload add "$PROJECT_ROOT/src/after-plan.txt")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "implementation approval contract"
}

@test "pre-tool-validate.sh: prior-turn plan can authorize source file_change" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    touch "$PROJECT_ROOT/.sage/work/20260101-alpha/plan.md"
    printf '{"session_id":"test-uuid","turn_id":"turn-0","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/manifest.md",".sage/work/20260101-alpha/plan.md",".sage/decisions.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload add "$PROJECT_ROOT/src/after-approval-turn.txt")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: prior approved plan allows same-turn manifest bookkeeping before source edit" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    touch "$PROJECT_ROOT/.sage/work/20260101-alpha/plan.md"
    add_implementation_approval "20260101-alpha"
    printf '{"session_id":"test-uuid","turn_id":"turn-0","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/plan.md",".sage/decisions.md"]}\n{"session_id":"test-uuid","turn_id":"turn-1","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/manifest.md",".sage/decisions.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload add "$PROJECT_ROOT/src/after-approved-manifest-bookkeeping.txt")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: semantic_reclassification checkpoint after approval does not renew same-turn block" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    sed -i.bak '/phase: implement/a\
semantic_reclassification: accepted
' "$PROJECT_ROOT/.sage/work/20260101-alpha/manifest.md"
    rm -f "$PROJECT_ROOT/.sage/work/20260101-alpha/manifest.md.bak"
    touch "$PROJECT_ROOT/.sage/work/20260101-alpha/plan.md"
    add_implementation_approval "20260101-alpha"
    printf '{"session_id":"test-uuid","turn_id":"turn-0","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/plan.md",".sage/decisions.md"]}\n{"session_id":"test-uuid","turn_id":"turn-1","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/manifest.md",".sage/decisions.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload add "$PROJECT_ROOT/src/after-semantic-checkpoint.txt")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: same-turn milestone plan bookkeeping does not count as canonical self-approval" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    touch "$PROJECT_ROOT/.sage/work/20260101-alpha/plan.md"
    touch "$PROJECT_ROOT/.sage/work/20260101-alpha/plan-milestone-1.md"
    add_implementation_approval "20260101-alpha"
    printf '{"session_id":"test-uuid","turn_id":"turn-0","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/plan.md",".sage/decisions.md"]}\n{"session_id":"test-uuid","turn_id":"turn-1","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/plan-milestone-1.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload add "$PROJECT_ROOT/src/after-milestone-plan.txt")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: conditional revision marker allows same-turn canonical plan revision" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    touch "$PROJECT_ROOT/.sage/work/20260101-alpha/plan.md"
    add_implementation_approval "20260101-alpha" "conditional_revision" "apply requested scope wording"
    printf '{"session_id":"test-uuid","turn_id":"turn-0","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/plan.md",".sage/decisions.md"]}\n{"session_id":"test-uuid","turn_id":"turn-1","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/plan.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload add "$PROJECT_ROOT/src/after-conditional-plan-revision.txt")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: marker without prior canonical plan evidence still blocks AGENTS.md" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "AGENTS.md"
    touch "$PROJECT_ROOT/.sage/work/20260101-alpha/plan.md"
    add_implementation_approval "20260101-alpha"
    printf '{"session_id":"test-uuid","turn_id":"turn-1","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/manifest.md",".sage/work/20260101-alpha/plan.md",".sage/decisions.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload update "$PROJECT_ROOT/AGENTS.md")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "implementation approval contract"
    echo "$output" | grep -q "AGENTS.md"
}

@test "pre-tool-validate.sh: manifest-only prior evidence without canonical plan still blocks AGENTS.md" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "AGENTS.md"
    add_implementation_approval "20260101-alpha"
    printf '{"session_id":"test-uuid","turn_id":"turn-0","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/manifest.md",".sage/decisions.md"]}\n{"session_id":"test-uuid","turn_id":"turn-1","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/manifest.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload update "$PROJECT_ROOT/AGENTS.md")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "implementation approval contract"
    echo "$output" | grep -q "AGENTS.md"
}

@test "pre-tool-validate.sh: same-turn manifest cannot authorize AGENTS.md" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "AGENTS.md"
    printf '{"session_id":"test-uuid","turn_id":"turn-1","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/manifest.md",".sage/decisions.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload update "$PROJECT_ROOT/AGENTS.md")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "instruction"
    echo "$output" | grep -q "implementation approval contract"
    echo "$output" | grep -q "AGENTS.md"
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
    sed -i.bak '/phase: implement/a\
semantic_reclassification: accepted
' "$PROJECT_ROOT/.sage/work/20260101-alpha/manifest.md"
    rm -f "$PROJECT_ROOT/.sage/work/20260101-alpha/manifest.md.bak"
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

@test "pre-tool-validate.sh: closed cycle (not in-progress) → exit 2 (no active cycle)" {
    make_cycle_with_scope "20260101-done" "closed" "src/**"
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 2 ]
}

@test "pre-tool-validate.sh: closed cycle plan mutation gives closeout recovery guidance" {
    make_cycle_with_scope "20260101-done" "closed" ".sage/work/20260101-done/*"
    cmd="$(make_patch_cmd Update .sage/work/20260101-done/plan.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "closed cycle"
    echo "$output" | grep -qi "immutable"
    echo "$output" | grep -qi "manifest-only reconciliation"
    echo "$output" | grep -qi "wrapper/follow-up"
}

@test "pre-tool-validate.sh: closed cycle artifact path beats unrelated active cycle" {
    make_cycle_with_scope "20260101-active" "in-progress" "src/**"
    make_cycle_with_scope "20260102-done" "closed" ".sage/work/20260102-done/*"
    cmd="$(make_patch_cmd Update .sage/work/20260102-done/plan.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "closed cycle"
    ! echo "$output" | grep -q "outside cycle scope"
}

@test "pre-tool-validate.sh: closed manifest-only reconciliation is allowed" {
    make_cycle_with_scope "20260101-done" "closed" ".sage/work/20260101-done/*"
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-done/manifest.md\n@@\n-resolution: shipped\n+resolution: superseded\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    jq -e 'select(.mutation_kind == "closed_manifest_reconciliation")' "$PROJECT_ROOT/.sage/.session-mutations.log" >/dev/null
}

@test "pre-tool-validate.sh: closed manifest-only reconciliation blocks reopen status" {
    make_cycle_with_scope "20260101-done" "closed" ".sage/work/20260101-done/*"
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-done/manifest.md\n@@\n-status: closed\n+status: in-progress\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "closed cycle"
}

@test "pre-tool-validate.sh: closed manifest-only reconciliation blocks status removal" {
    make_cycle_with_scope "20260101-done" "closed" ".sage/work/20260101-done/*"
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-done/manifest.md\n@@\n-status: closed\n phase: closed\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "closed cycle"
}

@test "pre-tool-validate.sh: closed manifest reconciliation blocks any second file" {
    make_cycle_with_scope "20260101-done" "closed" ".sage/work/20260101-done/*"
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-done/manifest.md\n@@\n-resolution: shipped\n+resolution: superseded\n*** Update File: .sage/decisions.md\n@@\n+decision\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "closed cycle"
}

@test "pre-tool-validate.sh: closed manifest reconciliation requires apply_patch command details" {
    make_cycle_with_scope "20260101-done" "closed" ".sage/work/20260101-done/*"
    payload="$(make_file_change_payload update "$PROJECT_ROOT/.sage/work/20260101-done/manifest.md")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "closed cycle"
}

@test "pre-tool-validate.sh: paused/intake cycles are parked, not silently activated" {
    make_cycle_with_scope "20260101-paused" "paused" "src/**"
    make_cycle_with_scope "20260102-intake" "intake" "src/**"
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "parked"
    echo "$output" | grep -qi "manifest-only"
    echo "$output" | grep -qi "sage:continue"
}

@test "pre-tool-validate.sh: lightweight single top-level config update allowed with parked cycles" {
    make_cycle_with_scope "20260101-paused" "paused" "src/**"
    make_cycle_with_scope "20260102-intake" "intake" "src/**"
    cmd="$(make_patch_cmd Update config/codex-config.toml)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    grep -q '"config/codex-config.toml"' "$log"
    tail -n1 "$log" | jq -e '.cycle_id == ""' >/dev/null
}

@test "pre-tool-validate.sh: lightweight config allowance rejects two config files without active cycle" {
    cmd="$(printf '*** Begin Patch\n*** Update File: config/a.toml\n@@\n+x\n*** Update File: config/b.toml\n@@\n+y\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active"
}

@test "pre-tool-validate.sh: lightweight config allowance rejects .codex/config.toml" {
    cmd="$(make_patch_cmd Update .codex/config.toml)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active"
}

@test "pre-tool-validate.sh: lightweight config allowance rejects delete" {
    cmd="$(make_patch_cmd Delete config/codex-config.toml)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active"
}

@test "pre-tool-validate.sh: lightweight config allowance rejects high-risk config basenames" {
    for path in config/hooks.toml config/secrets.json; do
        cmd="$(make_patch_cmd Update "$path")"
        payload="$(make_payload "$cmd")"
        run bash -c "echo '$payload' | '$HOOK' 2>&1"
        [ "$status" -eq 2 ]
        echo "$output" | grep -qi "no active"
    done
}

@test "pre-tool-validate.sh: lightweight config allowance rejects nested config path" {
    cmd="$(make_patch_cmd Update config/nested/app.toml)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active"
}

@test "pre-tool-validate.sh: lightweight single config file_change update allowed without active cycle" {
    payload="$(make_file_change_payload update "$PROJECT_ROOT/config/codex-config.toml")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    grep -q '"config/codex-config.toml"' "$log"
    tail -n1 "$log" | jq -e '.cycle_id == ""' >/dev/null
}

@test "pre-tool-validate.sh: quantitative surgical update allowed without active cycle" {
    cmd="$(printf '*** Begin Patch\n*** Update File: README.md\n@@\n-Smol realistic project\n+Small realistic project\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    tail -n1 "$log" | jq -e '.cycle_id == "" and .mutation_kind == "surgical_edit"' >/dev/null
}

@test "pre-tool-validate.sh: surgical update rejects over two changed lines without active cycle" {
    cmd="$(printf '*** Begin Patch\n*** Update File: README.md\n@@\n-a\n-b\n+c\n+d\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active"
}

@test "pre-tool-validate.sh: surgical update rejects multi-file patch without active cycle" {
    cmd="$(printf '*** Begin Patch\n*** Update File: README.md\n@@\n-a\n+b\n*** Update File: docs/architecture.md\n@@\n-c\n+d\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active"
}

@test "pre-tool-validate.sh: placeholder env artifact allowed without active cycle" {
    cmd="$(printf '*** Begin Patch\n*** Add File: .env.local.example\n+OPENAI_API_KEY=placeholder\n+DATABASE_URL=postgres://placeholder\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    grep -q '".env.local.example"' "$log"
    tail -n1 "$log" | jq -e '.cycle_id == "" and .mutation_kind == "placeholder_secret"' >/dev/null
}

@test "pre-tool-validate.sh: real secret value blocks even when file would be surgical" {
    cmd="$(printf '*** Begin Patch\n*** Update File: .env.local\n@@\n+OPENAI_API_KEY=sk-real-secret-value-for-test-123456\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "real secret"
    echo "$output" | grep -qi "placeholder"
}

@test "pre-tool-validate.sh: local ignored artifact allowed without active cycle" {
    (
        cd "$PROJECT_ROOT" || exit 1
        git init -q
        printf '.sage-local/\n' > .gitignore
    )
    cmd="$(make_patch_cmd Add .sage-local/hook-discovery.json)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    grep -q '".sage-local/hook-discovery.json"' "$log"
    tail -n1 "$log" | jq -e '.cycle_id == "" and .mutation_kind == "local_ignored_artifact"' >/dev/null
}

@test "pre-tool-validate.sh: local artifact is blocked when not gitignored" {
    (cd "$PROJECT_ROOT" && git init -q)
    cmd="$(make_patch_cmd Add .sage-local/hook-discovery.json)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active"
}

@test "pre-tool-validate.sh: local ignored artifact rejects mixed managed path" {
    (
        cd "$PROJECT_ROOT" || exit 1
        git init -q
        printf '.sage-local/\n' > .gitignore
    )
    cmd="$(printf '*** Begin Patch\n*** Add File: .sage-local/hook-discovery.json\n+{}\n*** Add File: src/leak.js\n+bad\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active"
}

@test "pre-tool-validate.sh: local ignored artifact rejects secret-like files" {
    (
        cd "$PROJECT_ROOT" || exit 1
        git init -q
        printf '.sage-local/\n' > .gitignore
    )
    cmd="$(make_patch_cmd Add .sage-local/api-token.json)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active"
}

@test "pre-tool-validate.sh: local ignored artifact is independent of unrelated active cycle" {
    (
        cd "$PROJECT_ROOT" || exit 1
        git init -q
        printf '.sage-local/\n' > .gitignore
    )
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    cmd="$(make_patch_cmd Add .sage-local/hook-discovery.json)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    tail -n1 "$PROJECT_ROOT/.sage/.session-mutations.log" | jq -e '.cycle_id == "" and .mutation_kind == "local_ignored_artifact"' >/dev/null
}

@test "pre-tool-validate.sh: decisions-only repo hygiene allows .gitignore plus decisions" {
    cmd="$(printf '*** Begin Patch\n*** Update File: .gitignore\n@@\n+harness-run-*\n*** Update File: .sage/decisions.md\n@@\n+repo hygiene decision\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    grep -q '".gitignore"' "$log"
    grep -q '".sage/decisions.md"' "$log"
    tail -n1 "$log" | jq -e '.cycle_id == "" and .mutation_kind == "decisions_only_repo_hygiene"' >/dev/null
}

@test "pre-tool-validate.sh: standalone .gitignore repo hygiene gets decisions-only guidance" {
    cmd="$(make_patch_cmd Update .gitignore)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "decisions-only repo hygiene"
    echo "$output" | grep -q ".sage/decisions.md"
}

@test "pre-tool-validate.sh: decisions-only repo hygiene rejects mixed runtime path" {
    cmd="$(printf '*** Begin Patch\n*** Update File: .gitignore\n@@\n+harness-run-*\n*** Update File: .sage/decisions.md\n@@\n+repo hygiene decision\n*** Update File: runtime/platforms/codex/hooks/pre-tool-validate.sh\n@@\n+bad\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active"
}

@test "pre-tool-validate.sh: lightweight config file_change rejects multi-file config change" {
    payload="$(make_file_change_multi_payload update "$PROJECT_ROOT/config/a.toml" update "$PROJECT_ROOT/config/b.toml")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active"
}

@test "pre-tool-validate.sh: lightweight config file_change rejects high-risk basename" {
    payload="$(make_file_change_payload update "$PROJECT_ROOT/config/policy.yaml")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active"
}

@test "pre-tool-validate.sh: active gated checkpoint allows same-cycle artifact update" {
    make_cycle_with_scope "20260101-alpha" "in-progress" ".sage/work/20260101-alpha/*"
    sed -i.bak 's/phase: implement/phase: root-cause-gate/' "$PROJECT_ROOT/.sage/work/20260101-alpha/manifest.md"
    rm -f "$PROJECT_ROOT/.sage/work/20260101-alpha/manifest.md.bak"
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-alpha/root-cause.md\n@@\n+evidence\n*** Update File: .sage/decisions.md\n@@\n+decision\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    grep -q '"cycle_id":"20260101-alpha"' "$PROJECT_ROOT/.sage/.session-mutations.log"
}

@test "pre-tool-validate.sh: new-cycle bootstrap allowed even when another cycle is active" {
    make_cycle_with_scope "20260101-active" "in-progress" "src/**"
    cmd="$(printf '*** Begin Patch\n*** Add File: .sage/work/20260103-new/manifest.md\n+---\n+cycle_id: \"20260103-new\"\n+status: in-progress\n+---\n*** Add File: .sage/work/20260103-new/spec.md\n+# Spec\n*** Update File: .sage/decisions.md\n@@\n+decision\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    grep -q '"cycle_id":"20260103-new"' "$log"
}

@test "pre-tool-validate.sh: new-cycle bootstrap rejects wrong active_session_id" {
    cycle="20260103-wrong-session"
    cmd="$(printf '*** Begin Patch\n*** Add File: .sage/work/%s/manifest.md\n+---\n+cycle_id: \"%s\"\n+status: in-progress\n+phase: understand\n+active_session_id: \"019e2fba-7253-7ee0-90c5-17637ab688bd\"\n+---\n+\n+# Wrong Session\n*** End Patch\n' "$cycle" "$cycle")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "active_session_id"
    echo "$output" | grep -q "current session_id"
}

@test "pre-tool-validate.sh: new-cycle bootstrap without active_session_id is allowed" {
    cycle="20260103-no-session"
    cmd="$(printf '*** Begin Patch\n*** Add File: .sage/work/%s/manifest.md\n+---\n+cycle_id: \"%s\"\n+status: in-progress\n+phase: understand\n+---\n+\n+# No Session Yet\n*** End Patch\n' "$cycle" "$cycle")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    grep -q "\"cycle_id\":\"$cycle\"" "$PROJECT_ROOT/.sage/.session-mutations.log"
}

@test "pre-tool-validate.sh: new intake manifest bootstrap allowed while another cycle is active" {
    make_cycle_with_scope "20260101-active" "in-progress" "src/**"
    cmd="$(printf '*** Begin Patch\n*** Add File: .sage/work/20260104-new-intake/manifest.md\n+---\n+cycle_id: \"20260104-new-intake\"\n+status: intake\n+phase: intake\n+tags:\n+  - needs-triage\n+---\n+\n+# Intake\n*** Update File: .sage/decisions.md\n@@\n+captured intake\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    grep -q '"cycle_id":"20260104-new-intake"' "$PROJECT_ROOT/.sage/.session-mutations.log"
}

@test "pre-tool-validate.sh: path intent chooses touched active cycle over newest active" {
    make_cycle_with_scope "20260101-target" "in-progress" ".sage/work/20260101-target/*"
    sleep 1
    make_cycle_with_scope "20260102-newest" "in-progress" "src/**"
    cmd="$(make_patch_cmd Update .sage/work/20260101-target/manifest.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    grep -q '"cycle_id":"20260101-target"' "$PROJECT_ROOT/.sage/.session-mutations.log"
}

@test "pre-tool-validate.sh: ambiguous multi-cycle patch blocks with selection guidance" {
    make_cycle_with_scope "20260101-alpha" "in-progress" ".sage/work/20260101-alpha/*"
    make_cycle_with_scope "20260102-beta" "in-progress" ".sage/work/20260102-beta/*"
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-alpha/manifest.md\n@@\n+a\n*** Update File: .sage/work/20260102-beta/manifest.md\n@@\n+b\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "ambiguous cycle"
    echo "$output" | grep -q "20260101-alpha"
    echo "$output" | grep -q "20260102-beta"
}

@test "pre-tool-validate.sh: parked intake capture allows same-cycle artifact and decisions only" {
    make_cycle_with_scope "20260101-intake" "intake" ".sage/work/20260101-intake/*"
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-intake/manifest.md\n@@\n+capture\n*** Update File: .sage/decisions.md\n@@\n+decision\n*** Add File: .sage-memory/learning.md\n+learned\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: cross-cycle capture to existing intake works while another cycle is active" {
    make_cycle_with_scope "20260101-active" "in-progress" "src/**"
    make_cycle_with_scope "20260102-intake" "intake" ".sage/work/20260102-intake/*"
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260102-intake/manifest.md\n@@\n+finding captured from active cycle\n*** Update File: .sage/decisions.md\n@@\n+decision\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    grep -q '"cycle_id":"20260102-intake"' "$PROJECT_ROOT/.sage/.session-mutations.log"
}

@test "pre-tool-validate.sh: parked intake capture blocks implementation files" {
    make_cycle_with_scope "20260101-intake" "intake" ".sage/work/20260101-intake/*"
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260101-intake/manifest.md\n@@\n+capture\n*** Add File: src/nope.sh\n+nope\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "parked-cycle capture"
    echo "$output" | grep -q "src/nope.sh"
}

@test "pre-tool-validate.sh: cross-cycle capture with implementation file blocks while another cycle is active" {
    make_cycle_with_scope "20260101-active" "in-progress" "src/**"
    make_cycle_with_scope "20260102-intake" "intake" ".sage/work/20260102-intake/*"
    cmd="$(printf '*** Begin Patch\n*** Update File: .sage/work/20260102-intake/manifest.md\n@@\n+capture\n*** Add File: src/nope.sh\n+nope\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "parked-cycle capture"
    echo "$output" | grep -q "src/nope.sh"
}

@test "pre-tool-validate.sh: risky repo-control/doc/test/CLI path requires semantic reclassification" {
    make_cycle_with_scope "20260101-alpha" "in-progress" ".gitignore" "README.md" "bin/*" "tests/**"
    cmd="$(printf '*** Begin Patch\n*** Update File: .gitignore\n@@\n+tmp\n*** Update File: README.md\n@@\n+docs\n*** Update File: bin/sage\n@@\n+cli\n*** Add File: tests/new.bats\n+test\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "semantic reclassification"
    echo "$output" | grep -q ".gitignore"
    echo "$output" | grep -q "README.md"
    echo "$output" | grep -q "bin/sage"
    echo "$output" | grep -q "tests/new.bats"
}

@test "pre-tool-validate.sh: risky path allowed after semantic_reclassification accepted" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<'EOF'
---
cycle_id: "20260101-alpha"
status: in-progress
phase: implement
semantic_reclassification: accepted
active_session_id: test-uuid
scope:
  - ".gitignore"
  - "tests/**"
---
EOF
    touch "$cycle_dir/plan.md"
    cmd="$(printf '*** Begin Patch\n*** Update File: .gitignore\n@@\n+tmp\n*** Add File: tests/new.bats\n+test\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: Delete File is risky even when path is otherwise in scope" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    cmd="$(make_patch_cmd Delete src/old.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "semantic reclassification"
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
active_session_id: test-uuid
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
    echo "$line" | jq -e '.kind == "session_mutation"' >/dev/null
    echo "$line" | jq -e '.session_id' >/dev/null
    echo "$line" | jq -e '.files | length' >/dev/null
    echo "$line" | jq -e '.ts' >/dev/null
}

@test "pre-tool-validate.sh: multiple in-progress cycles → newest mtime + warning logged" {
    make_cycle_with_scope "20260101-old" "in-progress" "src/**"
    sleep 1
    make_cycle_with_scope "20260102-newer" "in-progress" "app/**"
    cmd="$(make_patch_cmd Add app/new_feature.sh)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    # newer cycle scope = app/** → allow
    [ "$status" -eq 0 ]
    skip_log="$PROJECT_ROOT/.sage/.skipped-checks.log"
    [ -f "$skip_log" ]
    jq -e 'select(.kind == "skipped_check" and .cause == "multiple_in_progress_cycles")' "$skip_log" >/dev/null
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

@test "pre-tool-validate.sh: absolute apply_patch path → normalized to relative for scope check + log" {
    # T2.7 follow-up (2026-04-30): real Codex 0.126 emits ABSOLUTE paths
    # in apply_patch DSL. Pre-T2.7 fix, scope check failed (relative globs
    # didn't match absolute paths) AND session-mutations.log stored absolute
    # paths that turn-audit later compared against relative porcelain →
    # 18 false bypass_mutation incidents per 5-prompt harness run.
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    abs_path="$PROJECT_ROOT/src/foo.txt"
    cmd="$(make_patch_cmd Add "$abs_path")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    # session-mutations.log entry must contain RELATIVE path "src/foo.txt".
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    grep -q '"src/foo.txt"' "$log"
    ! grep -q "$abs_path" "$log"
}

@test "pre-tool-validate.sh: BUG-F1-1 — bootstrap exception: fresh cycle creation with manifest.md among paths → ALLOW" {
    # F-1 Phase 1 BUG-F1-1 (first PreToolUse block in T1):
    # Agent's first apply_patch on a fresh /sage:build creates the cycle dir,
    # including manifest.md. No in-progress manifest exists yet → active_init
    # returns empty → hook rejects. Chicken-egg: the manifest the predicate
    # needs is the file the agent is creating.
    #
    # Fix: bootstrap exception when ALL claimed paths are confined to a single
    # new .sage/work/<id>/ directory (id matches YYYYMMDD-<slug>) + decisions.md,
    # AND manifest.md is among the created paths, AND the cycle dir does NOT
    # yet exist on disk.
    cycle="20260101-bootstrap"
    cmd="$(printf '*** Begin Patch\n*** Add File: .sage/work/%s/brief.md\n+content\n*** Add File: .sage/work/%s/spec.md\n+content\n*** Add File: .sage/work/%s/manifest.md\n+content\n*** Update File: .sage/decisions.md\n@@\n line1\n+ new entry\n*** End Patch\n' "$cycle" "$cycle" "$cycle")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: BUG-F1-1 — bootstrap rejected when no manifest.md among created paths" {
    # If the patch creates a cycle dir but does NOT include manifest.md,
    # the agent isn't actually establishing a cycle — bootstrap exception
    # must NOT fire. Fall through to the normal "no active cycle" reject.
    cycle="20260101-bootstrap"
    cmd="$(printf '*** Begin Patch\n*** Add File: .sage/work/%s/brief.md\n+content\n*** Add File: .sage/work/%s/spec.md\n+content\n*** End Patch\n' "$cycle" "$cycle")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active cycle"
}

@test "pre-tool-validate.sh: BUG-F1-1 — bootstrap rejected when paths escape the new cycle dir" {
    # Bootstrap exception requires paths CONFINED to one new cycle dir + decisions.md.
    # If a patch claims to create a cycle but also writes outside, reject.
    cycle="20260101-bootstrap"
    cmd="$(printf '*** Begin Patch\n*** Add File: .sage/work/%s/manifest.md\n+content\n*** Add File: src/random_file.sh\n+content\n*** End Patch\n' "$cycle")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active cycle"
}

@test "pre-tool-validate.sh: BUG-F1-1 — bootstrap rejected when cycle id has wrong shape" {
    # Bootstrap shape requires id matches YYYYMMDD-<slug>. A bare-word cycle id
    # is suspicious and must not match.
    cmd="$(printf '*** Begin Patch\n*** Add File: .sage/work/random/manifest.md\n+content\n*** End Patch\n')"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "no active cycle"
}

@test "pre-tool-validate.sh: BUG-F1-3 — absolute scope glob in manifest + relative claimed path → ALLOW" {
    # F-1 Phase 1 BUG-F1-3 (third PreToolUse block in T1):
    # When the manifest's scope[] contains ABSOLUTE paths (the natural format an
    # agent who saw absolute paths during T2 might emit) and the agent later
    # supplies a RELATIVE apply_patch path, the case glob match fails because
    # one side is absolute and the other is relative.
    #
    # Fix: pre-tool-validate.sh must normalize scope_globs through normalize_path
    # the same way it normalizes claimed_paths.
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: "20260101-alpha"
status: in-progress
phase: implement
active_session_id: test-uuid
scope:
  - "$PROJECT_ROOT/.sage/work/20260101-alpha/*"
  - "$PROJECT_ROOT/scripts/health-check.sh"
---
# 20260101-alpha
EOF
    cmd="$(make_patch_cmd Add scripts/health-check.sh)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: BUG-F1-3 — absolute scope + truly out-of-scope relative path still rejected" {
    # Regression guard: scope normalization must not make rejection paths leak.
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: "20260101-alpha"
status: in-progress
phase: implement
active_session_id: test-uuid
scope:
  - "$PROJECT_ROOT/scripts/*"
---
# 20260101-alpha
EOF
    cmd="$(make_patch_cmd Add docs/leak.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "docs/leak.md"
}

@test "pre-tool-validate.sh: BUG-F1-5 — manifest with empty scope still allows cycle-self files (.sage/work/<id>/**)" {
    # F-1 re-run #1 surfaced this: agents emit manifests without `scope:` field.
    # Predicate must implicitly allow the cycle's OWN dir + .sage/decisions.md
    # so spec.md / plan.md / manifest.md updates inside the cycle never block.
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: "20260101-alpha"
status: in-progress
active_session_id: test-uuid
---
EOF
    cmd="$(make_patch_cmd Update "$cycle_dir/spec.md")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: BUG-F1-5 — .sage/decisions.md always implicitly in-scope" {
    # decisions.md is the shared reasoning log — every cycle close writes to it.
    # Must be writable regardless of manifest's `scope:` contents.
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: "20260101-alpha"
status: in-progress
active_session_id: test-uuid
scope:
  - "scripts/health-check.sh"
---
EOF
    cmd="$(make_patch_cmd Update "$PROJECT_ROOT/.sage/decisions.md")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: BUG-F1-5 — narrowed scope still allows cycle-self files (close-cycle case)" {
    # F-1 re-run T5: scope was narrowed to `scripts/health-check.sh`,
    # then agent tries to flip plan.md/manifest.md status to completed.
    # Without implicit scope-self, this blocks. With it, cycle close works.
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: "20260101-alpha"
status: in-progress
active_session_id: test-uuid
scope:
  - "scripts/health-check.sh"
---
EOF
    cmd="$(make_patch_cmd Update "$cycle_dir/plan.md")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: BUG-F1-5 — cross-cycle path still rejected (no over-broad allow)" {
    # Implicit scope-self only covers the ACTIVE cycle's dir, not other cycles.
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-alpha"
    other_dir="$PROJECT_ROOT/.sage/work/20260102-beta"
    mkdir -p "$cycle_dir" "$other_dir"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: "20260101-alpha"
status: in-progress
active_session_id: test-uuid
scope:
  - "scripts/*"
---
EOF
    cmd="$(make_patch_cmd Update "$other_dir/spec.md")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"outside cycle scope"* ]]
}

@test "pre-tool-validate.sh: macOS /private prefix on apply_patch path → stripped before scope check" {
    # macOS /var → /private/var symlink: apply_patch DSL may carry the
    # /private prefix while the cycle scope globs are project-relative.
    # Normalization strips both variants of the cwd prefix.
    make_cycle_with_scope "20260101-alpha" "in-progress" "AGENTS.md"
    abs_path="/private${PROJECT_ROOT}/AGENTS.md"
    case "$PROJECT_ROOT" in
        /private/*) skip "PROJECT_ROOT already canonical with /private — case covered by sibling test" ;;
    esac
    cmd="$(make_patch_cmd Update "$abs_path")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    grep -q '"AGENTS.md"' "$log"
}

@test "pre-tool-validate.sh: architect ADR docs do not count as Moderate+ implementation files" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-architect"
    mkdir -p "$cycle_dir" "$PROJECT_ROOT/.sage/docs"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: "20260101-architect"
workflow: architect
status: in-progress
phase: design
active_session_id: test-uuid
scope:
  - ".sage/work/20260101-architect/*"
  - ".sage/docs/decision-codex-*.md"
---
EOF
    printf '{"session_id":"test-uuid","cycle_id":"20260101-architect","files":[".sage/docs/decision-codex-a.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    printf '{"session_id":"test-uuid","cycle_id":"20260101-architect","files":[".sage/docs/decision-codex-b.md"]}\n' >> "$PROJECT_ROOT/.sage/.session-mutations.log"
    cmd="$(make_patch_cmd Update ".sage/docs/decision-codex-v11-layered-operating-model.md")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: bootstrap allows manifest creation when target cycle dir already exists but is empty" {
    cycle="20260101-empty-bootstrap"
    mkdir -p "$PROJECT_ROOT/.sage/work/$cycle"
    cmd="$(printf '*** Begin Patch\n*** Add File: .sage/work/%s/manifest.md\n+content\n*** Add File: .sage/work/%s/brief.md\n+content\n*** End Patch\n' "$cycle" "$cycle")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: safe auto-fix adds same-cycle architect doc scope and logs audit evidence" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-architect"
    mkdir -p "$cycle_dir" "$PROJECT_ROOT/.sage/docs"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: "20260101-architect"
workflow: architect
status: in-progress
phase: design
active_session_id: test-uuid
scope:
  - ".sage/work/20260101-architect/*"
---
EOF
    cmd="$(make_patch_cmd Add ".sage/docs/decision-codex-v11-example.md")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    grep -q '.sage/docs/decision-codex-\*.md' "$cycle_dir/manifest.md"
    log="$PROJECT_ROOT/.sage/.auto-fixes.log"
    [ -f "$log" ]
    tail -n1 "$log" | jq -e '.kind == "safe_auto_fix"' >/dev/null
    tail -n1 "$log" | jq -e '.fix == "manifest_scope_add"' >/dev/null
    tail -n1 "$log" | jq -e '.severity == "info"' >/dev/null
    tail -n1 "$log" | jq -e '.why_safe | test("reversible")' >/dev/null
}

@test "pre-tool-validate.sh: safe auto-fix creates missing scope key for architect doc metadata repair" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-architect"
    mkdir -p "$cycle_dir" "$PROJECT_ROOT/.sage/docs"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: "20260101-architect"
workflow: architect
status: in-progress
phase: design
active_session_id: test-uuid
---
EOF
    cmd="$(make_patch_cmd Add ".sage/docs/analysis-codex-v11-example.md")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    grep -q '^scope:' "$cycle_dir/manifest.md"
    grep -q '.sage/docs/analysis-codex-\*.md' "$cycle_dir/manifest.md"
}

@test "pre-tool-validate.sh: safe auto-fix does not expand scope for implementation paths" {
    cycle_dir="$PROJECT_ROOT/.sage/work/20260101-architect"
    mkdir -p "$cycle_dir"
    cat > "$cycle_dir/manifest.md" <<EOF
---
cycle_id: "20260101-architect"
workflow: architect
status: in-progress
phase: design
active_session_id: test-uuid
scope:
  - ".sage/work/20260101-architect/*"
---
EOF
    cmd="$(make_patch_cmd Add "src/surprise.sh")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "BLOCKING"
    echo "$output" | grep -q "outside cycle scope"
    [ ! -f "$PROJECT_ROOT/.sage/.auto-fixes.log" ]
}

@test "pre-tool-validate.sh: absolute path outside target repo hard-stops as out-of-scope ownership issue" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    outside_dir="$(mktemp -d -t sage_other_repo.XXXXXX)"
    outside_path="$outside_dir/src/leak.sh"
    cmd="$(make_patch_cmd Add "$outside_path")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    rm -rf "$outside_dir"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "outside cycle scope"
    echo "$output" | grep -q "$outside_path"
}

@test "pre-tool-validate.sh: cross-repo new intake manifest is allowed as capture only" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    outside_dir="$(mktemp -d -t sage_other_repo.XXXXXX)"
    mkdir -p "$outside_dir/.sage/work"
    outside_path="$outside_dir/.sage/work/20260102-cross-repo-finding/manifest.md"
    cmd="$(make_patch_cmd Add "$outside_path")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    rm -rf "$outside_dir"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.session-mutations.log"
    [ -f "$log" ]
    grep -q "$outside_path" "$log"
    tail -n1 "$log" | jq -e '.cycle_id == "" and .mutation_kind == "cross_repo_new_intake"' >/dev/null
}

@test "pre-tool-validate.sh: cross-repo SageDocs add-only is blocked in M1" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    outside_dir="$(mktemp -d -t sage_other_repo.XXXXXX)"
    mkdir -p "$outside_dir/.sage/docs"
    outside_path="$outside_dir/.sage/docs/analysis-cross-repo.md"
    cmd="$(make_patch_cmd Add "$outside_path")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    rm -rf "$outside_dir"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "outside cycle scope"
}

@test "pre-tool-validate.sh: cross-repo intake blocks existing manifest edit" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    outside_dir="$(mktemp -d -t sage_other_repo.XXXXXX)"
    outside_cycle="$outside_dir/.sage/work/20260102-cross-repo-finding"
    mkdir -p "$outside_cycle"
    printf -- '---\nstatus: intake\n---\n' > "$outside_cycle/manifest.md"
    cmd="$(make_patch_cmd Update "$outside_cycle/manifest.md")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    rm -rf "$outside_dir"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "outside cycle scope"
}

@test "pre-tool-validate.sh: cross-repo intake blocks second file" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    outside_dir="$(mktemp -d -t sage_other_repo.XXXXXX)"
    mkdir -p "$outside_dir/.sage/work"
    cmd="$(printf '*** Begin Patch\n*** Add File: %s/.sage/work/20260102-cross-repo-finding/manifest.md\n+---\n+status: intake\n+---\n*** Add File: %s/.sage/work/20260102-cross-repo-finding/notes.md\n+notes\n*** End Patch\n' "$outside_dir" "$outside_dir")"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    rm -rf "$outside_dir"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "outside cycle scope"
}
