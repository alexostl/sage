#!/usr/bin/env bash
# shellcheck disable=SC2001
# agents-md.sh — Stage 3 composer for `<target>/AGENTS.md`.
# (SC2001 disabled: `sed 's/^[0-9]*\.//'` is the clearest expression of
# "strip leading numbering"; bash param-expansion equivalent is ugly.)
#
# Responsibilities:
#   1. Detect Rule 1A variant (mcp vs filesystem) from .codex/config.toml.
#   2. Resolve effective preset from --preset and .sage/constitution.md
#      extends: field (user overlay wins).
#   3. Build merged constitution (base + preset overlay + user additions).
#   4. Render template body with __CONSTITUTION_PLACEHOLDER__ substitution.
#   5. Apply prefix-managed write (preserve content below SAGE-MANAGED-END;
#      backup + regenerate if marker absent and file present).
#
# Entry point: compose_agents_md <target> <preset> <sage_framework>
#
# v1 spec ref: §4 Stage 3 (B1 Rule 1A variant + B3 user overlay).
# v1 plan ref: T1.11.

# ------------------------------------------------------------------
# Rule 1A variant detection (B1)
# ------------------------------------------------------------------

_detect_rule_1a_variant() {
    local target="$1"
    local cfg="$target/.codex/config.toml"
    if [ -f "$cfg" ] && grep -qE '^\[\[mcp_servers\]\]' "$cfg" 2>/dev/null; then
        echo "mcp"
    else
        echo "filesystem"
    fi
}

# ------------------------------------------------------------------
# Effective preset resolution (B3 user overlay)
# ------------------------------------------------------------------

_resolve_effective_preset() {
    local target="$1"
    local cli_preset="$2"
    local user_const="$target/.sage/constitution.md"
    local user_extends=""
    if [ -f "$user_const" ]; then
        user_extends="$(awk '/^---$/{c++; next} c==1 && /^extends:/{sub(/^extends:[[:space:]]*/,""); print; exit} c>=2{exit}' "$user_const" 2>/dev/null | tr -d '[:space:]')"
    fi
    if [ -n "$user_extends" ]; then
        echo "$user_extends"
    else
        echo "$cli_preset"
    fi
}

# ------------------------------------------------------------------
# Constitution section composer (3-layer merge)
# ------------------------------------------------------------------

_compose_constitution_section() {
    local effective_preset="$1"
    local sage_framework="$2"
    local target="$3"

    local base_section
    base_section="## Engineering Principles

Base (all projects):
1. Tests before code — every behavior has a test before implementation
2. No silent failures — errors handled, logged, or propagated
3. Secrets never in code — use env vars or secret managers
4. Dependencies explicit — declared with pinned versions
5. Changes reversible — migrations reversible, deployments rollbackable"

    local principle_num=5
    local out="$base_section"

    # Layer 2 — preset overlay (sentinel-bypass per T1.9).
    case "$effective_preset" in
        base|none|"")
            : # sentinel — base alone is sufficient, no warning
            ;;
        *)
            local preset_file="$sage_framework/core/constitution/presets/${effective_preset}.constitution.md"
            if [ -f "$preset_file" ]; then
                local preset_lines
                preset_lines="$(sed -n '/^## Additions/,$ { /^[0-9]/p; }' "$preset_file")"
                if [ -n "$preset_lines" ]; then
                    out="$out

${effective_preset} preset:"
                    while IFS= read -r line; do
                        [ -n "$line" ] || continue
                        principle_num=$((principle_num + 1))
                        # Strip leading "<num>. " from upstream numbering.
                        # shellcheck disable=SC2001
                        local clean
                        clean="$(echo "$line" | sed 's/^[0-9]*\.[[:space:]]*//')"
                        out="$out
${principle_num}. ${clean}"
                    done <<< "$preset_lines"
                fi
            else
                printf 'generate-codex: Preset overlay missing: %s — falling back to base layer\n' \
                    "$effective_preset" >&2
            fi
            ;;
    esac

    # Layer 3 — user overlay project additions.
    local user_const="$target/.sage/constitution.md"
    if [ -f "$user_const" ]; then
        local additions
        additions="$(sed -n '/^## Project Additions/,$ { /^## Project Additions/d; /^[[:space:]]*$/d; p; }' "$user_const" 2>/dev/null)"
        if [ -n "$additions" ]; then
            out="$out

