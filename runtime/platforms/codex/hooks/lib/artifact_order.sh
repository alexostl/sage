#!/usr/bin/env bash
# Shared helpers for the Standard+ fix artifact-order invariant.

is_cycle_artifact_path() {
    local path="$1"
    local cycle="$2"
    case "$path" in
        ".sage/work/$cycle/"*|".sage/decisions.md") return 0 ;;
        *) return 1 ;;
    esac
}

is_documentation_artifact_path() {
    local path="$1"
    case "$path" in
        .sage/docs/*|.sage-memory/*) return 0 ;;
        *) return 1 ;;
    esac
}

count_prior_impl_files() {
    local session_log="$1"
    local session_id="$2"
    local cycle_id="$3"

    [ -f "$session_log" ] || {
        printf '0\n'
        return 0
    }

    jq -sr --arg sid "$session_id" --arg cycle "$cycle_id" '
        [.[] | select(.session_id == $sid and (.cycle_id // "") == $cycle)
         | .files[]?
         | select((startswith(".sage/work/" + $cycle + "/") | not) and . != ".sage/decisions.md")
         | select((startswith(".sage/docs/") or startswith(".sage-memory/")) | not)]
        | length
    ' "$session_log" 2>/dev/null || printf '0\n'
}

moderate_fix_artifacts_missing() {
    local cycle_dir="$1"
    local manifest="$2"
    local session_log="$3"
    local session_id="$4"
    local cycle_id="$5"
    shift 5

    local current_impl_count=0
    local path
    for path in "$@"; do
        if ! is_cycle_artifact_path "$path" "$cycle_id" && ! is_documentation_artifact_path "$path"; then
            current_impl_count=$((current_impl_count + 1))
        fi
    done

    [ "$current_impl_count" -gt 0 ] || return 1
    [ -f "$cycle_dir/plan.md" ] && [ -f "$manifest" ] && return 1

    local prior_impl_count
    prior_impl_count="$(count_prior_impl_files "$session_log" "$session_id" "$cycle_id")"
    case "$prior_impl_count" in ''|*[!0-9]*) prior_impl_count=0 ;; esac

    [ $((prior_impl_count + current_impl_count)) -ge 3 ]
}
