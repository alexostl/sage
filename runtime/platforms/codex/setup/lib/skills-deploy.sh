#!/usr/bin/env bash
# skills-deploy.sh — Stage 7: deploy skill loader stubs.
#
# Codex skill format:
#   <target>/.agents/skills/sage:<wf>/SKILL.md
#
# Each loader is a thin stub: name + description (Tier C preamble
# extracted from `core/workflows/<wf>.workflow.md` via T1.8 helper) +
# a body line referring to the deployed workflow file. In Codex targets,
# the framework is usually vendored under `sage/`, so loaders point at
# `sage/core/workflows/<wf>.workflow.md`. In selfhost/framework targets,
# loaders point at `core/workflows/<wf>.workflow.md`.
#
# v1 spec ref: §4 Stage 7, §5 Tier C.
# v1 plan ref: T1.14.

# ------------------------------------------------------------------
# Public workflow list (locked v1; matches preamble-extraction.bats).
# ------------------------------------------------------------------

CODEX_V1_WORKFLOWS=(
    build fix architect research design analyze qa design-review
    reflect continue learn status review map autoresearch
)

# ------------------------------------------------------------------
# Render a single loader stub
# ------------------------------------------------------------------

_render_skill_loader() {
    local wf="$1"
    local description="$2"
    local source_rel="$3"

    cat <<EOF
---
name: sage:${wf}
description: >-
  ${description}
---

Loader stub for the Sage \`${wf}\` workflow.

Read and follow the full workflow definition at:
  ${source_rel}

The Sage framework owns this directory. Re-deployed by \`bin/sage update\`.
EOF
}

_is_selfhost_target() {
    local target="$1"
    local sage_framework="$2"
    local target_real framework_real

    target_real="$(cd "$target" && pwd -P)"
    framework_real="$(cd "$sage_framework" && pwd -P)"

    if [ "$target_real" = "$framework_real" ]; then
        return 0
    fi

    [ -d "$target/core/workflows" ] && [ -d "$target/core/capabilities" ]
}

_workflow_source_rel() {
    local wf="$1"
    local source_prefix="$2"
    if [ "$source_prefix" = "." ]; then
        printf 'core/workflows/%s.workflow.md\n' "$wf"
    else
        printf '%s/core/workflows/%s.workflow.md\n' "$source_prefix" "$wf"
    fi
}

_navigator_source_rel() {
    local source_prefix="$1"
    if [ "$source_prefix" = "." ]; then
        printf 'core/capabilities/orchestration/sage-navigator/SKILL.md\n'
    else
        printf '%s/core/capabilities/orchestration/sage-navigator/SKILL.md\n' "$source_prefix"
    fi
}

_render_sage_router_fallback() {
    local navigator_rel="$1"

    cat <<EOF
---
name: sage
description: >-
  Primary Sage router. Start here for ambiguous tasks, then route into the right workflow.
---

RULES (apply to every step — non-negotiable):
- Present project state with "Sage:" prefix.
- Present options with [1] [2] [3] bracket notation — ALWAYS.
- Recommend a specific workflow for Standard+ tasks.
- NEVER just ask "What would you like to do?" — present structured choices.
- Never use code blocks for interaction output.

Sage's intelligent entry point. Assess the project and guide the user.

For complex routing or gap detection, read the sage-navigator at
\`${navigator_rel}\`.

The Sage framework owns this directory. Re-deployed by \`bin/sage update\`.
EOF
}

_deploy_sage_router() {
    local target="$1"
    local sage_framework="$2"
    local navigator_rel="$3"
    local skills_dir="$target/.agents/skills"
    local router_dir="$skills_dir/sage"
    local source_router="$sage_framework/.agents/skills/sage/SKILL.md"

    mkdir -p "$router_dir"

    if [ -f "$source_router" ]; then
        local source_real dest_real tmp
        source_real="$(cd "$(dirname "$source_router")" && pwd -P)/$(basename "$source_router")"
        dest_real="$(cd "$router_dir" && pwd -P)/SKILL.md"
        if [ "$source_real" = "$dest_real" ]; then
            _render_sage_router_fallback "$navigator_rel" > "$router_dir/SKILL.md"
            return 0
        fi
        tmp="$(mktemp)"
        sed -E \
            -e "s#(sage/)?core/capabilities/orchestration/sage-navigator/SKILL\\.md#${navigator_rel}#g" \
            "$source_router" > "$tmp"
        mv "$tmp" "$router_dir/SKILL.md"
    else
        _render_sage_router_fallback "$navigator_rel" > "$router_dir/SKILL.md"
    fi
}

_deploy_sage_navigator() {
    local target="$1"
    local sage_framework="$2"
    local skills_dir="$target/.agents/skills"
    local navigator_src="$sage_framework/core/capabilities/orchestration/sage-navigator/SKILL.md"
    local navigator_dir="$skills_dir/sage-navigator"

    if [ ! -f "$navigator_src" ]; then
        printf 'generate-codex: missing sage-navigator source: %s\n' "$navigator_src" >&2
        return 1
    fi

    mkdir -p "$navigator_dir"
    cp "$navigator_src" "$navigator_dir/SKILL.md"
}

# ------------------------------------------------------------------
# Description fallback (used if extract-preamble fails)
# ------------------------------------------------------------------

_default_description() {
    local wf="$1"
    echo "Sage ${wf} workflow."
}

# ------------------------------------------------------------------
# Public entry point
# ------------------------------------------------------------------

deploy_skills() {
    local target="$1"
    local sage_framework="$2"

    local extractor="$sage_framework/runtime/platforms/codex/setup/lib/extract-preamble.sh"
    if [ ! -f "$extractor" ]; then
        printf 'generate-codex: missing preamble extractor: %s\n' "$extractor" >&2
        return 1
    fi

    local workflows_dir="$sage_framework/core/workflows"
    if [ ! -d "$workflows_dir" ]; then
        printf 'generate-codex: missing workflows dir: %s\n' "$workflows_dir" >&2
        return 1
    fi

    local skills_dir="$target/.agents/skills"
    mkdir -p "$skills_dir"

    local source_prefix="sage"
    if _is_selfhost_target "$target" "$sage_framework"; then
        source_prefix="."
    fi
    local navigator_rel
    navigator_rel="$(_navigator_source_rel "$source_prefix")"

    _deploy_sage_router "$target" "$sage_framework" "$navigator_rel"
    _deploy_sage_navigator "$target" "$sage_framework"

    # Remove legacy duplicate generated by older Stage 7 versions.
    rm -rf "$skills_dir/sage:sage"

    local deployed=0
    local wf
    for wf in "${CODEX_V1_WORKFLOWS[@]}"; do
        local src="$workflows_dir/${wf}.workflow.md"
        if [ ! -f "$src" ]; then
            printf 'generate-codex: workflow source missing: %s\n' "$src" >&2
            return 1
        fi

        local description
        description="$(bash "$extractor" "$src" 2>/dev/null || true)"
        if [ -z "$description" ]; then
            description="$(_default_description "$wf")"
        fi

        local skill_dir="$skills_dir/sage:${wf}"
        mkdir -p "$skill_dir"
        _render_skill_loader "$wf" "$description" "$(_workflow_source_rel "$wf" "$source_prefix")" > "$skill_dir/SKILL.md"

        deployed=$((deployed + 1))
    done

    cat <<EOF
[stage 7] deployed skill loader stubs
  count=$deployed
  dst=$skills_dir
EOF
}
