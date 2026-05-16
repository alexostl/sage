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
            '{kind:"session_mutation", session_id:$sid, turn_id:$turn, ts:$ts, cycle_id:$cycle, files:$files, mutation_kind:"binary_asset"}')"
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

patch_changed_line_count() {
    printf '%s\n' "$cmd" |
        awk '/^[+-]/ && $0 !~ /^\+\+\+/ && $0 !~ /^---/ { count++ } END { print count + 0 }'
}

patch_added_content() {
    printf '%s\n' "$cmd" |
        awk '/^\+/ && $0 !~ /^\+\+\+/ { sub(/^\+/, ""); print }'
}

is_secret_like_path() {
    local lower
    lower="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        .env|.env.*|*.env|*.env.*|*secret*|*credential*|*token*|*auth*|*private*key*|*.pem|*.key|*.p12|*.pfx)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

line_is_placeholder_secret_value() {
    local line="$1"
    local lower
    lower="$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')"

    case "$lower" in
        ""|\#*|*placeholder*|*example*|*replace_me*|*replace-me*|*your_*|*changeme*|*change_me*|*todo*|*dummy*|*not-a-secret*|*do-not-use*)
            return 0 ;;
        *=)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

line_contains_real_secret_value() {
    local line="$1"

    printf '%s' "$line" | grep -E 'sk-[A-Za-z0-9_-]{12,}|AKIA[0-9A-Z]{12,}|BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY' >/dev/null 2>&1 && return 0

    if printf '%s' "$line" | grep -Eiq '(^|[^A-Za-z0-9_])(api[_-]?key|secret|token|credential|password|private[_-]?key|auth)[A-Za-z0-9_-]*[[:space:]]*[:=][[:space:]]*[^[:space:]#]+'; then
        line_is_placeholder_secret_value "$line" && return 1
        return 0
    fi

    return 1
}

patch_contains_real_secret_value() {
    local line
    while IFS= read -r line; do
        line_contains_real_secret_value "$line" && return 0
    done < <(patch_added_content)
    return 1
}

is_placeholder_secret_patch() {
    [ "${#claimed_paths[@]}" -gt 0 ] || return 1

    local i path op saw_secret_path=0 line saw_content=0
    for i in "${!claimed_paths[@]}"; do
        path="${claimed_paths[$i]}"
        op="${claimed_ops[$i]}"
        case "$op" in Add|Update) ;; *) return 1 ;; esac
        if is_secret_like_path "$path"; then
            saw_secret_path=1
        fi
    done
    [ "$saw_secret_path" -eq 1 ] || return 1

    patch_contains_real_secret_value && return 1

    while IFS= read -r line; do
        saw_content=1
        line_is_placeholder_secret_value "$line" || return 1
    done < <(patch_added_content)
    [ "$saw_content" -eq 1 ]
}

