#!/usr/bin/env bash
# pre-tool-validate.sh — Codex PreToolUse(apply_patch).
set -euo pipefail
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/json_log.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/active_init.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/path_normalize.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/bootstrap_check.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/artifact_order.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/recovery_autofix.sh"

for tool in jq yq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        # shellcheck disable=SC2016
        printf 'Sage: required tool missing: %s. Install: `brew install jq yq` (macOS) / `apt-get install jq yq` (Debian).\n' "$tool" >&2
        exit 2
    fi
done

payload="$(cat 2>/dev/null || true)"
if ! printf '%s' "$payload" | jq -e . >/dev/null 2>&1; then
    printf 'Sage: pre-tool-validate received invalid JSON payload (fail-closed).\n' >&2
    exit 2
fi

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$PWD"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"
session_id="$(printf '%s' "$payload" | jq -r '.session_id // "unknown"')"

claimed_paths=()
while IFS= read -r line; do
    case "$line" in
        '*** Add File: '*|'*** Update File: '*|'*** Delete File: '*)
            claimed_paths+=("$(normalize_path "${line#*File: }" "$cwd")") ;;
    esac
done <<< "$cmd"

[ "${#claimed_paths[@]}" -eq 0 ] && exit 0

cycle_dir="$(active_init_path "$cwd")"
if [ -z "$cycle_dir" ]; then
    if ! cycle_id="$(bootstrap_cycle_id "$cwd" "${claimed_paths[@]}")"; then
        # shellcheck disable=SC2016
        printf 'Sage: no active cycle. Run `/sage:build` (or `/sage:fix`, `/sage:architect`) to start a workflow before mutating files.\n' >&2
        exit 2
    fi
else
    cycle_id="$(basename "$cycle_dir")"
    manifest="$cycle_dir/manifest.md"
    scope_globs=("$(normalize_path "$cycle_dir/*" "$cwd")" "$(normalize_path "$cwd/.sage/decisions.md" "$cwd")")
    while IFS= read -r line; do
        [ -n "$line" ] && scope_globs+=("$(normalize_path "$line" "$cwd")")
    done < <(manifest_yaml "$manifest" | yq eval '.scope[]' - 2>/dev/null || true)
    out_of_scope=()
    for path in "${claimed_paths[@]}"; do
        matched=0
        for glob in ${scope_globs[@]+"${scope_globs[@]}"}; do
            case "$path" in $glob) matched=1; break ;; esac
        done
        [ "$matched" -eq 0 ] && out_of_scope+=("$path")
    done
    if [ "${#out_of_scope[@]}" -gt 0 ]; then
        if try_safe_scope_autofix "$cwd" "$cycle_id" "$manifest" "$session_id" "${out_of_scope[@]}"; then
            scope_globs=("$(normalize_path "$cycle_dir/*" "$cwd")" "$(normalize_path "$cwd/.sage/decisions.md" "$cwd")")
            while IFS= read -r line; do
                [ -n "$line" ] && scope_globs+=("$(normalize_path "$line" "$cwd")")
            done < <(manifest_yaml "$manifest" | yq eval '.scope[]' - 2>/dev/null || true)
            out_of_scope=()
            for path in "${claimed_paths[@]}"; do
                matched=0
                for glob in ${scope_globs[@]+"${scope_globs[@]}"}; do
                    case "$path" in $glob) matched=1; break ;; esac
                done
                [ "$matched" -eq 0 ] && out_of_scope+=("$path")
            done
        fi
    fi
    if [ "${#out_of_scope[@]}" -gt 0 ]; then
        printf 'Sage: BLOCKING outside cycle scope: %s. Active cycle: %s. Allowed scope: %s. Next legal move: update the approved manifest scope/plan first, or create a minimal intake cycle if this is separate work.\n' \
            "${out_of_scope[*]}" "$cycle_id" "${scope_globs[*]:-(none)}" >&2
        exit 2
    fi

    if moderate_fix_artifacts_missing "$cycle_dir" "$manifest" "$cwd/.sage/.session-mutations.log" "$session_id" "$cycle_id" "${claimed_paths[@]}"; then
        printf 'Sage: BLOCKING Moderate+ fix implementation before approved artifacts. Detected 3+ implementation files before plan.md and manifest.md existed first. Next legal move: write/update those artifacts before code changes; post-hoc artifacts do not cure a code-first violation. Active cycle: %s.\n' "$cycle_id" >&2
        exit 2
    fi
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
files_json="$(printf '%s\n' "${claimed_paths[@]}" | jq -R . | jq -sc .)"
log_line="$(jq -nc --arg sid "$session_id" --arg ts "$ts" --arg cycle "$cycle_id" --argjson files "$files_json" \
    '{session_id:$sid, ts:$ts, cycle_id:$cycle, files:$files}')"
json_log_append "$cwd/.sage/.session-mutations.log" "$log_line"

exit 0
