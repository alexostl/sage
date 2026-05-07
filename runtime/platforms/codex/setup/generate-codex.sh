#!/usr/bin/env bash
# shellcheck disable=SC2034
# generate-codex.sh — Codex port generator (skeleton).
# (SC2034 disabled file-wide: SCRIPT_DIR + DRY_RUN are pre-wired for T1.11+.)
#
# T1.10 deliverable: bash skeleton with stage functions defined,
# Stages 1, 2, 10 implemented; Stages 3-9a stubbed for T1.11-T1.16.
#
# Usage:
#   SAGE_FRAMEWORK=/path/to/sage-selfhost \
#     generate-codex.sh --target /abs/path --preset base [--stage N] [--dry-run]
#
# Exit codes:
#   0 — success
#   1 — runtime failure (missing tool, IO error)
#   2 — bad invocation (missing/invalid flag, sanity-sweep failure)
#
# v1 spec ref: §4 Stages 1-10.
# v1 plan ref: T1.10 (Group D).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/agents-md.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/config-toml.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/hooks-deploy.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/skills-deploy.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/sage-bootstrap.sh"

# ------------------------------------------------------------------
# argv parsing
# ------------------------------------------------------------------

TARGET=""
PRESET=""
STAGE="all"
# shellcheck disable=SC2034
DRY_RUN=0

print_usage() {
    cat <<'EOF'
generate-codex.sh — Codex port generator (skeleton)

Usage:
  SAGE_FRAMEWORK=<repo> generate-codex.sh --target <abs-path> [options]

Required:
  --target <path>     Absolute path to project where Codex port lands.

Options:
  --preset <name>     Constitution preset: base|startup|enterprise|opensource
                      (default: base). The sentinels base|none|"" skip the
                      preset overlay (base layer alone is the constitution).
  --stage <N>         Run only stage N (1..10, plus 9a). Default: all stages.
  --dry-run           Discover + read; never write files.
  -h, --help          Print this help and exit 0.

Environment:
  SAGE_FRAMEWORK      Path to the sage-selfhost repo (the framework source
                      of truth). Required for Stages 2 and beyond.
EOF
}

die() {
    printf 'generate-codex: %s\n' "$*" >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            print_usage
            exit 0
            ;;
        --target)
            [ "$#" -ge 2 ] || die "--target requires an argument"
            TARGET="$2"
            shift 2
            ;;
        --preset)
            [ "$#" -ge 2 ] || die "--preset requires an argument"
            PRESET="$2"
            shift 2
            ;;
        --stage)
            [ "$#" -ge 2 ] || die "--stage requires an argument"
            STAGE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

