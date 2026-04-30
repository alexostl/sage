#!/usr/bin/env bats
# T1.6 — post-tool-check.sh: PostToolUse hook (apply_patch matcher).
#
# Plan contract (T1.6): §15.3 + §15.4.
#
# §15.3 cases:
#   - Diff matches → no incident.
#   - Diff mismatch → claim_no_op incident logged.
#   - Broken frontmatter file → broken_frontmatter incident logged.
#
# §15.4 parity (vs sage_check_post_mutation MCP tool):
#   - Check A (diff-claim) — claim_no_op + unclaimed_change incidents.
#   - Check C (frontmatter via yq) — broken_frontmatter incident.
#   - Check B (symbol existence) — absent in v1.
#
# §6.4 invariant: never blocks (exit 0 always); short-circuits on
# tool_response.metadata.exit_code ≠ 0 (apply_patch failed → no work).

setup() {
    HOOK="$BATS_TEST_DIRNAME/../post-tool-check.sh"
    [ -f "$HOOK" ] || skip "post-tool-check.sh not found at $HOOK"
    [ -x "$HOOK" ] || skip "post-tool-check.sh not executable"
    PROJECT_ROOT="$(mktemp -d -t post_tool_check_bats.XXXXXX)"
    (
        cd "$PROJECT_ROOT" || exit 1
        git init -q -b main
        git config user.email "test@test"
        git config user.name "test"
        echo "seed" > seed.txt
        git add seed.txt
        git commit -q -m "seed"
    )
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

# Helper: build apply_patch DSL command.
make_patch_cmd() {
    local op="$1"
    local path="$2"
    printf '*** Begin Patch\n*** %s File: %s\n+content\n*** End Patch\n' "$op" "$path"
}

# Helper: build PostToolUse payload (PreToolUse + tool_response).
# tool_response is a STRINGIFIED JSON per §6.4.
make_payload() {
    local cmd="$1"
    local exit_code="${2:-0}"
    local cwd="${3:-$PROJECT_ROOT}"
    local cmd_json tool_response_str
    cmd_json="$(printf '%s' "$cmd" | jq -Rs .)"
    tool_response_str="$(jq -nc --argjson ec "$exit_code" \
        '{output:"ok", metadata:{exit_code:$ec, duration_seconds:0.1}}' | jq -Rs .)"
    jq -nc --arg cwd "$cwd" --argjson cmd "$cmd_json" --argjson tr "$tool_response_str" '{
        session_id: "test-uuid",
        turn_id: "turn-1",
        cwd: $cwd,
        hook_event_name: "PostToolUse",
        tool_name: "apply_patch",
        tool_input: { command: $cmd },
        tool_response: $tr
    }'
}

@test "post-tool-check.sh: claimed path matches diff → no incident, exit 0" {
    cd "$PROJECT_ROOT"
    echo "modified" >> seed.txt
    cmd="$(make_patch_cmd Update seed.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "claim_no_op" "$log"
    fi
}

@test "post-tool-check.sh: claimed but unchanged → claim_no_op incident logged" {
    cd "$PROJECT_ROOT"
    cmd="$(make_patch_cmd Update seed.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    [ -f "$log" ]
    grep -q "claim_no_op" "$log"
    grep -q "seed.txt" "$log"
}

@test "post-tool-check.sh: claimed new untracked file IS on disk → no claim_no_op (T2.1 bugfix)" {
    # Real-Codex T2.1 finding (2026-04-30): apply_patch creates a new
    # file. `git diff --name-only HEAD` misses untracked files — so the
    # M1 implementation logged a false claim_no_op even though the file
    # was correctly written. Fix: detect via `git status --porcelain`
    # which captures both modified-tracked AND untracked files.
    cd "$PROJECT_ROOT"
    mkdir -p src
    echo "world" > src/hello.txt   # simulate apply_patch having written the file
    cmd="$(make_patch_cmd Add src/hello.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "claim_no_op" "$log"
    fi
}

