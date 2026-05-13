#!/usr/bin/env bash
# pre-tool-validate.sh — Codex PreToolUse(apply_patch, Bash).
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
turn_id="$(printf '%s' "$payload" | jq -r '.turn_id // "unknown"')"
tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"

if [ "$tool_name" = "Bash" ]; then
    mutating=0
    targets_guarded=0
    if [[ "$cmd" =~ (^|[[:space:];|&])(cat[[:space:]].*\>|tee([[:space:]]|$)|sed[[:space:]][^;\|\&]*-i|perl[[:space:]][^;\|\&]*-.*pi|touch|mkdir|rm|mv|cp|install)([[:space:]]|$) ]] || [[ "$cmd" =~ (^|[^\<])\>\>?([^\|]|$) ]]; then
        mutating=1
    fi
    if [[ "$cmd" == *".sage/work/"* ]] || [[ "$cmd" == *".sage/decisions.md"* ]] || [[ "$cmd" == *".sage-memory/"* ]] || [[ "$cmd" == *"src/"* ]] || [[ "$cmd" == *"tests/"* ]] || [[ "$cmd" == *"runtime/"* ]] || [[ "$cmd" == *"core/"* ]] || [[ "$cmd" == *"bin/"* ]]; then
        targets_guarded=1
    fi
    if [ "$mutating" -eq 1 ] && [ "$targets_guarded" -eq 1 ]; then
        printf 'Sage: BLOCKING mutating Bash command against managed/project paths. Bash cannot claim exact Sage scope before execution. Next legal move: use apply_patch so PreToolUse can validate exact paths, or update the approved manifest scope/plan first.\n' >&2
        exit 2
    fi
    exit 0
fi

case "$tool_name" in
    apply_patch|Edit|Write|file_change|"") ;;
    *) exit 0 ;;
esac