Project additions:"
            while IFS= read -r line; do
                [ -n "$line" ] || continue
                principle_num=$((principle_num + 1))
                # shellcheck disable=SC2001
                local clean
                clean="$(echo "$line" | sed 's/^[0-9]*\.[[:space:]]*//')"
                out="$out
${principle_num}. ${clean}"
            done <<< "$additions"
        fi
    fi

    printf '%s\n' "$out"
}

# ------------------------------------------------------------------
# Rule 1A renderer (variant-aware)
# ------------------------------------------------------------------

_render_rule_1a() {
    local variant="$1"
    if [ "$variant" = "mcp" ]; then
        cat <<'EOF'
### Rule 1A — Memory Before Work (MANDATORY for Standard+)

Before writing specs, plans, ADRs, or starting an investigation,
search sage-memory. This prevents repeating past mistakes.

Two searches minimum:
1. General domain search — query with task domain keywords, limit 5
2. Self-learning search — same query with filter_tags ["self-learning"], limit 5

**MCP parameter types:** query is a string, limit is an integer (not "5"),
filter_tags and tags are arrays of strings (not JSON strings).

If sage-memory MCP is unavailable, check `.sage-memory/` folder. Skip
only for Tier 1 tasks.

**Compliance:** Every Standard+ workflow start includes at least one
sage_memory_search call before producing artifacts.
EOF
    else
        cat <<'EOF'
### Rule 1A — Memory Before Work (MANDATORY for Standard+) — v1 filesystem variant

Before writing specs, plans, ADRs, or starting an investigation,
check `<target>/.sage-memory/` for past learnings on the current
task domain. Skim filenames and read any file whose name matches
the task keywords (or `self-learning.md` if it exists). Use findings
to inform your approach.

**Note:** v1 ships without the Sage Memory MCP server; filesystem
fallback is the only v1 path. v2 will reintroduce `sage_memory_search`
per §8 promotion trigger — at which point this rule reverts to the
MCP-tool form. Skip only for Tier 1 tasks.

**Compliance:** Every Standard+ workflow start includes at least one
filesystem check of `.sage-memory/` before producing artifacts.
EOF
    fi
}

# ------------------------------------------------------------------
# Sage prefix body (everything above SAGE-MANAGED-END marker)
# ------------------------------------------------------------------