is_surgical_patch() {
    local path resolution resolution_kind

    [ "$tool_name" = "apply_patch" ] || return 1
    [ "${#claimed_paths[@]}" -eq 1 ] || return 1
    [ "${#claimed_ops[@]}" -eq 1 ] || return 1
    [ "${claimed_ops[0]}" = "Update" ] || return 1
    path="${claimed_paths[0]}"
    case "$path" in
        /*)
            return 1 ;;
    esac
    case "$path" in
        .sage/*|.sage-memory/*|.codex/*|.git/*|config/*|.gitignore)
            return 1 ;;
    esac
    is_secret_like_path "$path" && return 1
    resolution="$(resolve_cycle_for_patch "$cwd" "$path")"
    resolution_kind="${resolution%%:*}"
    [ "$resolution_kind" = "active" ] && return 1
    [ "$(patch_changed_line_count)" -le 2 ] || return 1
    patch_contains_real_secret_value && return 1

    return 0
}

is_cross_repo_new_intake_patch() {
    [ "${#claimed_paths[@]}" -eq 1 ] || return 1
    [ "${#claimed_ops[@]}" -eq 1 ] || return 1
    [ "${claimed_ops[0]}" = "Add" ] || return 1

    local path="${claimed_paths[0]}"
    local repo_root cycle_id cycle_dir

    case "$path" in
        /*/.sage/work/*/manifest.md) ;;
        *) return 1 ;;
    esac

    case "$path" in
        "$cwd"/*|"/private$cwd"/*)
            return 1 ;;
    esac
    case "$cwd" in
        /private/*)
            case "$path" in
                "${cwd#/private}"/*) return 1 ;;
            esac ;;
    esac

    repo_root="${path%%/.sage/work/*}"
    cycle_id="${path#"$repo_root/.sage/work/"}"
    cycle_id="${cycle_id%/manifest.md}"
    cycle_dir="$repo_root/.sage/work/$cycle_id"

    case "$cycle_id" in
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[a-z0-9]*) ;;
        *) return 1 ;;
    esac

    [ -d "$repo_root" ] || return 1
    [ -e "$path" ] && return 1
    if [ -d "$cycle_dir" ] && [ -n "$(find "$cycle_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
        return 1
    fi

    return 0
}

is_local_ignored_artifact_patch() {
    [ "${#claimed_paths[@]}" -gt 0 ] || return 1

    local i path op lower
    for i in "${!claimed_paths[@]}"; do
        path="${claimed_paths[$i]}"
        op="${claimed_ops[$i]}"
        case "$op" in Add|Update) ;; *) return 1 ;; esac

        case "$path" in
            .sage-local/*) ;;
            *) return 1 ;;
        esac

        case "$path" in
            .sage-local/../*|.sage-local/*/../*|.sage-local/.git/*|.sage-local/**/.git/*)
                return 1 ;;
        esac

        case "$path" in
            .codex/*|.sage/work/*|.sage/decisions.md|.sage-memory/*|AGENTS.md|CLAUDE.md|runtime/*|src/*|tests/*|*/tests/*|*.bats|bin/*|scripts/*|.github/workflows/*)
                return 1 ;;
        esac
        is_implementation_boundary_path "$path" && return 1

        lower="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"
        case "$lower" in
            *secret*|*credential*|*token*|*auth*|*private*key*|*.pem|*.key|*.p12|*.pfx)
                return 1 ;;
        esac

        git -C "$cwd" check-ignore -q -- "$path" >/dev/null 2>&1 || return 1
    done

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

is_closed_manifest_reconciliation_patch() {
    local cycle_id="$1"
    local manifest_path=".sage/work/$cycle_id/manifest.md"

    [ "${#claimed_paths[@]}" -eq 1 ] || return 1
    [ "${#claimed_ops[@]}" -eq 1 ] || return 1
    [ "${claimed_ops[0]}" = "Update" ] || return 1
    [ "${claimed_paths[0]}" = "$manifest_path" ] || return 1

    # Only apply_patch carries enough patch detail for a safe pre-write status
    # invariant check. File-change shaped payloads stay blocked for closed
    # cycles because PreToolUse cannot inspect the future manifest contents.
    if ! printf '%s\n' "$cmd" | grep -Fq "*** Update File: $manifest_path"; then
        printf '%s\n' "$cmd" | grep -Fq "*** Update File: $cwd/$manifest_path" || return 1
    fi

    # Never allow reopening a closed cycle through this narrow bookkeeping
    # path. Non-status manifest edits are allowed; any added status must remain
    # closed (or legacy completed during migration).
    if printf '%s\n' "$cmd" | grep -E '^\+status:[[:space:]]*' >/dev/null; then
        printf '%s\n' "$cmd" | grep -E '^\+status:[[:space:]]*(closed|completed)[[:space:]]*$' >/dev/null || return 1
    fi
    if printf '%s\n' "$cmd" | grep -E '^-status:[[:space:]]*(closed|completed)[[:space:]]*$' >/dev/null; then
        printf '%s\n' "$cmd" | grep -E '^\+status:[[:space:]]*(closed|completed)[[:space:]]*$' >/dev/null || return 1
    fi

    return 0
}

patch_touches_manifest_path() {
    local path
    for path in "${claimed_paths[@]}"; do
        case "$path" in
            .sage/work/*/manifest.md)
                return 0 ;;
        esac
    done
    return 1
}