claimed_paths=()
claimed_ops=()
while IFS= read -r line; do
    case "$line" in
        '*** Add File: '*)
            claimed_ops+=("Add")
            claimed_paths+=("$(normalize_path "${line#*File: }" "$cwd")") ;;
        '*** Update File: '*)
            claimed_ops+=("Update")
            claimed_paths+=("$(normalize_path "${line#*File: }" "$cwd")") ;;
        '*** Delete File: '*)
            claimed_ops+=("Delete")
            claimed_paths+=("$(normalize_path "${line#*File: }" "$cwd")") ;;
    esac
done <<< "$cmd"

while IFS=$'\t' read -r kind path; do
    [ -n "$path" ] || continue
    case "$kind" in
        add|Add) op="Add" ;;
        delete|Delete) op="Delete" ;;
        update|Update|modify|Modify|*) op="Update" ;;
    esac
    claimed_ops+=("$op")
    claimed_paths+=("$(normalize_path "$path" "$cwd")")
done < <(printf '%s' "$payload" | jq -r '
    (.tool_input.changes // .changes // .item.changes // [])[]? |
    [(.kind // "update"), (.path // empty)] | @tsv
' 2>/dev/null || true)

[ "${#claimed_paths[@]}" -eq 0 ] && exit 0

is_implementation_boundary_path() {
    case "$1" in
        AGENTS.md|CLAUDE.md|.codex/*|.claude/*|runtime/*|src/*|tests/*|*/tests/*|*.bats|bin/*|scripts/*|package.json|package-lock.json|pnpm-lock.yaml|yarn.lock|pyproject.toml|uv.lock|Cargo.toml|Cargo.lock|go.mod|go.sum|Makefile|Dockerfile|docker-compose*.yml|.github/workflows/*|.gitignore)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

is_lightweight_config_only_patch() {
    [ "${#claimed_paths[@]}" -eq 1 ] || return 1
    [ "${#claimed_ops[@]}" -eq 1 ] || return 1

    local path="${claimed_paths[0]}"
    local op="${claimed_ops[0]}"
    local base lower

    case "$op" in
        Add|Update) ;;
        *) return 1 ;;
    esac

    case "$path" in
        config/*) ;;
        *) return 1 ;;
    esac
    case "$path" in
        config/*/*) return 1 ;;
    esac
    case "$path" in
        *.toml|*.json|*.yaml|*.yml) ;;
        *) return 1 ;;
    esac

    base="${path##*/}"
    lower="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        *hook*|*agent*|*instruction*|*policy*|*permission*|*secret*|*credential*|*token*|*key*|*auth*|*mcp*|*plugin*|*skill*)
            return 1 ;;
    esac

    return 0
}

same_turn_bootstrapped_cycle() {
    local cwd="$1"
    local session_id="$2"
    local cycle_id="$3"
    local turn_id="$4"
    local log="$cwd/.sage/.session-mutations.log"
    local manifest_path=".sage/work/$cycle_id/manifest.md"
    local plan_path=".sage/work/$cycle_id/plan.md"

    [ -f "$log" ] || return 1

    jq -e --arg sid "$session_id" --arg turn "$turn_id" --arg cycle "$cycle_id" --arg manifest "$manifest_path" --arg plan "$plan_path" '
        select(.session_id == $sid and .turn_id == $turn and .cycle_id == $cycle and (((.files // []) | index($manifest)) or ((.files // []) | index($plan))))
    ' "$log" >/dev/null 2>&1
}

resolution="$(resolve_cycle_for_patch "$cwd" "${claimed_paths[@]}")"
resolution_kind="${resolution%%:*}"
resolution_value="${resolution#*:}"

if [ "$resolution_kind" = "ambiguous" ]; then
    printf 'Sage: BLOCKING ambiguous cycle selection for patch paths. Matching cycles: %s. Next legal move: explicitly select/resume one cycle or split the patch.\n' "$resolution_value" >&2
    exit 2
fi

if [ "$resolution_kind" = "bootstrap" ]; then
    cycle_id="$resolution_value"
elif [ "$resolution_kind" = "none" ]; then
    if is_lightweight_config_only_patch; then
        cycle_id=""
    else
        resumable="$(resumable_cycles_summary "$cwd" || true)"
        if [ -n "$resumable" ]; then
            printf 'Sage: no active implementation cycle. Found parked paused/intake work: %s. Parked cycles are manifest-only/resumable context, not implementation-active. Next legal move: run `sage status`, then explicitly use `sage:continue` or natural-language resume for the right cycle, or start a new workflow.\n' "$resumable" >&2
            exit 2
        fi
        # shellcheck disable=SC2016
        printf 'Sage: no active cycle. Run `/sage:build` (or `/sage:fix`, `/sage:architect`) to start a workflow before mutating files.\n' >&2
        exit 2
    fi
else
    cycle_dir="$resolution_value"
    cycle_id="$(basename "$cycle_dir")"
    manifest="$cycle_dir/manifest.md"
    if [ "$resolution_kind" = "active" ]; then
        active_session_id="$(cycle_active_session_id "$cwd" "$cycle_id" 2>/dev/null || true)"
        if [ -n "$active_session_id" ] && [ "$active_session_id" != "$session_id" ]; then
            printf 'Sage: BLOCKING active cycle owned by another session. Cycle: %s. active_session_id: %s. current session_id: %s. Next legal move: return to the original session, ask the user for explicit handoff/parking, or create a separate intake for independent work.\n' \
                "$cycle_id" "$active_session_id" "$session_id" >&2
            exit 2
        fi
    fi
    if [ "$resolution_kind" = "parked-capture" ]; then
        capture_out_of_scope=()
        for path in "${claimed_paths[@]}"; do
            case "$path" in
                .sage/work/"$cycle_id"/*|.sage/decisions.md|.sage-memory/*.md) ;;
                *) capture_out_of_scope+=("$path") ;;
            esac
        done
        if [ "${#capture_out_of_scope[@]}" -gt 0 ]; then
            printf 'Sage: BLOCKING parked-cycle capture with implementation/out-of-cycle paths: %s. Parked cycles allow only same-cycle .sage artifacts, .sage/decisions.md, and narrow .sage-memory capture. Next legal move: explicitly continue the cycle before implementation.\n' "${capture_out_of_scope[*]}" >&2
            exit 2
        fi
    fi
    scope_globs=("$(normalize_path "$cycle_dir/*" "$cwd")" "$(normalize_path "$cwd/.sage/decisions.md" "$cwd")")
    if [ "$resolution_kind" = "parked-capture" ]; then
        scope_globs+=("$(normalize_path "$cwd/.sage-memory/*.md" "$cwd")")
    fi
    while IFS= read -r line; do
        [ -n "$line" ] && scope_globs+=("$(normalize_path "$line" "$cwd")")
    done < <(manifest_yaml "$manifest" | yq eval -r '.scope[]? // ""' - 2>/dev/null || true)
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
            done < <(manifest_yaml "$manifest" | yq eval -r '.scope[]? // ""' - 2>/dev/null || true)
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

    boundary_paths=()
    for path in "${claimed_paths[@]}"; do
        case "$path" in
            ".sage/work/$cycle_id/"*|".sage/decisions.md"|.sage-memory/*.md) continue ;;
        esac
        if is_implementation_boundary_path "$path"; then
            boundary_paths+=("$path")
        fi
    done
    if [ "${#boundary_paths[@]}" -gt 0 ] && same_turn_bootstrapped_cycle "$cwd" "$session_id" "$cycle_id" "$turn_id"; then
        printf 'Sage: BLOCKING implementation/instruction mutation from a self-created cycle in the same turn: %s. Active cycle: %s. A manifest/plan created by this same turn is capture/planning state, not approval to edit source/runtime/test/instruction files. Config changes are calibrated separately by the lightweight structural allowlist. Next legal move: present the plan and wait for user approval, then continue in a later turn.\n' \
            "${boundary_paths[*]}" "$cycle_id" >&2
        exit 2
    fi

    risky_paths=()
    reclass_ack="$(manifest_yaml "$manifest" | yq eval -r '.semantic_reclassification // .scope_change_checkpoint // .risk_checkpoint // ""' - 2>/dev/null || true)"
    for i in "${!claimed_paths[@]}"; do
        path="${claimed_paths[$i]}"
        op="${claimed_ops[$i]}"
        case "$path" in
            ".sage/work/$cycle_id/"*|".sage/decisions.md") continue ;;
        esac
        risky=0
        [ "$op" = "Delete" ] && risky=1
        case "$path" in
            .gitignore|.github/workflows/*|README.md|bin/*|*.bats|tests/*|*/tests/*)
                risky=1 ;;
        esac
        [ "$risky" -eq 1 ] && risky_paths+=("$path")
    done
    if [ "${#risky_paths[@]}" -gt 0 ]; then
        case "$reclass_ack" in
            accepted|approved|true|yes) ;;
            *)
                printf 'Sage: BLOCKING risky scope mutation without semantic reclassification checkpoint: %s. Active cycle: %s. Repo-control files, public docs, CLI entrypoints, deletions, and tests require manifest frontmatter `semantic_reclassification: accepted` after an approved plan/scope review.\n' \
                    "${risky_paths[*]}" "$cycle_id" >&2
                exit 2 ;;
        esac
    fi

    if moderate_fix_artifacts_missing "$cycle_dir" "$manifest" "$cwd/.sage/.session-mutations.log" "$session_id" "$cycle_id" "${claimed_paths[@]}"; then
        printf 'Sage: BLOCKING Moderate+ fix implementation before approved artifacts. Detected 3+ implementation files before plan.md and manifest.md existed first. Next legal move: write/update those artifacts before code changes; post-hoc artifacts do not cure a code-first violation. Active cycle: %s.\n' "$cycle_id" >&2
        exit 2
    fi
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
files_json="$(printf '%s\n' "${claimed_paths[@]}" | jq -R . | jq -sc .)"
log_line="$(jq -nc --arg sid "$session_id" --arg turn "$turn_id" --arg ts "$ts" --arg cycle "$cycle_id" --argjson files "$files_json" \
    '{session_id:$sid, turn_id:$turn, ts:$ts, cycle_id:$cycle, files:$files}')"
json_log_append "$cwd/.sage/.session-mutations.log" "$log_line"

exit 0
