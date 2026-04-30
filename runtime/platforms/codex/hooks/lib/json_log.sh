#!/usr/bin/env bash
# json_log.sh — atomic JSON-line append helper for Sage Codex hooks.
#
# Usage (sourced by hook scripts):
#   source "$(dirname "$0")/lib/json_log.sh"
#   json_log_append "<log_path>" "<json_line>"
#
# Strategy:
#   - flock(1) available + JSON_LOG_FORCE_PLAIN unset → exclusive fd lock.
#   - Otherwise → POSIX O_APPEND plain `>>` (atomic for short writes
#     under PIPE_BUF; spec §6.6 fallback).
#
# v1 spec ref: §6.6 (cross-script common helpers).
# v1 plan ref: T1.1 (Group A foundation).

_JSON_LOG_HAS_FLOCK=0
if command -v flock >/dev/null 2>&1; then
    _JSON_LOG_HAS_FLOCK=1
fi

json_log_append() {
    local log_path="$1"
    local json_line="$2"
    local log_dir
    log_dir="$(dirname "$log_path")"
    [ -d "$log_dir" ] || mkdir -p "$log_dir" 2>/dev/null || return 1

    if [ "$_JSON_LOG_HAS_FLOCK" = "1" ] && [ -z "${JSON_LOG_FORCE_PLAIN:-}" ]; then
        (
            flock -x 9
            printf '%s\n' "$json_line" >> "$log_path"
        ) 9>"${log_path}.lock"
    else
        printf '%s\n' "$json_line" >> "$log_path"
    fi
}
