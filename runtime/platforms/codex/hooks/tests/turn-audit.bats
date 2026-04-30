#!/usr/bin/env bats
# T1.7 — turn-audit.sh: Stop event hook (partial ADR-7 surface).
#
# Plan contract (T1.7): §15.3 + §15.4.
#
# §15.3 cases:
#   - Normal turn → audit runs (session-mutations vs claimed paths +
#     phase_jump_observed probe).
#   - Skipped checks (orphan-approval, approval-coupling, dead-MCP)
#     verifiably do NOT fire.
#
# §6.5 invariant: never blocks (exit 0 always per ADR-7 D5).

setup() {
    HOOK="$BATS_TEST_DIRNAME/../turn-audit.sh"
    [ -f "$HOOK" ] || skip "turn-audit.sh not found at $HOOK"
    [ -x "$HOOK" ] || skip "turn-audit.sh not executable"
    PROJECT_ROOT="$(mktemp -d -t turn_audit_bats.XXXXXX)"
    (
        cd "$PROJECT_ROOT" || exit 1
        git init -q -b main
        git config user.email "test@test"
        git config user.name "test"
        echo "seed" > seed.txt
        git add seed.txt
        git commit -q -m "seed"
    )
    mkdir -p "$PROJECT_ROOT/.sage"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

# Helper: build Stop payload.
make_payload() {
    local session_id="${1:-test-session}"
    local turn_id="${2:-turn-1}"
    local cwd="${3:-$PROJECT_ROOT}"
    jq -nc --arg sid "$session_id" --arg tid "$turn_id" --arg cwd "$cwd" '{
        session_id: $sid,
        turn_id: $tid,
        ts: "2026-04-30T12:00:00Z",
        cwd: $cwd,
        hook_event_name: "Stop"
    }'
}

# Helper: append a session-mutations log line.
log_mutation() {
    local sid="$1"
    local tid="$2"
    shift 2
    local files_json
    files_json=$(printf '%s\n' "$@" | jq -R . | jq -sc .)
    jq -nc --arg sid "$sid" --arg tid "$tid" --argjson f "$files_json" \
        '{session_id:$sid, turn_id:$tid, ts:"2026-04-30T12:00:00Z", files:$f}' \
        >> "$PROJECT_ROOT/.sage/.session-mutations.log"
}

@test "turn-audit.sh: no mutations + no diff → exit 0, no incidents" {
    payload="$(make_payload)"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "bypass_mutation\|phase_jump_observed" "$log"
    fi
}

@test "turn-audit.sh: claimed mutation matches git diff → no bypass incident" {
    cd "$PROJECT_ROOT"
    log_mutation "test-session" "turn-1" "seed.txt"
    echo "modified" >> seed.txt
    payload="$(make_payload "test-session" "turn-1")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "bypass_mutation" "$log"
    fi
}

@test "turn-audit.sh: git diff shows mutation NOT in session log → bypass_mutation incident" {
    cd "$PROJECT_ROOT"
    # Don't log to session-mutations — simulate bash sed -i bypass.
    echo "modified" >> seed.txt
    payload="$(make_payload "test-session" "turn-1")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    [ -f "$log" ]
    grep -q "bypass_mutation" "$log"
    grep -q "seed.txt" "$log"
}

@test "turn-audit.sh: phase-jump probe — status flipped to completed → phase_jump_observed" {
    cd "$PROJECT_ROOT"
    mkdir -p .sage/work/20260101-alpha
    cat > .sage/work/20260101-alpha/spec.md <<'EOF'
---
status: completed
title: "alpha"
---
EOF
    git add .sage/work/20260101-alpha/spec.md
    log_mutation "test-session" "turn-1" ".sage/work/20260101-alpha/spec.md"
    payload="$(make_payload "test-session" "turn-1")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    [ -f "$log" ]
    grep -q "phase_jump_observed" "$log"
}

@test "turn-audit.sh: SKIPPED checks (orphan-approval, dead-MCP) do NOT fire (§6.5 deferred)" {
    cd "$PROJECT_ROOT"
    payload="$(make_payload)"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q "orphan_approval\|approval_coupling\|dead_validator" "$log"
    fi
}