# Required-flag validation.
[ -n "$TARGET" ] || die "--target is required (absolute path)"
case "$TARGET" in
    /*) ;;
    *) die "--target must be an absolute path (got: $TARGET)" ;;
esac
[ -d "$TARGET" ] || die "--target points to a non-directory: $TARGET"

[ -n "$PRESET" ] || PRESET="base"

# ------------------------------------------------------------------
# Stage 1 — Discover target project shape
# ------------------------------------------------------------------

stage_1_discover() {
    local is_git_repo="false"
    local has_codex_config_dir="false"
    local has_existing_agents_md="false"
    local has_sage_dir="false"

    [ -d "$TARGET/.git" ]      && is_git_repo="true"
    [ -d "$TARGET/.codex" ]    && has_codex_config_dir="true"
    [ -f "$TARGET/AGENTS.md" ] && has_existing_agents_md="true"
    [ -d "$TARGET/.sage" ]     && has_sage_dir="true"

    cat <<EOF
[stage 1] discover
  project_root=$TARGET
  is_git_repo=$is_git_repo
  has_codex_config_dir=$has_codex_config_dir
  has_existing_agents_md=$has_existing_agents_md
  has_sage_dir=$has_sage_dir
EOF
}

# ------------------------------------------------------------------
# Stage 2 — Read Sage core (workflows, skills)
# ------------------------------------------------------------------

stage_2_read_core() {
    local fw="${SAGE_FRAMEWORK:-}"
    if [ -z "$fw" ] || [ ! -d "$fw" ]; then
        printf 'generate-codex: SAGE_FRAMEWORK not set or not a directory (%s)\n' "$fw" >&2
        return 1
    fi
    [ -d "$fw/core/workflows" ]    || { echo "generate-codex: missing $fw/core/workflows" >&2; return 1; }
    [ -d "$fw/core/capabilities" ] || { echo "generate-codex: missing $fw/core/capabilities" >&2; return 1; }

    local wf_count
    wf_count="$(find "$fw/core/workflows" -maxdepth 1 -type f -name '*.workflow.md' 2>/dev/null | wc -l | tr -d ' ')"

    local skill_count
    skill_count="$(find "$fw/core/capabilities" -type f -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')"

    cat <<EOF
[stage 2] read core
  sage_framework=$fw
  workflows_to_load=$wf_count
  skills_available=$skill_count
  preset=$PRESET
EOF
}

# ------------------------------------------------------------------
# Stages 3-9a — STUBS (T1.11-T1.15 will fold them in)
# ------------------------------------------------------------------

stage_3_agents_md() {
    local fw="${SAGE_FRAMEWORK:-}"
    if [ -z "$fw" ] || [ ! -d "$fw" ]; then
        printf 'generate-codex: SAGE_FRAMEWORK not set or not a directory (%s)\n' "$fw" >&2
        return 1
    fi
    compose_agents_md "$TARGET" "$PRESET" "$fw"
}
stage_4_config_toml() {
    local fw="${SAGE_FRAMEWORK:-}"
    if [ -z "$fw" ] || [ ! -d "$fw" ]; then
        printf 'generate-codex: SAGE_FRAMEWORK not set or not a directory (%s)\n' "$fw" >&2
        return 1
    fi
    compose_config_toml "$TARGET" "$PRESET" "$fw"
}
stage_5_hooks_json() {
    compose_hooks_json "$TARGET"
}

stage_6_deploy_hooks() {
    local fw="${SAGE_FRAMEWORK:-}"
    if [ -z "$fw" ] || [ ! -d "$fw" ]; then
        printf 'generate-codex: SAGE_FRAMEWORK not set or not a directory (%s)\n' "$fw" >&2
        return 1
    fi
    deploy_hooks "$TARGET" "$fw"
}
stage_7_deploy_skills() {
    local fw="${SAGE_FRAMEWORK:-}"
    if [ -z "$fw" ] || [ ! -d "$fw" ]; then
        printf 'generate-codex: SAGE_FRAMEWORK not set or not a directory (%s)\n' "$fw" >&2
        return 1
    fi
    deploy_skills "$TARGET" "$fw"
}
stage_9_bootstrap_sage() {
    bootstrap_sage "$TARGET" "$PRESET"
}
stage_9a_gates_scripts() {
    local fw="${SAGE_FRAMEWORK:-}"
    if [ -z "$fw" ] || [ ! -d "$fw" ]; then
        printf 'generate-codex: SAGE_FRAMEWORK not set or not a directory (%s)\n' "$fw" >&2
        return 1
    fi
    deploy_gates "$TARGET" "$fw"
}

# ------------------------------------------------------------------
# Stage 10 — Verify wiring + emit summary
# ------------------------------------------------------------------

stage_10_sanity_sweep() {
    local fail=0
    local msg=""

    # Check 1: AGENTS.md exists, non-empty, has the compact Sage kernel.
    if [ ! -s "$TARGET/AGENTS.md" ]; then
        msg+="$msg
  - AGENTS.md missing or empty"
        fail=1
    else
        if ! grep -q '^## Operating Kernel' "$TARGET/AGENTS.md"; then
            msg+="
  - AGENTS.md has no operating kernel block"
            fail=1
        fi
        # SAGE-MANAGED-END marker (prefix-managed pattern).
        if ! grep -q 'SAGE-MANAGED-END' "$TARGET/AGENTS.md"; then
            msg+="
  - AGENTS.md missing SAGE-MANAGED-END marker"
            fail=1
        fi
    fi

    # Check 2: Rule 1A keeps Sage Memory discovery before filesystem fallback.
    # Anchor the [[mcp_servers]] match to start-of-line to avoid matching
    # the comment ("# v1 ships NO [[mcp_servers]] block...") in the
    # generated config.toml — TOML table headers must be on their own line.
    if [ -f "$TARGET/.codex/config.toml" ] && [ -f "$TARGET/AGENTS.md" ]; then
        if ! grep -qE '^[[:space:]]*\[\[mcp_servers\]\]' "$TARGET/.codex/config.toml" 2>/dev/null; then
            if ! grep -q 'Discover available Sage Memory tools' "$TARGET/AGENTS.md" || \
               ! grep -q 'Fall back to `.sage-memory/` files only when MCP tools are unavailable' "$TARGET/AGENTS.md"; then
                msg+="
  - AGENTS.md missing Sage Memory discovery/fallback Rule 1A wording"
                fail=1
            fi
        fi
    fi

    # Check 3: config.toml parses as TOML (best-effort: presence + readable).
    if [ ! -f "$TARGET/.codex/config.toml" ]; then
        msg+="
  - .codex/config.toml missing"
        fail=1
    elif command -v yq >/dev/null 2>&1; then
        # yq with -p toml validates; fall back to readability check.
        if ! yq -p toml eval '.' "$TARGET/.codex/config.toml" >/dev/null 2>&1; then
            # Some yq builds lack -p toml; accept readability if so.
            if ! [ -r "$TARGET/.codex/config.toml" ]; then
                msg+="
  - .codex/config.toml unreadable"
                fail=1
            fi
        fi
    fi

    # Check 4: hooks.json parses as JSON.
    if [ ! -f "$TARGET/.codex/hooks.json" ]; then
        msg+="
  - .codex/hooks.json missing"
        fail=1
    elif command -v jq >/dev/null 2>&1; then
        if ! jq -e . "$TARGET/.codex/hooks.json" >/dev/null 2>&1; then
            msg+="
  - .codex/hooks.json invalid JSON"
            fail=1
        fi
    fi

    # Check 5: 4 hook scripts executable.
    local hook
    for hook in session-init pre-tool-validate post-tool-check turn-audit; do
        local p="$TARGET/.codex/hooks/$hook.sh"
        if [ ! -x "$p" ]; then
            msg+="
  - hook not executable: .codex/hooks/$hook.sh"
            fail=1
        fi
    done

    # Check 6 (closes B2): gates scripts executable + count matches preset.
    # Tightened in T1.16: when source preset has gate scripts, target
    # MUST have them (matching count, all executable). Empty source dir
    # → info message, ok (per spec §4 Stage 9a empty-preset branch).
    local _src_gate_count=0
    local _tgt_gate_count=0
    local fw="${SAGE_FRAMEWORK:-}"
    if [ -n "$fw" ] && [ -d "$fw/core/gates/scripts" ]; then
        _src_gate_count="$(find "$fw/core/gates/scripts" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
    fi
    if [ -d "$TARGET/.sage/gates/scripts" ]; then
        _tgt_gate_count="$(find "$TARGET/.sage/gates/scripts" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
    fi

    if [ "$_src_gate_count" -gt 0 ]; then
        if [ "$_tgt_gate_count" -eq 0 ]; then
            msg+="
  - gates scripts missing in target (.sage/gates/scripts/) — src has $_src_gate_count, tgt has 0"
            fail=1
        elif [ "$_src_gate_count" != "$_tgt_gate_count" ]; then
            msg+="
  - gates scripts count mismatch (src=$_src_gate_count, tgt=$_tgt_gate_count)"
            fail=1
        else
            local g
            while IFS= read -r g; do
                [ -n "$g" ] || continue
                [ -x "$g" ] || { msg+="
  - gate not executable: $g"; fail=1; }
            done < <(find "$TARGET/.sage/gates/scripts" -maxdepth 1 -type f -name '*.sh' 2>/dev/null)
        fi
    else
        echo "[sage] no gate scripts configured for preset $PRESET — skipping gates check"
    fi

    # Check 7 (closes B3): .sage/constitution.md has parseable extends:.
    if [ ! -f "$TARGET/.sage/constitution.md" ]; then
        msg+="
  - .sage/constitution.md missing"
        fail=1
    else
        if ! grep -qE '^extends:[[:space:]]*' "$TARGET/.sage/constitution.md"; then
            msg+="
  - .sage/constitution.md missing 'extends:' frontmatter field"
            fail=1
        fi
    fi

    if [ "$fail" -ne 0 ]; then
        printf 'generate-codex: stage 10 sanity sweep FAILED:%s\n' "$msg" >&2
        # shellcheck disable=SC2016
        printf '\nTo fix: re-run `bin/sage init` (or `bin/sage update`) and inspect output.\n' >&2
        return 2
    fi

    # ── Summary table (PASSED branch) ────────────────────────────────
    local _skill_count=0
    if [ -d "$TARGET/.agents/skills" ]; then
        _skill_count="$(find "$TARGET/.agents/skills" -mindepth 2 -maxdepth 2 -type f -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')"
    fi

    cat <<EOF
[stage 10] sanity sweep PASSED

  Deployed summary:
    AGENTS.md           ✓ (Rule 1A v1 filesystem variant)
    .codex/config.toml  ✓ (managed block, codex_hooks=true)
    .codex/hooks.json   ✓ (4 events: SessionStart, PreToolUse, PostToolUse, Stop)
    .codex/hooks/       ✓ (4 hook scripts, mode 0755)
    .agents/skills/     ✓ (${_skill_count} skill loaders)
    .sage/gates/scripts ✓ (${_tgt_gate_count}/${_src_gate_count} gates)
    .sage/constitution  ✓ (preset=${PRESET})
EOF
    return 0
}

# ------------------------------------------------------------------
# Driver
# ------------------------------------------------------------------

run_stage() {
    case "$1" in
        1)   stage_1_discover ;;
        2)   stage_2_read_core ;;
        3)   stage_3_agents_md ;;
        4)   stage_4_config_toml ;;
        5)   stage_5_hooks_json ;;
        6)   stage_6_deploy_hooks ;;
        7)   stage_7_deploy_skills ;;
        9)   stage_9_bootstrap_sage ;;
        9a)  stage_9a_gates_scripts ;;
        10)  stage_10_sanity_sweep ;;
        *)   die "unknown stage: $1 (valid: 1..7, 9, 9a, 10)" ;;
    esac
}

if [ "$STAGE" = "all" ]; then
    stage_1_discover
    stage_2_read_core || exit 1
    stage_3_agents_md
    stage_4_config_toml
    stage_5_hooks_json
    stage_6_deploy_hooks
    stage_7_deploy_skills
    stage_9_bootstrap_sage
    stage_9a_gates_scripts
    stage_10_sanity_sweep
    exit $?
else
    run_stage "$STAGE"
    exit $?
fi
