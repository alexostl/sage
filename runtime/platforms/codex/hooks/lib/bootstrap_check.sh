#!/usr/bin/env bash
# bootstrap_check.sh — detect the chicken-egg bootstrap PreToolUse case.
#
# Why: pre-tool-validate rejects when no in-progress manifest exists, but the
# very first apply_patch on a fresh /sage:build CREATES the manifest the
# predicate needs. We allow that one specific shape: all claimed paths
# confined to a single new or empty .sage/work/<id>/ directory + optionally
# .sage/decisions.md, manifest.md among them, <id> matches YYYYMMDD-<slug>,
# and the cycle dir does not already contain files.
#
# v1 plan ref: F-1 Phase 1 BUG-F1-1.

bootstrap_cycle_id() {
    local cwd="$1"; shift
    local bootstrap_id="" has_manifest=0 path this_id
    for path in "$@"; do
        case "$path" in
            .sage/decisions.md) continue ;;
            .sage/work/*/manifest.md)
                this_id="${path#.sage/work/}"; this_id="${this_id%/manifest.md}"
                has_manifest=1 ;;
            .sage/work/*/*)
                this_id="${path#.sage/work/}"; this_id="${this_id%%/*}" ;;
            *) return 1 ;;
        esac
        if [ -z "$bootstrap_id" ]; then
            bootstrap_id="$this_id"
        elif [ "$bootstrap_id" != "$this_id" ]; then
            return 1
        fi
    done
    [ "$has_manifest" -eq 1 ] || return 1
    case "$bootstrap_id" in
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[a-z0-9]*) ;;
        *) return 1 ;;
    esac
    if [ -d "$cwd/.sage/work/$bootstrap_id" ] && [ -n "$(find "$cwd/.sage/work/$bootstrap_id" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
        return 1
    fi
    printf '%s' "$bootstrap_id"
    return 0
}
