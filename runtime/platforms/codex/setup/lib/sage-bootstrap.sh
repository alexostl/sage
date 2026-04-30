#!/usr/bin/env bash
# sage-bootstrap.sh — Stage 9 (.sage skeleton) + Stage 9a (gates scripts).
#
# Stage 9 creates the per-project Sage state layout when missing:
#   .sage/decisions.md        — '# Decisions' header
#   .sage/{docs,work,gates}/  — with .gitkeep
#   .sage/constitution.md     — frontmatter stub `extends: <preset>` (closes B3)
# When `.sage/` already exists, the skeleton step is skipped (project owns
# its own state). The constitution stub is created only when missing —
# never overwrites a user-edited file.
#
# Stage 9a copies framework gates scripts to <target>/.sage/gates/scripts/
# with mode 0755 (closes B2). Sage owns this directory; user-modified
# files are backed up as `<name>.user-edit-backup-<iso-ts>` then
# overwritten. Empty source dir → info message, exit 0 (no error).
#
# v1 spec ref: §4 Stage 9 + Stage 9a, §15.2 (B2 + B3).
# v1 plan ref: T1.15.

# ------------------------------------------------------------------
# Stage 9 — skeleton + constitution stub
# ------------------------------------------------------------------

_render_constitution_stub() {
    local preset="$1"
    cat <<EOF
---
extends: ${preset}
---

# Project constitution overlay

This file is the user-overlay layer of the §4 Stage 3 merge order
(base → preset → this file). Add lines under '## Project Additions'
below — every non-empty line under that heading becomes an extra
numbered project principle in the generated AGENTS.md. Leave the
section empty (or omit it) to inherit preset defaults verbatim.

## Project Additions

EOF
}

# Hook-only writers — Sage emits these locally; they MUST stay out of git
# (BUG-F1-4: doctor S4 false-positive on hook-only logs in git history).
# Block sentinels make the addition idempotent and user-removable.
_HOOK_GITIGNORE_OPEN='# Sage hook artifacts (managed by `bin/sage init` — remove this block to commit hook logs)'
_HOOK_GITIGNORE_CLOSE='# end Sage hook artifacts'
_HOOK_GITIGNORE_ENTRIES='.sage/.mcp-incidents.log
.sage/.session-mutations.log
.sage/.skipped-checks.log
.sage/.approval-pending
.sage/.codex-validated-version'

ensure_hook_gitignore() {
    local target="$1"
    local gi="$target/.gitignore"
    if [ -f "$gi" ] && grep -qF "$_HOOK_GITIGNORE_OPEN" "$gi" 2>/dev/null; then
        printf 'present'
        return 0
    fi
    if [ ! -f "$gi" ]; then
        : > "$gi"
    elif [ -s "$gi" ]; then
        printf '\n' >> "$gi"
    fi
    {
        printf '%s\n' "$_HOOK_GITIGNORE_OPEN"
        printf '%s\n' "$_HOOK_GITIGNORE_ENTRIES"
        printf '%s\n' "$_HOOK_GITIGNORE_CLOSE"
    } >> "$gi"
    printf 'added'
}

bootstrap_sage() {
    local target="$1"
    local preset="$2"

    local skeleton_created=0
    local constitution_created=0
    local gitignore_state

    if [ ! -d "$target/.sage" ]; then
        mkdir -p \
            "$target/.sage" \
            "$target/.sage/docs" \
            "$target/.sage/work" \
            "$target/.sage/gates"
        printf '# Decisions\n' > "$target/.sage/decisions.md"
        : > "$target/.sage/docs/.gitkeep"
        : > "$target/.sage/work/.gitkeep"
        : > "$target/.sage/gates/.gitkeep"
        skeleton_created=1
    fi

    # Constitution stub — created only when missing, never overwrites.
    # (B3: gives users a discoverable surface for preset overrides.)
    if [ ! -f "$target/.sage/constitution.md" ]; then
        mkdir -p "$target/.sage"
        _render_constitution_stub "$preset" > "$target/.sage/constitution.md"
        constitution_created=1
    fi

    gitignore_state="$(ensure_hook_gitignore "$target")"

    cat <<EOF
[stage 9] bootstrap .sage/
  skeleton_created=$skeleton_created
  constitution_stub_created=$constitution_created
  hook_gitignore=$gitignore_state
  preset=$preset
  dst=$target/.sage
EOF
}

# ------------------------------------------------------------------
# Stage 9a — copy gates scripts
# ------------------------------------------------------------------

deploy_gates() {
    local target="$1"
    local sage_framework="$2"

    local src_dir="$sage_framework/core/gates/scripts"
    if [ ! -d "$src_dir" ]; then
        printf 'generate-codex: missing gates source dir: %s\n' "$src_dir" >&2
        return 1
    fi

    # Empty preset: info message + exit 0 (per spec §4 Stage 9a).
    local src_count
    src_count="$(find "$src_dir" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$src_count" -eq 0 ]; then
        echo "[stage 9a] no gate scripts configured (preset has empty core/gates/scripts/)"
        return 0
    fi

    local dst_dir="$target/.sage/gates/scripts"
    mkdir -p "$dst_dir"

    local backed_up=0
    local deployed=0

    local src
    while IFS= read -r src; do
        [ -n "$src" ] || continue
        local base dst
        base="$(basename "$src")"
        dst="$dst_dir/$base"

        # Backup user edits before overwrite (Sage-owned territory,
        # but never silently lose user work).
        if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
            local ts backup
            ts="$(date -u +%Y%m%dT%H%M%S)"
            backup="${dst}.user-edit-backup-${ts}"
            cp "$dst" "$backup"
            printf 'generate-codex: gates script had user edits — saved to %s\n' "$backup" >&2
            backed_up=$((backed_up + 1))
        fi

        cp "$src" "$dst"
        chmod 0755 "$dst"
        deployed=$((deployed + 1))
    done < <(find "$src_dir" -maxdepth 1 -type f -name '*.sh' 2>/dev/null)

    cat <<EOF
[stage 9a] deployed gates scripts
  count=$deployed
  backed_up=$backed_up
  src=$src_dir
  dst=$dst_dir
EOF
}
