#!/usr/bin/env bash
# pre-tool-validate.sh — Codex PreToolUse(apply_patch). v1 cycle-scope-only.
# Spec §6.3 / §15.3 / §15.4. Plan T1.5 (≤80 LOC ceiling).
set -euo pipefail
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/json_log.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/active_init.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/path_normalize.sh"

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

# Parse apply_patch DSL — extract Add|Update|Delete File paths.
claimed_paths=()
while IFS= read -r line; do
    case "$line" in
        '*** Add File: '*|'*** Update File: '*|'*** Delete File: '*)
            claimed_paths+=("$(normalize_path "${line#*File: }" "$cwd")") ;;
    esac
done <<< "$cmd"

# Empty patch — Codex rejects on its own; not our role to mirror.
[ "${#claimed_paths[@]}" -eq 0 ] && exit 0

cycle_dir="$(active_init_path "$cwd")"
if [ -z "$cycle_dir" ]; then
    # shellcheck disable=SC2016
    printf 'Sage: no active cycle. Run `/sage:build` (or `/sage:fix`, `/sage:architect`) to start a workflow before mutating files.\n' >&2
    exit 2
fi

cycle_id="$(basename "$cycle_dir")"
manifest="$cycle_dir/manifest.md"
scope_globs=()
while IFS= read -r line; do
    [ -n "$line" ] && scope_globs+=("$line")
done < <(yq eval '.scope[]' "$manifest" 2>/dev/null || true)

# ${arr[@]+...} guards empty-array under set -u on bash 3.2 macOS.
out_of_scope=()
for path in "${claimed_paths[@]}"; do
    matched=0
    for glob in ${scope_globs[@]+"${scope_globs[@]}"}; do
        # shellcheck disable=SC2254
        case "$path" in $glob) matched=1; break ;; esac
    done
    [ "$matched" -eq 0 ] && out_of_scope+=("$path")
done

if [ "${#out_of_scope[@]}" -gt 0 ]; then
    printf 'Sage: paths outside cycle scope: %s. Active cycle: %s. Allowed scope: %s.\n' \
        "${out_of_scope[*]}" "$cycle_id" "${scope_globs[*]:-(none)}" >&2
    exit 2
fi

# Allow — log session mutation for ADR-7 audit.
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
session_id="$(printf '%s' "$payload" | jq -r '.session_id // "unknown"')"
files_json="$(printf '%s\n' "${claimed_paths[@]}" | jq -R . | jq -sc .)"
log_line="$(jq -nc --arg sid "$session_id" --arg ts "$ts" --arg cycle "$cycle_id" --argjson files "$files_json" \
    '{session_id:$sid, ts:$ts, cycle_id:$cycle, files:$files}')"
json_log_append "$cwd/.sage/.session-mutations.log" "$log_line"

exit 0
