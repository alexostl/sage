#!/usr/bin/env bash
# skills-deploy.sh — Stage 7: deploy skill loader stubs.
#
# Codex skill format:
#   <target>/.agents/skills/sage:<wf>/SKILL.md
#
# Each loader is a thin stub: name + description (Tier C preamble
# extracted from `core/workflows/<wf>.workflow.md` via T1.8 helper) +
# a body line referring to the deployed workflow file. In Codex targets,
# the framework is vendored under `sage/`, so loaders must point at
# `sage/core/workflows/<wf>.workflow.md`.
#
# v1 spec ref: §4 Stage 7, §5 Tier C.
# v1 plan ref: T1.14.

# ------------------------------------------------------------------
# Public workflow list (locked v1; matches preamble-extraction.bats).
# ------------------------------------------------------------------

CODEX_V1_WORKFLOWS=(
    build fix architect research design analyze sage qa design-review
    reflect continue learn status review map autoresearch
)

# ------------------------------------------------------------------
# Render a single loader stub
# ------------------------------------------------------------------

_render_skill_loader() {
    local wf="$1"
    local description="$2"
    local source_rel="sage/core/workflows/${wf}.workflow.md"

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
        _render_skill_loader "$wf" "$description" > "$skill_dir/SKILL.md"

        deployed=$((deployed + 1))
    done

    cat <<EOF
[stage 7] deployed skill loader stubs
  count=$deployed
  dst=$skills_dir
EOF
}
