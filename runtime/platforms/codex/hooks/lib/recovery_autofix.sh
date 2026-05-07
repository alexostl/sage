#!/usr/bin/env bash
# recovery_autofix.sh — safe, reversible metadata repairs for Codex hooks.

manifest_frontmatter_value() {
    local manifest="$1"
    local key="$2"
    manifest_yaml "$manifest" | yq eval ".$key // \"\"" - 2>/dev/null || true
}

scope_pattern_for_safe_doc() {
    local path="$1"
    case "$path" in
        .sage/docs/decision-codex-*.md) printf '.sage/docs/decision-codex-*.md' ;;
        .sage/docs/analysis-codex-*.md) printf '.sage/docs/analysis-codex-*.md' ;;
        *) return 1 ;;
    esac
}

manifest_scope_contains() {
    local manifest="$1"
    local pattern="$2"
    manifest_yaml "$manifest" | yq eval '.scope[]? // ""' - 2>/dev/null | grep -Fxq "$pattern"
}

manifest_scope_add() {
    local manifest="$1"
    shift
    local additions=""
    local pattern
    for pattern in "$@"; do
        [ -n "$pattern" ] || continue
        additions="${additions}  - \"${pattern}\"
"
    done
    [ -n "$additions" ] || return 0

    local tmp add_file
    tmp="$(mktemp "${manifest}.XXXXXX")" || return 1
    add_file="$(mktemp "${manifest}.add.XXXXXX")" || return 1
    printf '%s' "$additions" > "$add_file"
    awk -v add_file="$add_file" '
        function emit_additions() {
            while ((getline add_line < add_file) > 0) print add_line
            close(add_file)
        }
        BEGIN { in_fm = 0; fm_seen = 0; in_scope = 0; added = 0; saw_scope = 0 }
        NR == 1 && $0 == "---" { in_fm = 1; fm_seen = 1; print; next }
        in_fm && $0 == "---" {
            if (!added) {
                if (!saw_scope) print "scope:"
                emit_additions()
                added = 1
            }
            in_fm = 0
            print
            next
        }
        in_fm && /^scope:[[:space:]]*$/ {
            saw_scope = 1
            in_scope = 1
            print
            next
        }
        in_fm && in_scope && /^[A-Za-z0-9_-]+:[[:space:]]*/ {
            if (!added) {
                emit_additions()
                added = 1
            }
            in_scope = 0
            print
            next
        }
        { print }
        END {
            if (!fm_seen && !added) {
                print "---"
                print "scope:"
                emit_additions()
                print "---"
            }
        }
    ' "$manifest" > "$tmp" && mv "$tmp" "$manifest"
    rm -f "$add_file" "$tmp" 2>/dev/null || true
}

try_safe_scope_autofix() {
    local cwd="$1"
    local cycle_id="$2"
    local manifest="$3"
    local session_id="$4"
    shift 4

    local workflow
    workflow="$(manifest_frontmatter_value "$manifest" "workflow")"
    [ "$workflow" = "architect" ] || return 1

    local patterns=()
    local path pattern
    for path in "$@"; do
        pattern="$(scope_pattern_for_safe_doc "$path")" || return 1
        if ! manifest_scope_contains "$manifest" "$pattern"; then
            patterns+=("$pattern")
        fi
    done
    [ "${#patterns[@]}" -gt 0 ] || return 0

    manifest_scope_add "$manifest" "${patterns[@]}" || return 1

    local ts paths_json patterns_json log_line
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    paths_json="$(printf '%s\n' "$@" | jq -R . | jq -sc .)"
    patterns_json="$(printf '%s\n' "${patterns[@]}" | jq -R . | jq -sc .)"
    log_line="$(jq -nc --arg sid "$session_id" --arg ts "$ts" --arg cycle "$cycle_id" \
        --arg fix "manifest_scope_add" \
        --arg severity "info" \
        --arg detected "architect documentation path outside manifest scope" \
        --arg why "reversible same-cycle metadata repair; no implementation, product behavior, priority, or risk changed" \
        --arg result "manifest scope now includes deterministic architect documentation pattern" \
        --arg next "continue current workflow mutation" \
        --argjson paths "$paths_json" --argjson patterns "$patterns_json" \
        '{kind:"safe_auto_fix", fix:$fix, severity:$severity, session_id:$sid, ts:$ts, cycle_id:$cycle, detected:$detected, paths:$paths, added_scope:$patterns, why_safe:$why, result:$result, next:$next}')"
    json_log_append "$cwd/.sage/.auto-fixes.log" "$log_line"
    return 0
}