patch_adds_active_session_id() {
    [ "$tool_name" = "apply_patch" ] || return 1
    patch_touches_manifest_path || return 1
    printf '%s\n' "$cmd" | grep -E '^\+[[:space:]]*active_session_id:[[:space:]]*' >/dev/null
}

patch_sets_only_current_active_session_id() {
    local current_session_id="$1"
    local line value saw_added=0

    [ "$tool_name" = "apply_patch" ] || return 1
    patch_touches_manifest_path || return 1

    while IFS= read -r line; do
        case "$line" in
            +[[:space:]]active_session_id:*|+active_session_id:*)
                saw_added=1
                value="$(printf '%s' "$line" | sed -E 's/^\+[[:space:]]*active_session_id:[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//')"
                [ "$value" = "$current_session_id" ] || return 1 ;;
        esac
    done <<< "$cmd"

    [ "$saw_added" -eq 1 ]
}

patch_touches_manifest_control_field() {
    [ "$tool_name" = "apply_patch" ] || return 1
    patch_touches_manifest_path || return 1
    printf '%s\n' "$cmd" |
        grep -E '^[+-][[:space:]]*(status|phase|resolution|active_session_id|implementation_approval|semantic_reclassification|autonomy_grant|scope|folded_into|folded_cycles):[[:space:]]*' >/dev/null
}

