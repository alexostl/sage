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

manifest_scope_lines() {
    local yaml
    yaml="$(manifest_yaml "$1")" || return 0
    if printf '%s\n' "$yaml" | yq eval -e '.scope | tag == "!!map"' - >/dev/null 2>&1; then
        printf '%s\n' "$yaml" | yq eval -r '.scope.writable[]? // ""' - 2>/dev/null || true
    else
        printf '%s\n' "$yaml" | yq eval -r '.scope[]? // ""' - 2>/dev/null || true
    fi
}

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

bash_strip_token_path() {
    local token="$1"

    case "$token" in
        [0-9]">>"*) token="${token#*>>}" ;;
        [0-9]">"*) token="${token#*>}" ;;
        ">>"*) token="${token#>>}" ;;
        ">"*) token="${token#>}" ;;
    esac

    token="${token#\"}"; token="${token%\"}"
    token="${token#\'}"; token="${token%\'}"
    token="${token%;}"
    case "$token" in ./*) token="${token#./}" ;; esac
    printf '%s' "$token"
}

bash_redirection_target_mutates() {
    local target
    target="$(bash_strip_token_path "$1")"

    case "$target" in
        ""|/dev/null|/dev/fd/*|/proc/self/fd/*|\&1|\&2)
            return 1 ;;
        *)
            return 0 ;;
    esac
}

bash_has_mutating_output_redirection() {
    local command="$1"
    local expect_target=0
    local token

    # Simple token scan only: enough to distinguish real file writes from
    # descriptor/no-op redirects without becoming a shell parser.
    set -f
    # shellcheck disable=SC2086
    for token in $command; do
        if [ "$expect_target" -eq 1 ]; then
            if bash_redirection_target_mutates "$token"; then
                set +f
                return 0
            fi
            expect_target=0
            continue
        fi

        case "$token" in
            ">"|">>"|[0-9]">"|[0-9]">>")
                expect_target=1 ;;
            [0-9]">>"*|[0-9]">"*|">>"*|">"*)
                if bash_redirection_target_mutates "$token"; then
                    set +f
                    return 0
                fi ;;
        esac
    done
    set +f

    return 1
}

bash_is_allowed_local_artifact_path() {
    case "$1" in
        .sage/.*.log|.sage/.approval-pending|.sage/.codex-validated-version|.codex/hooks.json.user-edit-backup-*)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

bash_token_targets_guarded_repo_path() {
    local path
    path="$(bash_strip_token_path "$1")"

    case "$path" in
        ""|-|--*|\&*|/dev/*)
            return 1 ;;
    esac

    path="$(normalize_path "$path" "$cwd")"
    case "$path" in
        /*) return 1 ;;
    esac

    bash_is_allowed_local_artifact_path "$path" && return 1

    case "$path" in
        .sage/work/*|.sage/decisions.md|.sage-memory/*|AGENTS.md|CLAUDE.md|.codex/*|.claude/*|runtime/*|core/*|bin/*|src/*|tests/*|*/tests/*|*.bats|.gitignore)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

bash_command_targets_guarded_repo_path() {
    local command="$1"
    local token

    set -f
    # shellcheck disable=SC2086
    for token in $command; do
        if bash_token_targets_guarded_repo_path "$token"; then
            set +f
            return 0
        fi
    done
    set +f
    return 1
}

if [ "$tool_name" = "Bash" ]; then
    mutating=0
    targets_guarded=0
    if [[ "$cmd" =~ (^|[[:space:];|&])(tee([[:space:]]|$)|sed[[:space:]][^;\|\&]*-i|perl[[:space:]][^;\|\&]*-.*pi|touch|mkdir|rm|mv|cp|install)([[:space:]]|$) ]] || bash_has_mutating_output_redirection "$cmd"; then
        mutating=1
    fi
    binary_like=0
    if [[ "$cmd" =~ \.(png|jpg|jpeg|gif|webp|pdf|zip|gz|tar|ico|icns|woff|woff2|ttf|otf)([[:space:]]|$) ]]; then
        binary_like=1
    fi
    if bash_command_targets_guarded_repo_path "$cmd"; then
        targets_guarded=1
    fi
    if [ "$mutating" -eq 1 ] && [[ "$cmd" == SAGE_BINARY_MUTATION=1* ]]; then
        if [[ "$cmd" =~ [\;\|\&\<\>\*\?\[\]\{\}\`] ]] || [[ "$cmd" == *'$('* ]]; then
            printf 'Sage: BLOCKING binary asset mutation with non-simple Bash syntax. Binary asset mutations must use a simple allowlisted command with exact paths only. Next legal move: use a generator/helper with approved scope, or split to a simple `SAGE_BINARY_MUTATION=1 rm <path>` command.\n' >&2
            exit 2
        fi
        binary_path=""
        if [[ "$cmd" =~ ^SAGE_BINARY_MUTATION=1[[:space:]]+rm[[:space:]]+([^[:space:]]+)$ ]]; then
            binary_path="${BASH_REMATCH[1]}"
        else
            printf 'Sage: BLOCKING binary asset mutation with unsupported Bash shape. Allowed v1 shape is simple and exact, for example: `SAGE_BINARY_MUTATION=1 rm path/to/asset.png`.\n' >&2
            exit 2
        fi
        claimed_path="$(normalize_path "$binary_path" "$cwd")"
        resolution="$(resolve_cycle_for_patch "$cwd" "$claimed_path")"
        resolution_kind="${resolution%%:*}"
        resolution_value="${resolution#*:}"
        if [ "$resolution_kind" != "active" ]; then
            printf 'Sage: BLOCKING binary asset mutation without an active implementation cycle. File: %s. Next legal move: start/resume the workflow and approve manifest scope first.\n' "$claimed_path" >&2
            exit 2
        fi
        cycle_dir="$resolution_value"
        cycle_id="$(basename "$cycle_dir")"
        manifest="$cycle_dir/manifest.md"
        active_session_id="$(cycle_active_session_id "$cwd" "$cycle_id" 2>/dev/null || true)"
        if [ -n "$active_session_id" ] && [ "$active_session_id" != "$session_id" ]; then
            printf 'Sage: BLOCKING active cycle owned by another session. Cycle: %s. active_session_id: %s. current session_id: %s. Next legal move: return to the original session, ask for handoff/parking, or create a separate intake.\n' \
                "$cycle_id" "$active_session_id" "$session_id" >&2
            exit 2
        fi
        scope_globs=("$(normalize_path "$cycle_dir/*" "$cwd")" "$(normalize_path "$cwd/.sage/decisions.md" "$cwd")")
        while IFS= read -r line; do
            [ -n "$line" ] && scope_globs+=("$(normalize_path "$line" "$cwd")")
        done < <(manifest_scope_lines "$manifest")
        matched=0
        for glob in ${scope_globs[@]+"${scope_globs[@]}"}; do
            case "$claimed_path" in $glob) matched=1; break ;; esac
        done
        if [ "$matched" -ne 1 ]; then
            printf 'Sage: BLOCKING binary asset mutation outside cycle scope: %s. Active cycle: %s. Next legal move: update the approved manifest scope/plan first.\n' "$claimed_path" "$cycle_id" >&2
            exit 2
        fi
        ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        files_json="$(printf '%s\n' "$claimed_path" | jq -R . | jq -sc .)"
        log_line="$(jq -nc --arg sid "$session_id" --arg turn "$turn_id" --arg ts "$ts" --arg cycle "$cycle_id" --argjson files "$files_json" \
            '{session_id:$sid, turn_id:$turn, ts:$ts, cycle_id:$cycle, files:$files, mutation_kind:"binary_asset"}')"
        json_log_append "$cwd/.sage/.session-mutations.log" "$log_line"
        exit 0
    fi
    if [ "$mutating" -eq 1 ] && [ "$targets_guarded" -eq 1 ]; then
        if [ "$binary_like" -eq 1 ]; then
            printf 'Sage: BLOCKING binary asset mutation without explicit binary intent. Binary assets cannot use apply_patch, but shell mutation still needs approved scope. Next legal move: use a simple `SAGE_BINARY_MUTATION=1 rm <path>` command after confirming the file is in manifest scope.\n' >&2
            exit 2
        fi
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

is_decisions_only_repo_hygiene_patch() {
    [ "${#claimed_paths[@]}" -eq 2 ] || return 1
    [ "${#claimed_ops[@]}" -eq 2 ] || return 1

    local has_repo_hygiene=0 has_decision=0 i path op
    for i in "${!claimed_paths[@]}"; do
        path="${claimed_paths[$i]}"
        op="${claimed_ops[$i]}"
        case "$op" in Add|Update) ;; *) return 1 ;; esac
        case "$path" in
            .gitignore) has_repo_hygiene=1 ;;
            .sage/decisions.md) has_decision=1 ;;
            *) return 1 ;;
        esac
    done

    [ "$has_repo_hygiene" -eq 1 ] && [ "$has_decision" -eq 1 ]
}

is_standalone_repo_hygiene_patch() {
    [ "${#claimed_paths[@]}" -eq 1 ] || return 1
    [ "${#claimed_ops[@]}" -eq 1 ] || return 1
    case "${claimed_ops[0]}" in Add|Update) ;; *) return 1 ;; esac
    [ "${claimed_paths[0]}" = ".gitignore" ]
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

has_valid_implementation_approval() {
    local cwd="$1"
    local session_id="$2"
    local cycle_id="$3"
    local turn_id="$4"
    local manifest_file="$cwd/.sage/work/$cycle_id/manifest.md"
    local plan_path=".sage/work/$cycle_id/plan.md"
    local plan_file="$cwd/$plan_path"
    local log="$cwd/.sage/.session-mutations.log"
    local yaml mode artifact revision

    [ -f "$manifest_file" ] || return 1
    [ -f "$plan_file" ] || return 1
    [ -f "$log" ] || return 1

    yaml="$(manifest_yaml "$manifest_file")" || return 1
    mode="$(printf '%s\n' "$yaml" | yq eval -r '.implementation_approval.mode // ""' - 2>/dev/null || true)"
    artifact="$(printf '%s\n' "$yaml" | yq eval -r '.implementation_approval.artifact // ""' - 2>/dev/null || true)"
    revision="$(printf '%s\n' "$yaml" | yq eval -r '.implementation_approval.revision // ""' - 2>/dev/null || true)"

    case "$mode" in
        approved) ;;
        conditional_revision)
            [ -n "$revision" ] || return 1 ;;
        *)
            return 1 ;;
    esac

    [ "$artifact" = "$plan_path" ] || return 1

    jq -e --arg sid "$session_id" --arg turn "$turn_id" --arg cycle "$cycle_id" --arg plan "$plan_path" '
        select(.session_id == $sid and .turn_id != $turn and .cycle_id == $cycle and ((.files // []) | index($plan)))
    ' "$log" >/dev/null 2>&1
}

resolution="$(resolve_cycle_for_patch "$cwd" "${claimed_paths[@]}")"
resolution_kind="${resolution%%:*}"
resolution_value="${resolution#*:}"
mutation_kind=""

if [ "$resolution_kind" = "ambiguous" ]; then
    printf 'Sage: BLOCKING ambiguous cycle selection for patch paths. Matching cycles: %s. Next legal move: explicitly select/resume one cycle or split the patch.\n' "$resolution_value" >&2
    exit 2
fi

if [ "$resolution_kind" = "bootstrap" ]; then
    cycle_id="$resolution_value"
elif [ "$resolution_kind" = "completed" ]; then
    cycle_id="$(basename "$resolution_value")"
    printf 'Sage: BLOCKING completed cycle mutation. Cycle: %s. This cycle may have been closed before closeout artifacts were finished. Next legal move: ask the user for an explicit reopen/scope decision, or continue stage/commit handoff without mutating closed .sage artifacts. Do not add a post-closeout .sage epilogue.\n' "$cycle_id" >&2
    exit 2
elif [ "$resolution_kind" = "none" ]; then
    if is_decisions_only_repo_hygiene_patch; then
        cycle_id=""
        mutation_kind="decisions_only_repo_hygiene"
    elif is_standalone_repo_hygiene_patch; then
        printf 'Sage: BLOCKING standalone repo hygiene mutation. Decisions-only repo hygiene requires the single repo-hygiene file plus .sage/decisions.md in the same patch. Next legal move: add a concise .sage/decisions.md entry or start a workflow if this is not obvious low-risk hygiene.\n' >&2
        exit 2
    elif is_lightweight_config_only_patch; then
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
    done < <(manifest_scope_lines "$manifest")
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
            done < <(manifest_scope_lines "$manifest")
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
        if ! has_valid_implementation_approval "$cwd" "$session_id" "$cycle_id" "$turn_id"; then
            printf 'Sage: BLOCKING implementation/instruction mutation without a recognized implementation approval contract: %s. Active cycle: %s. Same-turn manifest/plan writes need manifest frontmatter `implementation_approval` pointing at an existing canonical plan.md with prior-turn plan evidence, and targets must stay in manifest scope. Next legal move: present or revise the plan for user approval, then record the implementation approval marker before editing source/runtime/test/instruction files.\n' \
                "${boundary_paths[*]}" "$cycle_id" >&2
            exit 2
        fi
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
        printf 'Sage: BLOCKING Moderate+ fix implementation before approved artifacts. Detected 3+ implementation files before plan.md and manifest.md existed first. Next legal move: write/update those artifacts before code changes; post-hoc artifacts do not cure a code-first violation. Do not use scope amputation: if the third file is required, escalate to the Moderate+ scope gate instead of dropping it. Active cycle: %s.\n' "$cycle_id" >&2
        exit 2
    fi
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
files_json="$(printf '%s\n' "${claimed_paths[@]}" | jq -R . | jq -sc .)"
log_line="$(jq -nc --arg sid "$session_id" --arg turn "$turn_id" --arg ts "$ts" --arg cycle "$cycle_id" --arg mutation_kind "$mutation_kind" --argjson files "$files_json" \
    '{session_id:$sid, turn_id:$turn, ts:$ts, cycle_id:$cycle, files:$files} + (if $mutation_kind == "" then {} else {mutation_kind:$mutation_kind} end)')"
json_log_append "$cwd/.sage/.session-mutations.log" "$log_line"

exit 0