@test "turn-audit.sh: exit 0 always (§6.5 invariant — never blocks)" {
    # Test all sorts of weird inputs
    cd "$PROJECT_ROOT"
    run bash -c "echo 'not-json' | '$HOOK'"
    [ "$status" -eq 0 ]
    run bash -c "echo '{}' | '$HOOK'"
    [ "$status" -eq 0 ]
    run bash -c "echo '' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "turn-audit.sh: incident JSON line is valid (parseable + has severity)" {
    cd "$PROJECT_ROOT"
    echo "modified" >> seed.txt
    payload="$(make_payload)"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    line="$(tail -n1 "$log")"
    echo "$line" | jq -e '.kind' >/dev/null
    echo "$line" | jq -e '.severity' >/dev/null
    echo "$line" | jq -e '.ts' >/dev/null
}

@test "turn-audit.sh: only this session's mutations counted (filter by session_id)" {
    cd "$PROJECT_ROOT"
    # Other session logged the mutation (from a different shell)
    log_mutation "other-session" "turn-1" "seed.txt"
    echo "modified" >> seed.txt
    payload="$(make_payload "test-session" "turn-1")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    # bypass should fire — current session didn't claim, but git shows change
    [ -f "$log" ]
    grep -q "bypass_mutation" "$log"
}

@test "turn-audit.sh: untracked file written by bash (no apply_patch) → bypass_mutation incident" {
    # Real-Codex T2.1 finding (2026-04-30): turn-audit used `git diff
    # --name-only HEAD` which misses untracked files. An agent that
    # writes a NEW file via `bash echo > foo` (bypass apply_patch) was
    # NOT detected — bypass_mutation never fired for untracked. Fix:
    # use `git status --porcelain -uall` (same as post-tool-check Check A).
    cd "$PROJECT_ROOT"
    mkdir -p src
    echo "bypass-content" > src/sneaky.txt
    payload="$(make_payload "test-session" "turn-1")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    [ -f "$log" ]
    grep -q "bypass_mutation" "$log"
    grep -q "src/sneaky.txt" "$log"
}

@test "turn-audit.sh: absolute path in session-mutations.log matches relative porcelain → no false bypass" {
    # T2.7 follow-up (2026-04-30): the harness baseline run logged absolute
    # claimed paths to session-mutations.log (Codex 0.126 apply_patch DSL
    # emits absolute) but porcelain was relative → contains() never matched
    # → 18 false bypass_mutation incidents per 5-prompt run. Fix: turn-audit
    # normalizes claimed_paths from log against $cwd before comparing.
    cd "$PROJECT_ROOT"
    abs_path="$PROJECT_ROOT/seed.txt"
    log_mutation "test-session" "turn-1" "$abs_path"
    echo "modified" >> seed.txt
    payload="$(make_payload "test-session" "turn-1")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q '"kind":"bypass_mutation".*"file":"seed.txt"' "$log"
    fi
}

@test "turn-audit.sh: macOS /private prefix on log entry → normalized → no false bypass" {
    cd "$PROJECT_ROOT"
    case "$PROJECT_ROOT" in
        /private/*) skip "PROJECT_ROOT already canonical with /private" ;;
    esac
    abs_path="/private${PROJECT_ROOT}/seed.txt"
    log_mutation "test-session" "turn-1" "$abs_path"
    echo "modified" >> seed.txt
    payload="$(make_payload "test-session" "turn-1")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    if [ -f "$log" ]; then
        ! grep -q '"kind":"bypass_mutation".*"file":"seed.txt"' "$log"
    fi
}

@test "turn-audit.sh: hook bookkeeping logs are excluded from bypass_mutation" {
    # Companion fix to post-tool-check: PreToolUse appended to
    # .sage/.session-mutations.log during the session. Stop hook then
    # sees the file in porcelain but not claimed → false bypass_mutation.
    cd "$PROJECT_ROOT"
    mkdir -p .sage
    printf '{"session":"test-session","files":["seed.txt"]}\n' > .sage/.session-mutations.log
    git add .sage/.session-mutations.log
    git commit -q -m "with bookkeeping baseline"
    # During the session, hook appended a new line.
    printf '{"session":"test-session","files":["seed.txt"]}\n' >> .sage/.session-mutations.log
    log_mutation "test-session" "turn-1" "seed.txt"
    echo "modified" >> seed.txt
    payload="$(make_payload "test-session" "turn-1")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    log="$PROJECT_ROOT/.sage/.mcp-incidents.log"
    found_bypass_log=0
    [ -f "$log" ] && grep -q '"file":".sage/.session-mutations.log"' "$log" && found_bypass_log=1
    [ "$found_bypass_log" -eq 0 ]
}
