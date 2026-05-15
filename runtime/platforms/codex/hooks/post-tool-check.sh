#!/usr/bin/env bash
# post-tool-check.sh — Codex PostToolUse hook (apply_patch matcher).
#
# Spec §6.4: bash-native v1 lite of sage_check_post_mutation MCP tool.
#   1. Short-circuit if tool_response.metadata.exit_code != 0.
#   2. Check A — diff vs claim mismatch (claim_no_op + unclaimed_change).
#   3. Check C — frontmatter health on touched .sage/**/*.md files.
#   4. Check B — DEFERRED (symbol existence, language parser required).
#   5. Exit 0 always (§6.4 invariant: never blocks per ADR-10).
#
# v1 spec ref: §6.4, §15.3, §15.4.
# v1 plan ref: T1.6 (Group B).

set -euo pipefail
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/json_log.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/path_normalize.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/active_init.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/artifact_order.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/decisions_rotate.sh"

# Pre-flight: jq required to read payload. yq is optional (Check C
# degrades). If jq missing, log skip + exit 0 — never block.
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

payload="$(cat 2>/dev/null || true)"
if ! printf '%s' "$payload" | jq -e . >/dev/null 2>&1; then
    exit 0
fi

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$PWD"

# Step 1 — short-circuit on apply_patch failure.
exit_code="$(printf '%s' "$payload" | jq -r '.tool_response | (try fromjson catch null) | .metadata.exit_code // 0')"
if [ "$exit_code" != "0" ] && [ -n "$exit_code" ]; then
    exit 0
fi