is_sage_capture_without_control_patch() {
    [ "$tool_name" = "apply_patch" ] || return 1
    [ "${#claimed_paths[@]}" -gt 0 ] || return 1

    local path op
    for i in "${!claimed_paths[@]}"; do
        path="${claimed_paths[$i]}"
        op="${claimed_ops[$i]}"
        case "$op" in Add|Update) ;; *) return 1 ;; esac
        case "$path" in
            .sage/work/*/*|.sage/decisions.md|.sage-memory/*.md) ;;
            *) return 1 ;;
        esac
    done

    patch_touches_manifest_control_field && return 1
    return 0
}

is_unbound_active_cycle_claim_patch() {
    local cycle_id="$1"
    local current_session_id="$2"
    local manifest_path=".sage/work/$cycle_id/manifest.md"
    local escaped_session_id

    [ "$tool_name" = "apply_patch" ] || return 1
    [ "${#claimed_paths[@]}" -eq 1 ] || return 1
    [ "${#claimed_ops[@]}" -eq 1 ] || return 1
    [ "${claimed_ops[0]}" = "Update" ] || return 1
    [ "${claimed_paths[0]}" = "$manifest_path" ] || return 1
    if ! printf '%s\n' "$cmd" | grep -Fq "*** Update File: $manifest_path"; then
        printf '%s\n' "$cmd" | grep -Fq "*** Update File: $cwd/$manifest_path" || return 1
    fi

    if printf '%s\n' "$cmd" | grep -E '^\+status:[[:space:]]*(closed|completed)[[:space:]]*$' >/dev/null; then
        return 1
    fi

    escaped_session_id="$(printf '%s' "$current_session_id" | sed 's/[][\\.^$*+?{}|()]/\\&/g')"
    if printf '%s\n' "$cmd" | grep -E "^\+active_session_id:[[:space:]]*\"?$escaped_session_id\"?[[:space:]]*$" >/dev/null; then
        return 0
    fi
    if printf '%s\n' "$cmd" | grep -E '^\+status:[[:space:]]*paused[[:space:]]*$' >/dev/null; then
        return 0
    fi

    return 1
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

mutation_kind=""
if patch_contains_real_secret_value; then
    printf 'Sage: BLOCKING real secret value write. Agents may create placeholder env/config files, but real secrets must be edited by the user. Next legal move: write placeholders only, or ask the user to fill the secret locally.\n' >&2
    exit 2
elif patch_adds_active_session_id && ! patch_sets_only_current_active_session_id "$session_id"; then
    printf 'Sage: BLOCKING invalid active_session_id update. active_session_id must equal the current hook payload session_id. current session_id: %s. Do not use codex://threads/*, CODEX_THREAD_ID, transcripts, logs, or analyzed thread ids as the ownership lock.\n' "$session_id" >&2
    exit 2
elif is_surgical_patch; then
    resolution_kind="surgical"
    resolution_value=""
    mutation_kind="surgical_edit"
elif is_placeholder_secret_patch; then
    resolution_kind="placeholder-secret"
    resolution_value=""
    mutation_kind="placeholder_secret"
elif is_cross_repo_new_intake_patch; then
    resolution_kind="cross-repo-new-intake"
    resolution_value=""
    mutation_kind="cross_repo_new_intake"
elif is_local_ignored_artifact_patch; then
    resolution_kind="local-ignored-artifact"
    resolution_value=""
    mutation_kind="local_ignored_artifact"
else
    resolution="$(resolve_cycle_for_patch "$cwd" "${claimed_paths[@]}")"
    resolution_kind="${resolution%%:*}"
    resolution_value="${resolution#*:}"
fi

if [ "$resolution_kind" = "ambiguous" ]; then
    printf 'Sage: BLOCKING ambiguous cycle selection for patch paths. Matching cycles: %s. Next legal move: explicitly select/resume one cycle or split the patch.\n' "$resolution_value" >&2
    exit 2
fi

if [ "$resolution_kind" = "surgical" ]; then
    cycle_id=""
elif [ "$resolution_kind" = "placeholder-secret" ]; then
    cycle_id=""
elif [ "$resolution_kind" = "cross-repo-new-intake" ]; then
    cycle_id=""
elif [ "$resolution_kind" = "local-ignored-artifact" ]; then
    cycle_id=""
elif [ "$resolution_kind" = "bootstrap" ]; then
    cycle_id="$resolution_value"
elif [ "$resolution_kind" = "closed" ]; then
    cycle_id="$(basename "$resolution_value")"
    if is_closed_manifest_reconciliation_patch "$cycle_id"; then
        mutation_kind="closed_manifest_reconciliation"
    else
        printf 'Sage: BLOCKING closed cycle mutation. Cycle: %s. Closed cycles are immutable. Next legal move: if this is stale closed-cycle bookkeeping, use a manifest-only reconciliation that keeps status closed; otherwise create a wrapper/follow-up cycle. Do not add a post-closeout .sage epilogue.\n' "$cycle_id" >&2
        exit 2
    fi
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
            if is_sage_capture_without_control_patch; then
                mutation_kind="sage_capture_without_lock"
            else
                printf 'Sage: BLOCKING active cycle owned by another session. Cycle: %s. active_session_id: %s. current session_id: %s. Next legal move: return to the original session, ask the user for explicit handoff/parking, or create a separate intake for independent work.\n' \
                    "$cycle_id" "$active_session_id" "$session_id" >&2
                exit 2
            fi
        fi
        if [ -z "$active_session_id" ]; then
            if is_unbound_active_cycle_claim_patch "$cycle_id" "$session_id"; then
                mutation_kind="active_cycle_claim_or_handoff"
            elif is_sage_capture_without_control_patch; then
                mutation_kind="sage_capture_without_lock"
            else
                printf 'Sage: BLOCKING unbound active cycle mutation. Cycle: %s has status in-progress but no real active_session_id. Lightweight .sage capture/diagnosis/planning is allowed, but ownership/lifecycle/control changes and implementation paths require claim/handoff first. Next legal move: make a single-file manifest-only claim/handoff patch that sets active_session_id to the current session, park the cycle as paused, or limit this patch to capture-only .sage artifacts.\n' \
                    "$cycle_id" >&2
                exit 2
            fi
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
    '{kind:"session_mutation", session_id:$sid, turn_id:$turn, ts:$ts, cycle_id:$cycle, files:$files} + (if $mutation_kind == "" then {} else {mutation_kind:$mutation_kind} end)')"
json_log_append "$cwd/.sage/.session-mutations.log" "$log_line"

exit 0
