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
    echo "$output" | grep -q "same turn"
    echo "$output" | grep -q "user approval"
    echo "$output" | grep -q "src/from-self-created-manifest.txt"
}

@test "pre-tool-validate.sh: same-turn plan still cannot authorize source file_change" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    touch "$PROJECT_ROOT/.sage/work/20260101-alpha/plan.md"
    printf '{"session_id":"test-uuid","turn_id":"turn-1","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/manifest.md",".sage/work/20260101-alpha/plan.md",".sage/decisions.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload add "$PROJECT_ROOT/src/after-plan.txt")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "same turn"
    echo "$output" | grep -q "user approval"
}

@test "pre-tool-validate.sh: prior-turn plan can authorize source file_change" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "src/**"
    touch "$PROJECT_ROOT/.sage/work/20260101-alpha/plan.md"
    printf '{"session_id":"test-uuid","turn_id":"turn-0","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/manifest.md",".sage/work/20260101-alpha/plan.md",".sage/decisions.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload add "$PROJECT_ROOT/src/after-approval-turn.txt")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-tool-validate.sh: same-turn manifest cannot authorize AGENTS.md" {
    make_cycle_with_scope "20260101-alpha" "in-progress" "AGENTS.md"
    printf '{"session_id":"test-uuid","turn_id":"turn-1","cycle_id":"20260101-alpha","files":[".sage/work/20260101-alpha/manifest.md",".sage/decisions.md"]}\n' > "$PROJECT_ROOT/.sage/.session-mutations.log"
    payload="$(make_file_change_payload update "$PROJECT_ROOT/AGENTS.md")"
    run bash -c "echo '$payload' | '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "instruction"
    echo "$output" | grep -q "same turn"
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

@test "pre-tool-validate.sh: completed cycle (not in-progress) → exit 2 (no active cycle)" {
    make_cycle_with_scope "20260101-done" "completed" "src/**"
    cmd="$(make_patch_cmd Add src/foo.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 2 ]
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
    make_cycle_with_scope "20260102-newer" "in-progress" "app/**"
    cmd="$(make_patch_cmd Add app/new_feature.sh)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    # newer cycle scope = app/** → allow
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