# Parse claimed_paths from apply_patch DSL or native file-change shaped
# payloads. Current Codex hook docs expose file edits through apply_patch/
# Edit/Write aliases; the extra changes[] parsing is defensive for real-agent
# transcript shapes and future hook payloads.
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"
claimed_paths=()
while IFS= read -r line; do
    case "$line" in
        '*** Add File: '*|'*** Update File: '*|'*** Delete File: '*)
            claimed_paths+=("$(normalize_path "${line#*File: }" "$cwd")")
            ;;
    esac
done <<< "$cmd"

while IFS=$'\t' read -r _kind path; do
    [ -n "$path" ] || continue
    claimed_paths+=("$(normalize_path "$path" "$cwd")")
done < <(printf '%s' "$payload" | jq -r '
    (.tool_input.changes // .changes // .item.changes // [])[]? |
    [(.kind // "update"), (.path // empty)] | @tsv
' 2>/dev/null || true)

[ "${#claimed_paths[@]}" -eq 0 ] && exit 0

for p in "${claimed_paths[@]}"; do
    if [ "$p" = ".sage/decisions.md" ]; then
        decisions_rotate_if_needed "$cwd" || true
        break
    fi
done

incidents_log="$cwd/.sage/.mcp-incidents.log"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
session_id="$(printf '%s' "$payload" | jq -r '.session_id // "unknown"')"

emit_incident() {
    local kind="$1"
    local file="$2"
    local sev="${3:-warn}"
    local line
    line="$(jq -nc --arg kind "$kind" --arg file "$file" --arg sev "$sev" \
        --arg sid "$session_id" --arg ts "$ts" \
        '{kind:$kind, file:$file, severity:$sev, session_id:$sid, ts:$ts}')"
    json_log_append "$incidents_log" "$line"
}

# Close-cycle contract: flipping a manifest to completed should be the final
# mutation by default. If the same patch also touches implementation/public
# files, surface a critical incident unless the manifest explicitly carries a
# pre-flip closeout marker.
completed_cycles=()
for p in "${claimed_paths[@]}"; do
    case "$p" in
        .sage/work/*/manifest.md)
            cycle="${p#.sage/work/}"
            cycle="${cycle%/manifest.md}"
            manifest="$cwd/$p"
            [ -f "$manifest" ] || continue
            status_now="$(manifest_yaml "$manifest" | yq eval '.status // ""' - 2>/dev/null || true)"
            epilogue="$(manifest_yaml "$manifest" | yq eval '.closeout_epilogue // ""' - 2>/dev/null || true)"
            if [ "$status_now" = "completed" ]; then
                case "$epilogue" in allowed|accepted|true|yes) ;;
                    *) completed_cycles+=("$cycle") ;;
                esac
            fi
            ;;
    esac
done

for cycle in ${completed_cycles[@]+"${completed_cycles[@]}"}; do
    for p in "${claimed_paths[@]}"; do
        if ! is_cycle_artifact_path "$p" "$cycle"; then
            emit_incident "post_completion_mutation" "$p" "critical"
        fi
    done
done

# Step 2 — Check A (diff-claim mismatch).
# Use `git status --porcelain -uall` (not `git diff --name-only HEAD`):
#   - Porcelain reports untracked files (new apply_patch additions are
#     untracked until staged) — diff misses them.
#   - Porcelain works in repos with no commits yet — `HEAD` is undefined
#     in a fresh `git init` repo, so diff returns empty for every claim.
#   - `-uall` expands untracked directories into individual files (default
#     `normal` collapses `src/foo.txt` into `src/`, breaking path match).
# Format: "XY <path>" — strip the first 3 chars (status flags + space).
cd "$cwd" || exit 0
actual_paths=()
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        path="${line:3}"
        # Exclude hook bookkeeping (PreToolUse writes .session-mutations.log
        # before apply_patch runs; this hook writes .mcp-incidents.log;
        # other libs write .skipped-checks.log). They show up in porcelain
        # but are NOT agent mutations — surfacing them as unclaimed_change
        # creates self-flagging noise on every turn.
        case "$path" in .sage/.*.log|.sage/decisions-archive.md) continue ;; esac
        actual_paths+=("$path")
    done < <(git status --porcelain -uall 2>/dev/null || true)
fi

contains() {
    local needle="$1"; shift
    local x
    for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
    return 1
}

is_capture_documentation_path() {
    case "$1" in
        .sage/work/*|.sage/docs/*|.sage/decisions.md) return 0 ;;
        *) return 1 ;;
    esac
}

is_local_ignored_artifact_path() {
    case "$1" in
        .sage-local/*) ;;
        *) return 1 ;;
    esac
    git -C "$cwd" check-ignore -q -- "$1" >/dev/null 2>&1 || return 1
}

all_claimed_capture_only=1
for p in "${claimed_paths[@]}"; do
    if ! is_capture_documentation_path "$p"; then
        all_claimed_capture_only=0
        break
    fi
done

if [ "$all_claimed_capture_only" -eq 1 ]; then
    for p in "${claimed_paths[@]}"; do
        [ -e "$cwd/$p" ] || continue
        emit_incident "capture_documentation_mutation" "$p" "info"
    done
fi

all_claimed_local_ignored=1
for p in "${claimed_paths[@]}"; do
    if ! is_local_ignored_artifact_path "$p"; then
        all_claimed_local_ignored=0
        break
    fi
done

if [ "$all_claimed_local_ignored" -eq 1 ]; then
    for p in "${claimed_paths[@]}"; do
        [ -e "$cwd/$p" ] || continue
        emit_incident "local_ignored_artifact_mutation" "$p" "info"
    done
fi

# claim_no_op: claimed but not in diff
for p in "${claimed_paths[@]}"; do
    if [ "${#actual_paths[@]}" -gt 0 ]; then
        if ! contains "$p" "${actual_paths[@]}"; then
            if [ "$all_claimed_capture_only" -eq 1 ] && is_capture_documentation_path "$p" && [ -e "$cwd/$p" ]; then
                continue
            fi
            if [ "$all_claimed_local_ignored" -eq 1 ] && is_local_ignored_artifact_path "$p" && [ -e "$cwd/$p" ]; then
                continue
            fi
            emit_incident "claim_no_op" "$p" "warn"
        fi
    else
        if [ "$all_claimed_capture_only" -eq 1 ] && is_capture_documentation_path "$p" && [ -e "$cwd/$p" ]; then
            continue
        fi
        if [ "$all_claimed_local_ignored" -eq 1 ] && is_local_ignored_artifact_path "$p" && [ -e "$cwd/$p" ]; then
            continue
        fi
        emit_incident "claim_no_op" "$p" "warn"
    fi
done

# unclaimed_change: in diff but not claimed
for p in ${actual_paths[@]+"${actual_paths[@]}"}; do
    if ! contains "$p" "${claimed_paths[@]}"; then
        emit_incident "unclaimed_change" "$p" "warn"
    fi
done

# Step 3 — Check C (frontmatter health on touched .sage/**/*.md).
if command -v yq >/dev/null 2>&1; then
    for p in ${actual_paths[@]+"${actual_paths[@]}"}; do
        case "$p" in .sage/*) ;; *) continue ;; esac
        case "$p" in *.md) ;; *) continue ;; esac
        [ "$p" = ".sage/decisions.md" ] && continue
        [ -f "$cwd/$p" ] || continue
        # Extract frontmatter between first '---' and next '---'.
        fm="$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$cwd/$p" 2>/dev/null || true)"
        [ -n "$fm" ] || continue
        if ! printf '%s' "$fm" | yq eval '.' >/dev/null 2>&1; then
            emit_incident "broken_frontmatter" "$p" "warn"
        fi
    done
else
    # Note skip per §6.4 step 3 fallback.
    skip_log="$cwd/.sage/.skipped-checks.log"
    mkdir -p "$(dirname "$skip_log")" 2>/dev/null
    printf '%s post-tool-check: yq missing, Check C skipped\n' "$ts" >> "$skip_log"
fi

exit 0
