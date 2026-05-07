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
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/path_normalize.sh"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/artifact_order.sh"

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
            [ -n "$f" ] && claimed_paths+=("$(normalize_path "$f" "$cwd")")
        done <<< "$match"
    done < "$mutations_log"
fi

# Collect actual mutated paths via `git status --porcelain -uall` (same
# rationale as post-tool-check Check A): catches untracked files (a
# `bash echo > foo` bypass writes an untracked file — `git diff HEAD`
# misses it, so bypass_mutation never fired) and works in repos with
# no commits yet.
actual_paths=()
cd "$cwd" || exit 0
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        p="${line:3}"
        # Exclude hook bookkeeping (we appended to .session-mutations.log
        # ourselves; .mcp-incidents.log is this hook's own output).
        case "$p" in .sage/.*.log) continue ;; esac
        actual_paths+=("$p")
    done < <(git status --porcelain -uall 2>/dev/null || true)
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

# Critical fix invariant — Moderate+ fixes are artifact-first. A 3+ file
# implementation change in a fix cycle is treated as Moderate+ for audit
# purposes, and `plan.md` + `manifest.md` must have appeared in the session
# mutation stream before the first implementation file. Later artifact writes
# are recorded as post-hoc and do not cure the violation.
if [ -f "$mutations_log" ]; then
    cycle_ids="$(jq -r --arg sid "$session_id" '
        select(.session_id == $sid) |
        ((.cycle_id // empty), (.files[]? | capture("^\\.sage/work/(?<cycle>[^/]+)/").cycle?)) |
        select(. != "")
    ' "$mutations_log" 2>/dev/null | sort -u || true)"

    while IFS= read -r cycle; do
        [ -n "$cycle" ] || continue
        plan_seen=0
        manifest_seen=0
        impl_count=0
        first_impl=""
        violation=0

        while IFS= read -r row; do
            entry_cycle="${row%%	*}"
            path="${row#*	}"
            [ "$entry_cycle" = "$cycle" ] || continue

            case "$path" in
                ".sage/work/$cycle/plan.md") plan_seen=1 ;;
                ".sage/work/$cycle/manifest.md") manifest_seen=1 ;;
            esac

            if is_cycle_artifact_path "$path" "$cycle"; then
                continue
            fi

            impl_count=$((impl_count + 1))
            [ -n "$first_impl" ] || first_impl="$path"
            if [ "$plan_seen" -ne 1 ] || [ "$manifest_seen" -ne 1 ]; then
                violation=1
            fi
        done < <(jq -r --arg sid "$session_id" --arg cwd "$cwd" '
            select(.session_id == $sid) as $entry |
            ($entry.cycle_id // "") as $entry_cycle |
            $entry.files[]? |
            if test("^\\.sage/work/[^/]+/") then
                (capture("^\\.sage/work/(?<cycle>[^/]+)/").cycle) + "\t" + .
            elif $entry_cycle != "" then
                $entry_cycle + "\t" + .
            else
                empty
            end
        ' "$mutations_log" 2>/dev/null || true)

        if [ "$impl_count" -ge 3 ] && [ "$violation" -eq 1 ]; then
            post_hoc=false
            if [ "$plan_seen" -eq 1 ] && [ "$manifest_seen" -eq 1 ]; then
                post_hoc=true
            fi
            extras="$(jq -nc --arg cycle "$cycle" --argjson count "$impl_count" --argjson post "$post_hoc" \
                '{cycle:$cycle, implementation_file_count:$count, post_hoc_artifacts:$post}')"
            emit_incident "artifact_order_violation" "$first_impl" "critical" "$extras"
        fi
    done <<< "$cycle_ids"
fi

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
