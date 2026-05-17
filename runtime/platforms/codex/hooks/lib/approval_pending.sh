#!/usr/bin/env bash
# approval_pending.sh — per-session developer override latch for Codex hooks.

approval_pending_path() {
    printf '%s/.sage/.approval-pending' "$1"
}

approval_pending_default_doc() {
    printf '{"version":1,"sessions":{}}\n'
}

approval_pending_read_doc() {
    local path="$1"
    if [ -f "$path" ] && jq -e 'type == "object"' "$path" >/dev/null 2>&1; then
        cat "$path"
    else
        approval_pending_default_doc
    fi
}

approval_pending_atomic_write() {
    local path="$1"
    local json="$2"
    local dir tmp

    dir="$(dirname "$path")"
    mkdir -p "$dir"
    tmp="$dir/.approval-pending.$$.${RANDOM}.tmp"
    printf '%s\n' "$json" > "$tmp"
    chmod 0600 "$tmp" 2>/dev/null || true
    mv "$tmp" "$path"
}

approval_pending_lock_path() {
    printf '%s.lock' "$(approval_pending_path "$1")"
}

approval_pending_write_pending_unlocked() {
    local cwd="$1"
    local session_id="$2"
    local turn_id="$3"
    local tool_name="$4"
    local reason="$5"
    local path ts doc updated

    path="$(approval_pending_path "$cwd")"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    doc="$(approval_pending_read_doc "$path")"
    updated="$(printf '%s' "$doc" | jq -c \
        --arg sid "$session_id" \
        --arg turn "$turn_id" \
        --arg ts "$ts" \
        --arg tool "$tool_name" \
        --arg reason "$reason" \
        '.version = 1
         | .sessions = (.sessions // {})
         | .sessions[$sid] = {
             state: "pending",
             session_id: $sid,
             turn_id: $turn,
             ts: $ts,
             tool_name: $tool,
             reason: $reason
           }')"
    approval_pending_atomic_write "$path" "$updated"
}

approval_pending_write_pending() {
    local cwd="$1"
    local lock

    lock="$(approval_pending_lock_path "$cwd")"
    mkdir -p "$(dirname "$lock")"
    if command -v flock >/dev/null 2>&1; then
        (
            flock -x 9
            approval_pending_write_pending_unlocked "$@"
        ) 9>"$lock"
    else
        approval_pending_write_pending_unlocked "$@"
    fi
}

approval_pending_approve_unlocked() {
    local cwd="$1"
    local session_id="$2"
    local turn_id="$3"
    local path ts doc updated

    path="$(approval_pending_path "$cwd")"
    doc="$(approval_pending_read_doc "$path")"
    if ! printf '%s' "$doc" | jq -e --arg sid "$session_id" '.sessions[$sid].state == "pending"' >/dev/null 2>&1; then
        return 1
    fi

    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    updated="$(printf '%s' "$doc" | jq -c \
        --arg sid "$session_id" \
        --arg turn "$turn_id" \
        --arg ts "$ts" \
        '.version = 1
         | .sessions = (.sessions // {})
         | .sessions[$sid].state = "approved"
         | .sessions[$sid].approved_turn_id = $turn
         | .sessions[$sid].approved_ts = $ts')"
    approval_pending_atomic_write "$path" "$updated"
}

approval_pending_approve() {
    local cwd="$1"
    local lock

    lock="$(approval_pending_lock_path "$cwd")"
    mkdir -p "$(dirname "$lock")"
    if command -v flock >/dev/null 2>&1; then
        (
            flock -x 9
            approval_pending_approve_unlocked "$@"
        ) 9>"$lock"
    else
        approval_pending_approve_unlocked "$@"
    fi
}

approval_pending_reject_unlocked() {
    local cwd="$1"
    local session_id="$2"
    local path doc updated

    path="$(approval_pending_path "$cwd")"
    doc="$(approval_pending_read_doc "$path")"
    if ! printf '%s' "$doc" | jq -e --arg sid "$session_id" '.sessions[$sid] != null' >/dev/null 2>&1; then
        return 1
    fi

    updated="$(printf '%s' "$doc" | jq -c --arg sid "$session_id" '
        .version = 1
        | .sessions = (.sessions // {})
        | del(.sessions[$sid])')"
    approval_pending_atomic_write "$path" "$updated"
}

approval_pending_reject() {
    local cwd="$1"
    local lock

    lock="$(approval_pending_lock_path "$cwd")"
    mkdir -p "$(dirname "$lock")"
    if command -v flock >/dev/null 2>&1; then
        (
            flock -x 9
            approval_pending_reject_unlocked "$@"
        ) 9>"$lock"
    else
        approval_pending_reject_unlocked "$@"
    fi
}

approval_pending_consume_approved_unlocked() {
    local cwd="$1"
    local session_id="$2"
    local path doc updated

    path="$(approval_pending_path "$cwd")"
    doc="$(approval_pending_read_doc "$path")"
    if ! printf '%s' "$doc" | jq -e --arg sid "$session_id" '.sessions[$sid].state == "approved"' >/dev/null 2>&1; then
        return 1
    fi

    updated="$(printf '%s' "$doc" | jq -c --arg sid "$session_id" '
        .version = 1
        | .sessions = (.sessions // {})
        | del(.sessions[$sid])')"
    approval_pending_atomic_write "$path" "$updated"
}

approval_pending_consume_approved() {
    local cwd="$1"
    local lock

    lock="$(approval_pending_lock_path "$cwd")"
    mkdir -p "$(dirname "$lock")"
    if command -v flock >/dev/null 2>&1; then
        (
            flock -x 9
            approval_pending_consume_approved_unlocked "$@"
        ) 9>"$lock"
    else
        approval_pending_consume_approved_unlocked "$@"
    fi
}
