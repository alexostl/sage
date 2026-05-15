#!/usr/bin/env bash
# session-init.sh — Codex SessionStart hook.
#
# Action sequence (spec §6.1):
#   1. Print Sage banner to stdout (Codex injects as context).
#   2. Trust state check: noop in v1 (Codex only fires hooks on
#      trusted projects per ~/.codex/config.toml trust_level).
#   3. Emit one-line summary for each in-progress / paused / intake cycle.
#   4. Emit last 3 decisions.md entries.
#   5. Exit 0 always (session start must never block).
#
# Failure mode: any error → log to stderr, exit 0. Acceptable
# degradation per spec §6.1.
#
# v1 spec ref: §6.1, §15.3 smoke.
# v1 plan ref: T1.4 (Group B foundation).

set -euo pipefail
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/json_log.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/dirty_state.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/decisions_log.sh"

# Read stdin payload (best-effort; never crash session on bad JSON).
payload=""
if [ ! -t 0 ]; then
    payload="$(cat 2>/dev/null || true)"
fi

# Extract project_dir; fall back to PWD on failure.
project_dir=""
session_id="unknown"
if [ -n "$payload" ] && command -v jq >/dev/null 2>&1; then
    project_dir="$(printf '%s' "$payload" | jq -r '.project_dir // empty' 2>/dev/null || true)"
    session_id="$(printf '%s' "$payload" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
fi
[ -n "$project_dir" ] || project_dir="$PWD"
[ -d "$project_dir" ] || project_dir="$PWD"
[ -n "$session_id" ] || session_id="unknown"

baseline_log="$project_dir/.sage/.session-baseline.log"
if [ -d "$project_dir/.sage" ]; then
    baseline_files='[]'
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        fp="$(dirty_fingerprint "$project_dir" "$path")"
        baseline_files="$(jq -c --arg p "$path" --arg fp "$fp" '. + [{path:$p, fingerprint:$fp}]' <<< "$baseline_files")"
    done < <(dirty_paths "$project_dir")
    baseline_line="$(jq -nc --arg sid "$session_id" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson files "$baseline_files" \
        '{kind:"session_baseline", session_id:$sid, ts:$ts, files:$files}')"
    json_log_append "$baseline_log" "$baseline_line" 2>/dev/null || true
fi

# Step 1 — banner.
printf '=== Sage / Codex — session start ===\n'
printf 'Project: %s\n' "$project_dir"

# Step 3 — active cycles summary.
work_dir="$project_dir/.sage/work"
if [ -d "$work_dir" ] && command -v yq >/dev/null 2>&1; then
    any_active=0
    for manifest in "$work_dir"/*/manifest.md; do
        [ -f "$manifest" ] || continue
        status=$(yq eval '.status // ""' "$manifest" 2>/dev/null || true)
        case "$status" in
            in-progress|paused|intake) ;;
            *) continue ;;
        esac
        cycle_id=$(yq eval '.cycle_id // ""' "$manifest" 2>/dev/null || true)
        title=$(yq eval '.title // ""' "$manifest" 2>/dev/null || true)
        workflow=$(yq eval '.workflow // ""' "$manifest" 2>/dev/null || true)
        phase=$(yq eval '.phase // ""' "$manifest" 2>/dev/null || true)
        if [ -z "$cycle_id" ]; then
            cycle_id=$(basename "$(dirname "$manifest")")
        fi
        if [ "$any_active" = "0" ]; then
            printf '\nActive cycles:\n'
            any_active=1
        fi
        printf '  - [%s] %s — %s/%s (%s)\n' \
            "$status" "$cycle_id" "${workflow:-?}" "${phase:-?}" "${title:-untitled}"
    done
fi

# Step 4 — last 3 decisions.
decisions="$project_dir/.sage/decisions.md"
if [ -f "$decisions" ]; then
    recent_decisions="$(decisions_recent_labels "$decisions" 3)"
    if [ -n "$recent_decisions" ]; then
        printf '\nRecent decisions:\n'
        printf '%s\n' "$recent_decisions"
    fi
fi

printf '\n'
exit 0
