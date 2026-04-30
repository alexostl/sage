#!/usr/bin/env bash
# turn-audit.sh — Codex Stop event hook (partial ADR-7 audit surface).
#
# Spec §6.5: bash-native v1 lite (~70% of ADR-7).
#   1. Skipped: orphan_approval (§6.2 deferred — no .approval-pending).
#   2. Skipped: approval_coupling (§6.2 deferred).
#   3. Session-mutations vs git diff → bypass_mutation incidents.
#   4. Phase-jump probe → phase_jump_observed incidents (informational).
#   5. Skipped: ADR-7 C5 (L5 deferred), C7 deep audit (sage doctor S4).
#   6. Skipped: dead-MCP detection (§8 deferred).
#   7. Exit 0 always (ADR-7 D5 invariant).
#
# v1 spec ref: §6.5, §15.3, §15.4.
# v1 plan ref: T1.7 (Group B).

set -euo pipefail
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/json_log.sh"

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

payload="$(cat 2>/dev/null || true)"
session_id=""
turn_id=""
cwd=""
if printf '%s' "$payload" | jq -e . >/dev/null 2>&1; then
    session_id="$(printf '%s' "$payload" | jq -r '.session_id // empty')"
    turn_id="$(printf '%s' "$payload" | jq -r '.turn_id // empty')"
    cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
fi
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$PWD"
[ -n "$session_id" ] || session_id="unknown"

incidents_log="$cwd/.sage/.mcp-incidents.log"
mutations_log="$cwd/.sage/.session-mutations.log"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

emit_incident() {
    local kind="$1"
    local file="$2"
    local sev="${3:-warn}"
    local extras="${4:-}"
    [ -n "$extras" ] || extras='{}'
    local line
    line="$(jq -nc --arg kind "$kind" --arg file "$file" --arg sev "$sev" \
        --arg sid "$session_id" --arg tid "$turn_id" --arg ts "$ts" \
        --argjson extras "$extras" \
        '{kind:$kind, file:$file, severity:$sev, session_id:$sid, turn_id:$tid, ts:$ts} * $extras')"
    json_log_append "$incidents_log" "$line"
}

# Collect this session's claimed paths from session-mutations log.
claimed_paths=()
if [ -f "$mutations_log" ]; then
    while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        # Filter by session_id (turn_id optional — any turn from this session).
        match="$(printf '%s' "$entry" | jq -r --arg sid "$session_id" \
            'select(.session_id == $sid) | .files[]?' 2>/dev/null || true)"
        while IFS= read -r f; do
            [ -n "$f" ] && claimed_paths+=("$f")
        done <<< "$match"
    done < "$mutations_log"
fi

# Collect git-diff'd paths.
actual_paths=()
cd "$cwd" || exit 0
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r p; do
        [ -n "$p" ] && actual_paths+=("$p")
    done < <(git diff --name-only HEAD 2>/dev/null || true)
fi

contains() {
    local needle="$1"; shift
    local x
    for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
    return 1
}

# Step 3 — bypass_mutation: in git-diff but not in session-mutations log.
for p in ${actual_paths[@]+"${actual_paths[@]}"}; do
    if [ "${#claimed_paths[@]}" -gt 0 ]; then
        if ! contains "$p" "${claimed_paths[@]}"; then
            emit_incident "bypass_mutation" "$p" "warn"
        fi
    else
        emit_incident "bypass_mutation" "$p" "warn"
    fi
done

# Step 4 — phase-jump probe: did this session mutate a manifest/spec/
# plan and is the on-disk file at status: completed? Informational —
# feeds outcome harness for §6.2 v2 promotion trigger #1.
if command -v yq >/dev/null 2>&1; then
    for p in ${claimed_paths[@]+"${claimed_paths[@]}"}; do
        case "$p" in
            .sage/work/*/manifest.md|.sage/work/*/spec.md|.sage/work/*/plan.md) ;;
            *) continue ;;
        esac
        [ -f "$cwd/$p" ] || continue
        fm="$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$cwd/$p" 2>/dev/null || true)"
        [ -n "$fm" ] || continue
        new_status="$(printf '%s' "$fm" | yq eval '.status // ""' - 2>/dev/null || true)"
        if [ "$new_status" = "completed" ]; then
            cycle="$(basename "$(dirname "$p")")"
            extras="$(jq -nc --arg cycle "$cycle" --arg ns "$new_status" \
                '{cycle:$cycle, new_status:$ns}')"
            emit_incident "phase_jump_observed" "$p" "info" "$extras"
        fi
    done
fi

exit 0
