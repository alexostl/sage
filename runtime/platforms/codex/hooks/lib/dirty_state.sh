#!/usr/bin/env bash
# dirty_state.sh — helpers for session dirty-state baseline checks.

dirty_fingerprint() {
    local cwd="$1"
    local path="$2"
    local full="$cwd/$path"
    if [ -f "$full" ]; then
        cksum < "$full" | awk '{print $1 ":" $2}'
    elif [ -d "$full" ]; then
        printf 'dir'
    else
        printf 'missing'
    fi
}

dirty_paths() {
    local cwd="$1"
    (
        cd "$cwd" || exit 0
        if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
            while IFS= read -r line; do
                [ -n "$line" ] || continue
                path="${line:3}"
                case "$path" in .sage/.*.log) continue ;; esac
                printf '%s\n' "$path"
            done < <(git status --porcelain -uall 2>/dev/null || true)
        fi
    )
}

session_baseline_fingerprint() {
    local log="$1"
    local session_id="$2"
    local path="$3"
    [ -f "$log" ] || return 1
    jq -r --arg sid "$session_id" --arg p "$path" '
        select(.kind == "session_baseline" and .session_id == $sid) |
        .files[]? |
        select(.path == $p) |
        .fingerprint
    ' "$log" 2>/dev/null | tail -1
}
