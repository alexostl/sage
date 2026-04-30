#!/usr/bin/env bash
# path_normalize.sh — canonicalize apply_patch DSL paths to relative-to-cwd.
#
# Why: Codex 0.126.0-alpha.15 emits ABSOLUTE paths in apply_patch DSL
# (e.g. /private/var/folders/.../target/AGENTS.md), while
# `git status --porcelain` emits relative paths (AGENTS.md). The
# bypass_mutation + claim_no_op + unclaimed_change comparisons all
# mismatch unless we strip a common prefix first.
#
# macOS additionally surfaces /var → /private/var symlink resolution
# differently per caller — one side may have the /private prefix and
# the other may not. We tolerate both forms.
#
# Pure bash 3.2 (macOS default). No realpath dependency — that varies
# between BSD/GNU and isn't always installed.
#
# v1 spec ref: §6.6 (cross-script common helpers).
# v1 plan ref: T2.7 follow-up (path-format mismatch surfaced by harness).

normalize_path() {
    local path="$1"
    local base="${2:-$PWD}"

    # Strip trailing slash on base (so "/tmp/project/" + "/tmp/project/X" works).
    case "$base" in
        */) base="${base%/}" ;;
    esac

    # Already relative — leave alone.
    case "$path" in
        /*) ;;
        *) printf '%s' "$path"; return 0 ;;
    esac

    # Direct cwd prefix.
    case "$path" in
        "$base") printf '.'; return 0 ;;
        "$base"/*) printf '%s' "${path#"$base"/}"; return 0 ;;
    esac

    # macOS /private/<base> ↔ <base> (path has /private, base doesn't).
    case "$path" in
        "/private$base") printf '.'; return 0 ;;
        "/private$base"/*) printf '%s' "${path#"/private$base"/}"; return 0 ;;
    esac

    # macOS <stripped> ↔ /private/<stripped> (base has /private, path doesn't).
    case "$base" in
        /private/*)
            local stripped="${base#/private}"
            case "$path" in
                "$stripped") printf '.'; return 0 ;;
                "$stripped"/*) printf '%s' "${path#"$stripped"/}"; return 0 ;;
            esac
            ;;
    esac

    # Outside cwd — preserve absolute path so out-of-scope rejection can fire.
    printf '%s' "$path"
    return 0
}
