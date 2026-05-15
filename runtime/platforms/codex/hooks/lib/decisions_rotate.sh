#!/usr/bin/env bash
# decisions_rotate.sh — bounded `.sage/decisions.md` retention for Codex hooks.

is_primary_git_checkout() {
    local cwd="$1"
    command -v git >/dev/null 2>&1 || return 1
    local git_dir common_dir
    git_dir="$(git -C "$cwd" rev-parse --path-format=absolute --git-dir 2>/dev/null)" || return 1
    common_dir="$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
    [ "$git_dir" = "$common_dir" ]
}

decisions_rotate_if_needed() {
    local cwd="$1"
    local decisions="$cwd/.sage/decisions.md"
    local archive="$cwd/.sage/decisions-archive.md"

    is_primary_git_checkout "$cwd" || return 0
    [ -f "$decisions" ] || return 0
    [ "$(sed -n '1p' "$decisions" 2>/dev/null || true)" = "# Decisions" ] || return 0

    local count overflow_start
    count="$(grep -c '^### ' "$decisions" 2>/dev/null || true)"
    case "$count" in ''|*[!0-9]*) return 0 ;; esac
    [ "$count" -gt 50 ] || return 0

    overflow_start="$(grep -n '^### ' "$decisions" 2>/dev/null | sed -n '51p' | cut -d: -f1)"
    case "$overflow_start" in ''|*[!0-9]*) return 0 ;; esac

    local dir current_tmp overflow_tmp archive_tmp archive_head_tmp archive_body_tmp
    dir="$(dirname "$decisions")"
    current_tmp="$(mktemp "$dir/decisions.current.XXXXXX")" || return 0
    overflow_tmp="$(mktemp "$dir/decisions.overflow.XXXXXX")" || {
        rm -f "$current_tmp"
        return 0
    }
    archive_tmp="$(mktemp "$dir/decisions.archive.XXXXXX")" || {
        rm -f "$current_tmp" "$overflow_tmp"
        return 0
    }
    archive_head_tmp="$(mktemp "$dir/decisions.archive.head.XXXXXX")" || {
        rm -f "$current_tmp" "$overflow_tmp" "$archive_tmp"
        return 0
    }
    archive_body_tmp="$(mktemp "$dir/decisions.archive.body.XXXXXX")" || {
        rm -f "$current_tmp" "$overflow_tmp" "$archive_tmp" "$archive_head_tmp"
        return 0
    }

    sed -n "1,$((overflow_start - 1))p" "$decisions" > "$current_tmp" || {
        rm -f "$current_tmp" "$overflow_tmp" "$archive_tmp" "$archive_head_tmp" "$archive_body_tmp"
        return 0
    }
    sed -n "${overflow_start},\$p" "$decisions" > "$overflow_tmp" || {
        rm -f "$current_tmp" "$overflow_tmp" "$archive_tmp" "$archive_head_tmp" "$archive_body_tmp"
        return 0
    }

    if [ -f "$archive" ]; then
        local first_archive_entry
        first_archive_entry="$(grep -n '^### ' "$archive" 2>/dev/null | sed -n '1p' | cut -d: -f1)"
        if [ -n "$first_archive_entry" ]; then
            sed -n "1,$((first_archive_entry - 1))p" "$archive" > "$archive_head_tmp" || true
            sed -n "${first_archive_entry},\$p" "$archive" > "$archive_body_tmp" || true
        else
            cp "$archive" "$archive_head_tmp" 2>/dev/null || printf '# Decisions Archive\n\n' > "$archive_head_tmp"
            : > "$archive_body_tmp"
        fi
    else
        printf '# Decisions Archive\n\n' > "$archive_head_tmp"
        : > "$archive_body_tmp"
    fi

    {
        cat "$archive_head_tmp"
        awk 'NF { seen = 1 } { print } END { if (seen) print "" }' "$overflow_tmp"
        cat "$archive_body_tmp"
    } > "$archive_tmp" || {
        rm -f "$current_tmp" "$overflow_tmp" "$archive_tmp" "$archive_head_tmp" "$archive_body_tmp"
        return 0
    }

    mv "$current_tmp" "$decisions" || {
        rm -f "$current_tmp" "$overflow_tmp" "$archive_tmp" "$archive_head_tmp" "$archive_body_tmp"
        return 0
    }
    mv "$archive_tmp" "$archive" || true
    rm -f "$current_tmp" "$overflow_tmp" "$archive_tmp" "$archive_head_tmp" "$archive_body_tmp" 2>/dev/null || true
    return 0
}
