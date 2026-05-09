#!/usr/bin/env bash
# active_init.sh — return path of newest in-progress cycle.
#
# Usage (sourced by hook scripts):
#   source "$(dirname "$0")/lib/active_init.sh"
#   cycle_dir="$(active_init_path "$PROJECT_ROOT")"
#
# Echoes cycle dir path (e.g. /repo/.sage/work/20260101-foo) or empty.
# When multiple in-progress cycles exist, picks newest manifest mtime
# and writes warning to <root>/.sage/.skipped-checks.log.
#
# v1 spec ref: §6.6 (cross-script common helpers).
# v1 plan ref: T1.2 (Group A foundation).
# F-1 fix ref: BUG-F1-2 (yq exits non-zero when markdown body contains
# YAML-like content like `- brief.md: exists`; we extract frontmatter
# explicitly so yq sees only the YAML doc, never the body).

manifest_yaml() {
    local manifest="$1"
    if [ -f "$manifest" ] && [ "$(head -1 "$manifest" 2>/dev/null)" = "---" ]; then
        awk 'NR==1 && /^---$/{next} /^---$/{exit} {print}' "$manifest"
    else
        cat "$manifest" 2>/dev/null
    fi
}

active_init_path() {
    local project_root="$1"
    local work_dir="$project_root/.sage/work"
    [ -d "$work_dir" ] || return 0

    local newest_path=""
    local newest_mtime=0
    local matched_count=0
    local matched_list=""

    local manifest
    for manifest in "$work_dir"/*/manifest.md; do
        [ -f "$manifest" ] || continue
        local status
        status=$(manifest_yaml "$manifest" | yq eval '.status // ""' - 2>/dev/null) || continue
        [ "$status" = "in-progress" ] || continue
        local mtime
        mtime=$(stat -c '%Y' "$manifest" 2>/dev/null || stat -f '%m' "$manifest" 2>/dev/null) || continue
        matched_count=$((matched_count + 1))
        matched_list="$matched_list $manifest"
        if [ "$mtime" -gt "$newest_mtime" ]; then
            newest_mtime="$mtime"
            newest_path="$(dirname "$manifest")"
        fi
    done

    if [ "$matched_count" -gt 1 ]; then
        local skip_log="$project_root/.sage/.skipped-checks.log"
        mkdir -p "$(dirname "$skip_log")" 2>/dev/null
        local ts
        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
        printf '%s active_init: multiple in-progress cycles found, picked newest=%s; all=%s\n' \
            "$ts" "$newest_path" "$matched_list" >> "$skip_log"
    fi

    [ -n "$newest_path" ] && printf '%s\n' "$newest_path"
    return 0
}

resumable_cycles_summary() {
    local project_root="$1"
    local work_dir="$project_root/.sage/work"
    [ -d "$work_dir" ] || return 0

    local manifest out="" count=0
    for manifest in "$work_dir"/*/manifest.md; do
        [ -f "$manifest" ] || continue
        local status id phase
        status=$(manifest_yaml "$manifest" | yq eval '.status // ""' - 2>/dev/null) || continue
        case "$status" in paused|intake) ;; *) continue ;; esac
        id="$(basename "$(dirname "$manifest")")"
        phase="$(manifest_yaml "$manifest" | yq eval '.phase // ""' - 2>/dev/null || true)"
        count=$((count + 1))
        if [ -z "$out" ]; then
            out="${id} status=${status} phase=${phase:-unknown}"
        else
            out="${out}; ${id} status=${status} phase=${phase:-unknown}"
        fi
    done

    [ "$count" -gt 0 ] && printf '%s\n' "$out"
    return 0
}

path_cycle_ids() {
    local path this_id seen="" out=""
    for path in "$@"; do
        case "$path" in
            .sage/work/*/*)
                this_id="${path#.sage/work/}"
                this_id="${this_id%%/*}" ;;
            *) continue ;;
        esac
        case " $seen " in
            *" $this_id "*) ;;
            *)
                seen="$seen $this_id"
                if [ -z "$out" ]; then
                    out="$this_id"
                else
                    out="$out
$this_id"
                fi ;;
        esac
    done
    [ -n "$out" ] && printf '%s\n' "$out"
    return 0
}

cycle_status() {
    local project_root="$1"
    local cycle_id="$2"
    local manifest="$project_root/.sage/work/$cycle_id/manifest.md"
    [ -f "$manifest" ] || return 1
    manifest_yaml "$manifest" | yq eval '.status // ""' - 2>/dev/null
}

resolve_cycle_for_patch() {
    local project_root="$1"; shift
    local cycle_ids count cycle_id status
    cycle_ids="$(path_cycle_ids "$@" || true)"
    count="$(printf '%s\n' "$cycle_ids" | sed '/^$/d' | wc -l | tr -d ' ')"

    if [ "$count" -gt 1 ]; then
        printf 'ambiguous:%s\n' "$(printf '%s' "$cycle_ids" | tr '\n' ' ')"
        return 0
    fi

    if [ "$count" -eq 1 ]; then
        cycle_id="$(printf '%s\n' "$cycle_ids" | sed -n '1p')"
        if bootstrap_cycle_id "$project_root" "$@" >/dev/null 2>&1; then
            printf 'bootstrap:%s\n' "$cycle_id"
            return 0
        fi
        status="$(cycle_status "$project_root" "$cycle_id" 2>/dev/null || true)"
        case "$status" in
            in-progress)
                printf 'active:%s\n' "$project_root/.sage/work/$cycle_id"
                return 0 ;;
            paused|intake)
                printf 'parked-capture:%s\n' "$project_root/.sage/work/$cycle_id"
                return 0 ;;
        esac
    fi

    local active
    active="$(active_init_path "$project_root")"
    if [ -n "$active" ]; then
        printf 'active:%s\n' "$active"
        return 0
    fi

    if cycle_id="$(bootstrap_cycle_id "$project_root" "$@" 2>/dev/null)"; then
        printf 'bootstrap:%s\n' "$cycle_id"
        return 0
    fi

    printf 'none:\n'
    return 0
}
