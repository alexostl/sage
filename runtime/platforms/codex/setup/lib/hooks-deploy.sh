#!/usr/bin/env bash
# hooks-deploy.sh — Stage 5 (.codex/hooks.json) + Stage 6 (deploy hook scripts).
#
# Stage 5: full regenerate of `.codex/hooks.json` registry.
#   - 4 events × 1 hook each (SessionStart, PreToolUse[apply_patch],
#     PostToolUse[apply_patch], Stop).
#   - If a different file is present: backup as
#     `hooks.json.user-edit-backup-<iso-ts>`, then overwrite.
#
# Stage 6: copy `<sage>/runtime/platforms/codex/hooks/{*.sh,lib/}` →
#   `<target>/.codex/hooks/`. Mode 0755. Full regenerate, no backup.
#
# v1 spec ref: §4 Stage 5 + Stage 6.
# v1 plan ref: T1.13.

# v1 hook list — 4 events. ups-approval.sh deferred to v2 per §6.2.
CODEX_V1_HOOKS=(session-init pre-tool-validate post-tool-check turn-audit)

# ------------------------------------------------------------------
# Stage 5 — hooks.json
# ------------------------------------------------------------------

_build_hooks_json() {
    cat <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": ".codex/hooks/session-init.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "apply_patch",
        "hooks": [
          { "type": "command", "command": ".codex/hooks/pre-tool-validate.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "apply_patch",
        "hooks": [
          { "type": "command", "command": ".codex/hooks/post-tool-check.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": ".codex/hooks/turn-audit.sh" }
        ]
      }
    ]
  }
}
EOF
}

compose_hooks_json() {
    local target="$1"
    mkdir -p "$target/.codex"
    local target_file="$target/.codex/hooks.json"

    local fresh
    fresh="$(_build_hooks_json)"

    if [ -f "$target_file" ]; then
        # Backup if existing content differs from what we'd write.
        if ! diff -q <(printf '%s\n' "$fresh") "$target_file" >/dev/null 2>&1; then
            local ts backup
            ts="$(date -u +%Y%m%dT%H%M%S)"
            backup="${target_file}.user-edit-backup-${ts}"
            cp "$target_file" "$backup"
            printf 'generate-codex: .codex/hooks.json had user edits — saved to %s\n' "$backup" >&2
        fi
    fi

    printf '%s\n' "$fresh" > "$target_file"

    cat <<EOF
[stage 5] composed .codex/hooks.json
  events=SessionStart, PreToolUse[apply_patch], PostToolUse[apply_patch], Stop
  path=$target_file
EOF
}

# ------------------------------------------------------------------
# Stage 6 — deploy hook scripts
# ------------------------------------------------------------------

deploy_hooks() {
    local target="$1"
    local sage_framework="$2"

    local src_dir="$sage_framework/runtime/platforms/codex/hooks"
    if [ ! -d "$src_dir" ]; then
        printf 'generate-codex: missing hook source dir: %s\n' "$src_dir" >&2
        return 1
    fi

    local dst_dir="$target/.codex/hooks"
    mkdir -p "$dst_dir/lib"

    # 1) Hook scripts (full regenerate, mode 0755, no backup).
    local hook
    for hook in "${CODEX_V1_HOOKS[@]}"; do
        local src="$src_dir/$hook.sh"
        if [ ! -f "$src" ]; then
            printf 'generate-codex: missing hook source: %s\n' "$src" >&2
            return 1
        fi
        cp "$src" "$dst_dir/$hook.sh"
        chmod 0755 "$dst_dir/$hook.sh"
    done

    # 2) lib/ helpers (json_log.sh + active_init.sh).
    if [ -d "$src_dir/lib" ]; then
        local libfile
        for libfile in "$src_dir/lib"/*.sh; do
            [ -f "$libfile" ] || continue
            local base
            base="$(basename "$libfile")"
            cp "$libfile" "$dst_dir/lib/$base"
            chmod 0644 "$dst_dir/lib/$base"
        done
    fi

    cat <<EOF
[stage 6] deployed hook scripts
  scripts=${#CODEX_V1_HOOKS[@]} (${CODEX_V1_HOOKS[*]})
  dst=$dst_dir
EOF
}