@test "post-tool-check.sh: repo with no commits, claimed file written → no false claim_no_op" {
    # Companion bug surface: in a fresh `git init` repo (no commits
    # yet), `git diff --name-only HEAD` returns empty, again triggering
    # false claim_no_op for every claimed path.
    NOCMTREE="$(mktemp -d -t no_commits.XXXXXX)"
    cd "$NOCMTREE"
    git init -q -b main
    mkdir -p src
    echo "world" > src/hello.txt
    cmd="$(make_patch_cmd Add src/hello.txt)"
    payload="$(make_payload "$cmd" 0 "$NOCMTREE")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$NOCMTREE/.sage/.mcp-incidents.log"
    found_no_op=0
    [ -f "$log" ] && grep -q "claim_no_op" "$log" && found_no_op=1
    rm -rf "$NOCMTREE"
    [ "$found_no_op" -eq 0 ]
}

@test "post-tool-check.sh: tool_response exit_code != 0 → early exit, no Check A" {
    cd "$PROJECT_ROOT"
    cmd="$(make_patch_cmd Update seed.txt)"
    payload="$(make_payload "$cmd" 1)"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "claim_no_op" "$log"
    fi
}

@test "post-tool-check.sh: broken frontmatter in .sage/*.md → broken_frontmatter incident" {
    cd "$PROJECT_ROOT"
    mkdir -p .sage/work/20260101-alpha
    cat > .sage/work/20260101-alpha/spec.md <<'EOF'
---
status: in-progress
title: "missing close
broken: yaml: : :
---
# spec
EOF
    git add .sage/work/20260101-alpha/spec.md
    cmd="$(make_patch_cmd Add .sage/work/20260101-alpha/spec.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    [ -f "$log" ]
    grep -q "broken_frontmatter" "$log"
}

@test "post-tool-check.sh: valid frontmatter in .sage/*.md → no broken_frontmatter incident" {
    cd "$PROJECT_ROOT"
    mkdir -p .sage/work/20260101-alpha
    cat > .sage/work/20260101-alpha/spec.md <<'EOF'
---
status: in-progress
title: "OK spec"
phase: design
---
# spec
EOF
    git add .sage/work/20260101-alpha/spec.md
    cmd="$(make_patch_cmd Add .sage/work/20260101-alpha/spec.md)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "broken_frontmatter" "$log"
    fi
}

@test "post-tool-check.sh: incident JSON line is valid (parseable + has severity)" {
    cd "$PROJECT_ROOT"
    cmd="$(make_patch_cmd Update seed.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    line="$(tail -n1 "$log")"
    echo "$line" | jq -e '.kind' >/dev/null
    echo "$line" | jq -e '.severity' >/dev/null
    echo "$line" | jq -e '.ts' >/dev/null
}

@test "post-tool-check.sh: invalid JSON payload → exit 0 (never blocks per §6.4)" {
    cd "$PROJECT_ROOT"
    run bash -c "echo 'not-json' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "post-tool-check.sh: empty patch (no claimed paths) → exit 0, no incidents" {
    cd "$PROJECT_ROOT"
    cmd="*** Begin Patch\n*** End Patch\n"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "post-tool-check.sh: hook bookkeeping logs in .sage/ are excluded from unclaimed_change" {
    # Real-Codex T2.1a finding (2026-04-30): pre-tool-validate.sh appends to
    # .sage/.session-mutations.log BEFORE apply_patch runs. PostToolUse then
    # sees that file as modified-but-not-claimed → false unclaimed_change
    # incident on every successful mutation. Fix: exclude .sage/.*.log paths
    # from the diff-claim comparison since they are hook-generated, not
    # agent-written.
    cd "$PROJECT_ROOT"
    # Simulate the hook bookkeeping side-effect.
    mkdir -p .sage
    printf '{"session":"prior"}\n' > .sage/.session-mutations.log
    printf '{"prev":"warn"}\n' > .sage/.mcp-incidents.log
    git add .
    git commit -q -m "with bookkeeping baseline"
    # Now agent mutates a single file in scope.
    echo "modified" >> seed.txt
    # And pre-tool-validate appended a new line to .session-mutations.log
    # (simulating its own behaviour during this turn).
    printf '{"session":"now"}\n' >> .sage/.session-mutations.log
    cmd="$(make_patch_cmd Update seed.txt)"
    payload="$(make_payload "$cmd")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    # The bookkeeping file should NOT appear as unclaimed_change.
    found_unclaimed_log=0
    [ -f "$log" ] && grep -q '"file":".sage/.session-mutations.log"' "$log" && found_unclaimed_log=1
    [ "$found_unclaimed_log" -eq 0 ]
}
