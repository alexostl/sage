#!/usr/bin/env bats
# user-prompt-submit.sh: literal A/a developer override approval hook.

setup() {
    HOOK="$BATS_TEST_DIRNAME/../user-prompt-submit.sh"
    [ -f "$HOOK" ] || skip "user-prompt-submit.sh not found at $HOOK"
    PROJECT_ROOT="$(mktemp -d -t user_prompt_submit_bats.XXXXXX)"
    mkdir -p "$PROJECT_ROOT/.sage"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

make_payload() {
    local prompt="$1"
    local session_id="${2:-test-uuid}"
    jq -nc --arg cwd "$PROJECT_ROOT" --arg sid "$session_id" --arg prompt "$prompt" '{
        session_id: $sid,
        turn_id: "turn-2",
        cwd: $cwd,
        hook_event_name: "UserPromptSubmit",
        prompt: $prompt
    }'
}

write_pending() {
    local session_id="${1:-test-uuid}"
    jq -n --arg sid "$session_id" '{
        version: 1,
        sessions: {
            ($sid): {
                state: "pending",
                session_id: $sid,
                turn_id: "turn-1",
                ts: "2026-05-17T00:00:00Z",
                tool_name: "apply_patch",
                reason: "blocked"
            }
        }
    }' > "$PROJECT_ROOT/.sage/.approval-pending"
}

state_for() {
    local session_id="${1:-test-uuid}"
    jq -r --arg sid "$session_id" '.sessions[$sid].state // "missing"' "$PROJECT_ROOT/.sage/.approval-pending"
}

@test "user-prompt-submit.sh: prompt A approves pending override" {
    write_pending
    payload="$(make_payload "A")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ "$(state_for)" = "approved" ]
}

@test "user-prompt-submit.sh: prompt a approves pending override" {
    write_pending
    payload="$(make_payload "a")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ "$(state_for)" = "approved" ]
}

@test "user-prompt-submit.sh: prompt [A] cancels without approval" {
    write_pending
    payload="$(make_payload "[A]")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ "$(state_for)" = "missing" ]
}

@test "user-prompt-submit.sh: prompt tak cancels without approval" {
    write_pending
    payload="$(make_payload "tak")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ "$(state_for)" = "missing" ]
}

@test "user-prompt-submit.sh: prompt A with other text cancels without approval" {
    write_pending
    payload="$(make_payload "A, dzialaj")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ "$(state_for)" = "missing" ]
}

@test "user-prompt-submit.sh: no pending record does not create approval" {
    payload="$(make_payload "A")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ ! -f "$PROJECT_ROOT/.sage/.approval-pending" ]
}

@test "user-prompt-submit.sh: pending from another session is not approved" {
    write_pending "other-session"
    payload="$(make_payload "A" "test-uuid")"
    run bash -c "echo '$payload' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ "$(state_for other-session)" = "pending" ]
    [ "$(state_for test-uuid)" = "missing" ]
}

@test "user-prompt-submit.sh: invalid JSON exits 0 and does not create approval" {
    run bash -c "printf '%s' '{' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ ! -f "$PROJECT_ROOT/.sage/.approval-pending" ]
}