_build_sage_prefix() {
    local effective_preset="$1"
    local sage_framework="$2"
    local target="$3"
    local rule_1a_variant="$4"

    local const_section
    const_section="$(_compose_constitution_section "$effective_preset" "$sage_framework" "$target")"

    local rule_1a_block
    rule_1a_block="$(_render_rule_1a "$rule_1a_variant")"

    cat <<EOF
# Sage — Project Instructions

> Auto-generated by Sage. Regenerate with \`bin/sage update\`.
> Content below \`<!-- SAGE-MANAGED-END -->\` is yours, edit freely.

## Constitution

These rules apply to EVERY response. Each has a compliance check —
an observable signal the rule was followed.

${rule_1a_block}

### Rule 0 — Route Work, Preserve Conversation

Before doing Standard+ work, route to the right Sage workflow. Conversation
is not work by itself: conversational/read-only questions can be answered
without workflow by default.

Classify the user's mandate:
- conversational/read-only question → answer conversationally by default;
  do not announce a workflow or write artifacts
- explicit workflow command (\`\$sage:build\`, \`\$sage:fix\`, etc.) → enter that
  workflow and follow its gates
- action mandate, including polite question-form mandates like "Can you fix
  this?", "Could you implement this?", or "Would you run a smoke test?" →
  route to workflow or confirmation
- ambiguous/borderline prompt → use soft confirmation before workflow

When active work exists, acknowledge it when relevant, but unrelated
read-only questions may be answered from context without resuming
implementation. After workflow entry, Codex-native enforcement still applies:
spec/plan gates, fix root-cause approval, manifest scope protection, and
verification-before-done remain mandatory.

Moderate+ fixes must update plan.md and manifest.md before code changes.
Writing plan.md or manifest.md after code does not cure the violation.

### Rule 1 — State First

Before any substantial response, scan \`.sage/work/\` frontmatter for
active initiatives. Read \`.sage/decisions.md\` for recent context.
Never start fresh when there is existing context.

### Rule 2 — Skills Before Assumptions

If a Sage skill exists for the current task, read and follow it.
Skills live in \`.agents/skills/\`. Do NOT rely on general training
when a skill provides specific methodology.

### Rule 3 — Document Decisions

Decisions that affect the project must be recorded. Specs, plans,
ADRs, and briefs go to \`.sage/work/\` or \`.sage/docs/\`.

### Rule 4 — Checkpoints Are Sacred

Never skip human approval on briefs, specs, plans, or final
deliverables. Show the work. Wait for approval. Never change scope
unilaterally.

### Rule 5 — Verify Before Claiming Done

Before any completion checkpoint: tests exist, tests pass (paste
actual output, do not summarize), implementation matches the spec.

### Rule 6 — Capture Corrections

When a learning moment occurs, store it via self-learning before
proceeding. This is automatic, not optional.

### Rule 7 — Record Decisions at Checkpoints

At each checkpoint, **prepend** significant decisions to
\`.sage/decisions.md\`. Newest first.

${const_section}

## Available Skills

Sage skills are deployed under \`.agents/skills/\`. Type \`/\` in your
agent UI to see all available commands and skills.

## Project State

All Sage state lives in \`.sage/\`:
- \`decisions.md\` — shared decision log (agent + human)
- \`docs/\` — project-level knowledge (analyses, ADRs, guides)
- \`work/\` — per-initiative deliverables with YAML frontmatter
- \`gates/\` — quality gate scripts and activation config

<!-- SAGE-MANAGED-END — do not modify or move this line. Content above is regenerated. Content below is yours. -->
EOF
}

# ------------------------------------------------------------------
# Prefix-managed write (preserve user territory below marker)
# ------------------------------------------------------------------

_write_with_marker_strategy() {
    local target_file="$1"
    local sage_prefix="$2"

    if [ ! -f "$target_file" ]; then
        # Fresh file — just write the prefix (which ends with the marker).
        printf '%s\n' "$sage_prefix" > "$target_file"
        return 0
    fi

    if grep -q '<!-- SAGE-MANAGED-END' "$target_file"; then
        # Marker present — preserve everything from the marker line onward.
        local user_territory
        user_territory="$(awk '/<!-- SAGE-MANAGED-END/{found=1} found{print}' "$target_file")"
        # Strip the marker line itself from user_territory (we re-emit it via prefix).
        user_territory="$(printf '%s' "$user_territory" | sed -n '2,$p')"
        if [ -n "$user_territory" ]; then
            printf '%s\n%s\n' "$sage_prefix" "$user_territory" > "$target_file"
        else
            printf '%s\n' "$sage_prefix" > "$target_file"
        fi
        return 0
    fi

    # No marker — back up the user file, then regenerate fresh.
    local ts backup
    ts="$(date -u +%Y%m%dT%H%M%S)"
    backup="${target_file}.user-backup-${ts}"
    cp "$target_file" "$backup"
    printf 'generate-codex: AGENTS.md had no SAGE-MANAGED-END marker — saved your previous content to %s\n' "$backup" >&2
    printf '%s\n' "$sage_prefix" > "$target_file"
}

# ------------------------------------------------------------------
# Public entry point
# ------------------------------------------------------------------

compose_agents_md() {
    local target="$1"
    local cli_preset="$2"
    local sage_framework="$3"

    local rule_1a_variant
    rule_1a_variant="$(_detect_rule_1a_variant "$target")"

    local effective_preset
    effective_preset="$(_resolve_effective_preset "$target" "$cli_preset")"

    local sage_prefix
    sage_prefix="$(_build_sage_prefix "$effective_preset" "$sage_framework" "$target" "$rule_1a_variant")"

    _write_with_marker_strategy "$target/AGENTS.md" "$sage_prefix"

    cat <<EOF
[stage 3] composed AGENTS.md
  preset_cli=$cli_preset
  preset_effective=$effective_preset
  rule_1a_variant=$rule_1a_variant
  path=$target/AGENTS.md
EOF
}
