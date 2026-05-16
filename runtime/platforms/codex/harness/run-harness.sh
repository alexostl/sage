#!/usr/bin/env bash
# run-harness.sh — Codex outcome harness seed (v1).
#
# What it does (per plan T2.7 + spec §13.2):
#   1. Creates a fresh git-init target dir.
#   2. Runs `bin/sage init --platform codex --preset base` on it.
#   3. For each prompt in prompts/, runs `codex exec --json` non-
#      interactively, captures the JSONL transcript.
#   4. Invokes lib/aggregate-signals.sh against the target +
#      transcripts to produce the §13.2 signal report.
#   5. Writes the report JSON to <out-dir>/report.json.
#
# Output dir defaults to a tempdir under $TMPDIR. Override with
# HARNESS_OUT=<path>. Target dir = <out-dir>/target.
# Real-agent profile defaults to gpt-5.4 medium. gpt-5.5 is refused because
# this harness is intentionally extensive and cost-sensitive.
#
# Runnable autonomously by Claude Code (Round 2 C5 hard gate).
#
# v1 plan ref: T2.7 (M2 Group).

set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$HARNESS_DIR/../../../.." && pwd)"
SAGE_BIN="$FRAMEWORK_ROOT/bin/sage"

# shellcheck source=runtime/platforms/codex/harness/lib/log-parser.sh
source "$HARNESS_DIR/lib/log-parser.sh"

if [ "${HARNESS_TEST_READ_LOG:-}" = "1" ]; then
    read_json_or_key_value_log "${1:?log path required}" "${2:-1}"
    exit 0
fi

# Pre-flight: tools we need.
for cmd in jq codex git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: $cmd not on PATH — harness cannot run." >&2
        exit 1
    fi
done
[ -x "$SAGE_BIN" ] || { echo "ERROR: bin/sage not executable at $SAGE_BIN" >&2; exit 1; }

log_line_count() {
    local file="${1:?log file required}"
    if [ -f "$file" ]; then
        wc -l < "$file" | tr -d ' '
    else
        printf '0\n'
    fi
}

OUT_DIR="${HARNESS_OUT:-$(mktemp -d -t codex-harness.XXXXXX)}"
TARGET="$OUT_DIR/target"
SECONDARY_TARGET="$OUT_DIR/secondary-target"
TRANSCRIPTS="$OUT_DIR/transcripts"
HARNESS_MODEL="${HARNESS_MODEL:-gpt-5.4}"
HARNESS_REASONING="${HARNESS_REASONING:-medium}"
HARNESS_TARGET_MODE="${HARNESS_TARGET_MODE:-dummy-project}"
HARNESS_SCENARIOS="${HARNESS_SCENARIOS:-}"
HARNESS_HOOK_MODE="${HARNESS_HOOK_MODE:-on}"
HARNESS_SERVICE_TIER="${HARNESS_SERVICE_TIER:-}"
HARNESS_CODEX_HOME="${HARNESS_CODEX_HOME:-$(mktemp -d -t codex-harness-home.XXXXXX)}"
SCENARIO_MANIFEST="$HARNESS_DIR/v11-scenarios.json"
mkdir -p "$TARGET" "$TRANSCRIPTS" "$HARNESS_CODEX_HOME"
if [ -f "$HOME/.codex/auth.json" ] && [ ! -f "$HARNESS_CODEX_HOME/auth.json" ]; then
    cp "$HOME/.codex/auth.json" "$HARNESS_CODEX_HOME/auth.json"
    chmod 0600 "$HARNESS_CODEX_HOME/auth.json" 2>/dev/null || true
fi
if [ -f "$HOME/.codex/installation_id" ] && [ ! -f "$HARNESS_CODEX_HOME/installation_id" ]; then
    cp "$HOME/.codex/installation_id" "$HARNESS_CODEX_HOME/installation_id"
fi

case "$HARNESS_MODEL" in
    gpt-5.5|*gpt-5.5*)
        echo "ERROR: HARNESS_MODEL must not be gpt-5.5 for this extensive harness." >&2
        exit 2 ;;
esac
case "$HARNESS_HOOK_MODE" in
    on|off) ;;
    *)
        echo "ERROR: HARNESS_HOOK_MODE must be one of: on, off" >&2
        exit 2 ;;
esac

list_available_prompts() {
    for prompt_file in "$HARNESS_DIR"/prompts/*.txt; do
        [ -f "$prompt_file" ] || continue
        basename "$prompt_file" .txt
    done | sort
}

resolve_prompt_selector() {
    local selector="${1:?selector required}"
    local prompt

    selector="$(printf '%s' "$selector" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    selector="${selector%.txt}"
    [ -n "$selector" ] || return 1

    if [ -f "$HARNESS_DIR/prompts/$selector.txt" ]; then
        printf '%s\n' "$HARNESS_DIR/prompts/$selector.txt"
        return 0
    fi

    if [ -f "$SCENARIO_MANIFEST" ]; then
        prompt="$(jq -r --arg id "$selector" '.scenarios[]? | select(.id == $id) | .prompt' "$SCENARIO_MANIFEST" | head -1)"
        if [ -n "$prompt" ] && [ "$prompt" != "null" ] && [ -f "$HARNESS_DIR/prompts/$prompt" ]; then
            printf '%s\n' "$HARNESS_DIR/prompts/$prompt"
            return 0
        fi
    fi

    return 1
}

append_prompt_file() {
    local prompt_path="${1:?prompt path required}"
    local existing

    if [ "${#PROMPT_FILES[@]}" -gt 0 ]; then
        for existing in "${PROMPT_FILES[@]}"; do
            [ "$existing" = "$prompt_path" ] && return 0
        done
    fi
    PROMPT_FILES+=("$prompt_path")
}

selected_prompts_need_secondary_target() {
    local prompt_path
    for prompt_path in "${PROMPT_FILES[@]}"; do
        [ -f "$prompt_path" ] || continue
        if grep -q '__HARNESS_SECONDARY_TARGET__' "$prompt_path"; then
            return 0
        fi
    done
    return 1
}

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

apply_prompt_fixture() {
    local name="${1:?prompt name required}"

    case "$name" in
        16-closed-cycle-explicit-reopen)
            mkdir -p "$TARGET/.sage/work/20260515-closed-hook-study"
            cat > "$TARGET/.sage/work/20260515-closed-hook-study/manifest.md" <<'EOF'
---
cycle_id: 20260515-closed-hook-study
workflow: architect
phase: closed
status: closed
resolution: shipped
created: 2026-05-15
scope:
  - .sage/work/20260515-closed-hook-study/**
---

# Closed Hook Study

## Closeout

This fixture is intentionally marked closed before the prompt begins.
EOF
            (
                cd "$TARGET" || exit 1
                git add .sage/work/20260515-closed-hook-study/manifest.md
                git commit -q -m "harness fixture: closed cycle" >/dev/null 2>&1 || true
            ) || true
            ;;
        17-local-gitignored-config-artifact)
            if ! grep -qxF ".sage-local/" "$TARGET/.gitignore" 2>/dev/null; then
                printf '\n.sage-local/\n' >> "$TARGET/.gitignore"
                (
                    cd "$TARGET" || exit 1
                    git add .gitignore
                    git commit -q -m "harness fixture: local sage ignore" >/dev/null 2>&1 || true
                ) || true
            fi
            ;;
        18-surgical-edit-quantitative)
            cat > "$TARGET/README.md" <<'EOF'
# Dummy Project

Smol realistic project for Sage/Codex harness runs.
EOF
            (
                cd "$TARGET" || exit 1
                git add README.md
                git commit -q -m "harness fixture: surgical typo" >/dev/null 2>&1 || true
            ) || true
            ;;
    esac
}

declare -a PROMPT_FILES
if [ -n "$HARNESS_SCENARIOS" ]; then
    while IFS= read -r raw_selector; do
        selector="$(printf '%s' "$raw_selector" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [ -n "$selector" ] || continue
        if ! prompt_path="$(resolve_prompt_selector "$selector")"; then
            echo "ERROR: unknown HARNESS_SCENARIOS selector: $selector" >&2
            echo "Available scenarios:" >&2
            list_available_prompts >&2
            exit 2
        fi
        append_prompt_file "$prompt_path"
    done < <(printf '%s\n' "$HARNESS_SCENARIOS" | tr ',' '\n' | tr '[:space:]' '\n')
else
    while IFS= read -r prompt_file; do
        [ -n "$prompt_file" ] || continue
        PROMPT_FILES+=("$prompt_file")
    done < <(find "$HARNESS_DIR/prompts" -maxdepth 1 -type f -name '*.txt' | sort)
fi
[ "${#PROMPT_FILES[@]}" -gt 0 ] || {
    echo "ERROR: no harness prompts selected." >&2
    exit 2
}
if selected_prompts_need_secondary_target; then
    HARNESS_NEEDS_SECONDARY_TARGET=1
else
    HARNESS_NEEDS_SECONDARY_TARGET=0
fi
if [ -n "$HARNESS_SCENARIOS" ]; then
    HARNESS_RUN_MODE="targeted"
else
    HARNESS_RUN_MODE="full"
fi
if [ "${HARNESS_LIST_PROMPTS_ONLY:-}" = "1" ]; then
    for prompt_file in "${PROMPT_FILES[@]}"; do
        basename "$prompt_file" .txt
    done
    exit 0
fi

echo "==> Harness output: $OUT_DIR"
echo "==> Target dir:     $TARGET"
if [ "$HARNESS_NEEDS_SECONDARY_TARGET" = "1" ]; then
    echo "==> Secondary dir:  $SECONDARY_TARGET"
fi
echo "==> Target mode:    $HARNESS_TARGET_MODE"
echo "==> Model profile:  $HARNESS_MODEL / reasoning=$HARNESS_REASONING"
echo "==> Hook mode:      $HARNESS_HOOK_MODE"
echo "==> Run mode:       $HARNESS_RUN_MODE (${#PROMPT_FILES[@]} prompts)"
echo "==> Codex home:     $HARNESS_CODEX_HOME"
if [ -n "$HARNESS_SERVICE_TIER" ]; then
    echo "==> Service tier:   $HARNESS_SERVICE_TIER"
else
    echo "==> Service tier:   unset"
fi

# --- Step 1: init target -------------------------------------------
(
    cd "$TARGET" || exit 1
    git init -q -b main
    git config user.email "harness@sage.local"
    git config user.name "harness"
    if [ "$HARNESS_TARGET_MODE" = "dummy-project" ]; then
        mkdir -p src tests docs
        cat > README.md <<'EOF'
# Dummy Project

Small realistic project for Sage/Codex harness runs.
EOF
        cat > package.json <<'EOF'
{"scripts":{"test":"node tests/smoke.test.js"},"dependencies":{},"devDependencies":{}}
EOF
        cat > src/todo-store.js <<'EOF'
export function normalizeTitle(title) {
  return String(title || "").trim().replace(/\s+/g, " ");
}
EOF
        cat > tests/smoke.test.js <<'EOF'
import assert from "node:assert/strict";
import { normalizeTitle } from "../src/todo-store.js";

assert.equal(normalizeTitle("  pay   invoice "), "pay invoice");
EOF
        cat > docs/architecture.md <<'EOF'
# Architecture

The app has a tiny domain module and a smoke test so agent changes have real files.
EOF
    else
        echo "harness seed" > README.md
    fi
    git add -A
    git commit -q -m "seed"
) || { echo "ERROR: git init failed" >&2; exit 1; }

echo "==> Running bin/sage init --platform codex --preset base..."
# bin/sage uses cwd as the target — must cd into target first. The
# self-host detection (line ~899) refuses to init inside the framework
# repo unless SELF_HOST_FLAG=true, so running from the harness target
# is the correct mode.
( cd "$TARGET" && "$SAGE_BIN" init --platform codex --preset base ) \
    >"$OUT_DIR/sage-init.log" 2>&1 || {
    echo "ERROR: bin/sage init failed — see $OUT_DIR/sage-init.log" >&2
    tail -20 "$OUT_DIR/sage-init.log" >&2
    exit 1
}

if [ "$HARNESS_NEEDS_SECONDARY_TARGET" = "1" ]; then
    mkdir -p "$SECONDARY_TARGET"
    (
        cd "$SECONDARY_TARGET" || exit 1
        git init -q -b main
        git config user.email "harness@sage.local"
        git config user.name "harness"
        mkdir -p docs
        cat > README.md <<'EOF'
# Secondary Target

Separate realistic target repository for cross-repo Sage ownership checks.
EOF
        git add -A
        git commit -q -m "seed"
    ) || { echo "ERROR: secondary git init failed" >&2; exit 1; }
    ( cd "$SECONDARY_TARGET" && "$SAGE_BIN" init --platform codex --preset base ) \
        >"$OUT_DIR/sage-init-secondary.log" 2>&1 || {
        echo "ERROR: secondary bin/sage init failed — see $OUT_DIR/sage-init-secondary.log" >&2
        tail -20 "$OUT_DIR/sage-init-secondary.log" >&2
        exit 1
    }
    (
        cd "$SECONDARY_TARGET" || exit 1
        git add -A
        git commit -q -m "sage init: codex platform" >/dev/null 2>&1 || true
    ) || true
fi

# Codex 0.126.0-alpha.15 requires [history].persistence in config.toml
# for `codex exec` to start cleanly. The generator already emits this,
# but defensive guard for the harness.
if ! grep -q '\[history\]' "$TARGET/.codex/config.toml" 2>/dev/null; then
    cat >> "$TARGET/.codex/config.toml" <<'EOF'

[history]
persistence = "save-all"
EOF
fi

if [ "$HARNESS_HOOK_MODE" = "off" ]; then
    echo "==> Disabling project-local hooks inside isolated target..."
    tmp_config="$(mktemp)"
    sed 's/^\([[:space:]]*hooks[[:space:]]*=[[:space:]]*\)true[[:space:]]*$/\1false/' \
        "$TARGET/.codex/config.toml" > "$tmp_config"
    mv "$tmp_config" "$TARGET/.codex/config.toml"
    cat > "$TARGET/.codex/hooks.json" <<'EOF'
{
  "hooks": {}
}
EOF
fi

# Commit the freshly-initialized framework so commits-during-codex
# are visible to signal 7 + 8 (otherwise everything looks like one
# initial commit and signals 7/8 measure nothing).
(
    cd "$TARGET" || exit 1
    git add -A
    git commit -q -m "sage init: codex platform" >/dev/null 2>&1 || true
) || true

# --- Step 2: run codex exec on each prompt -------------------------
prompt_idx=0
prompt_total="${#PROMPT_FILES[@]}"
codex_config_args=(-c "model_reasoning_effort=\"$HARNESS_REASONING\"")
if [ -n "$HARNESS_SERVICE_TIER" ]; then
    codex_config_args+=(-c "service_tier=\"$HARNESS_SERVICE_TIER\"")
fi
codex_config_args+=(-c "projects.\"$TARGET\".trust_level=\"trusted\"")
for prompt_file in "${PROMPT_FILES[@]}"; do
    [ -f "$prompt_file" ] || continue
    prompt_idx=$((prompt_idx + 1))
    name="$(basename "$prompt_file" .txt)"
    out="$TRANSCRIPTS/$name.jsonl"

    apply_prompt_fixture "$name"
    primary_target_escaped="$(escape_sed_replacement "$TARGET")"
    secondary_target_escaped="$(escape_sed_replacement "$SECONDARY_TARGET")"
    prompt_text="$(sed \
        -e "s#__HARNESS_PRIMARY_TARGET__#$primary_target_escaped#g" \
        -e "s#__HARNESS_SECONDARY_TARGET__#$secondary_target_escaped#g" \
        "$prompt_file")"
    echo "==> [${prompt_idx}/${prompt_total}] $name"
    echo "    prompt: $prompt_text"

    before_incident_lines="$(log_line_count "$TARGET/.sage/.mcp-incidents.log")"
    before_auto_fix_lines="$(log_line_count "$TARGET/.sage/.auto-fixes.log")"
    before_manifests_json="$(cd "$TARGET" && find .sage/work -mindepth 2 -maxdepth 2 -name manifest.md -type f 2>/dev/null | sed 's#^\./##' | sort | jq -R . | jq -sc .)"

    # codex exec --json: non-interactive JSON-line transcript.
    # CLI 0.126 still needs the legacy feature gate for project-local hooks,
    # while generated Desktop config uses [features].hooks. Keep this
    # compatibility shim in the harness so release evidence exercises hooks.
    # --skip-git-repo-check + --ephemeral + --dangerously-bypass-... per
    # ADR-9 / cycle test setup; -C runs in target dir.
    # < /dev/null closes stdin (codex hangs on shell-special chars).
    if [ "$HARNESS_HOOK_MODE" = "on" ]; then
        codex_exec_cmd=(codex exec --json --enable codex_hooks)
    else
        codex_exec_cmd=(codex exec --json)
    fi
    if CODEX_HOME="$HARNESS_CODEX_HOME" "${codex_exec_cmd[@]}" --skip-git-repo-check --ephemeral \
        --dangerously-bypass-approvals-and-sandbox \
        -m "$HARNESS_MODEL" "${codex_config_args[@]}" \
        -C "$TARGET" "$prompt_text" > "$out" 2> "$out.stderr" < /dev/null; then
        rc=0
        printf '0\n' > "$out.exit"
        echo "    transcript: $(wc -l < "$out" | tr -d ' ') events"
    else
        rc=$?
        printf '%s\n' "$rc" > "$out.exit"
        echo "    WARN: codex exec returned non-zero — see $out.stderr" >&2
    fi

    files_json="$(cd "$TARGET" && find . -type f ! -path './.git/*' | sed 's#^\./##' | sort | jq -R . | jq -sc .)"
    manifests_json="$(cd "$TARGET" && find .sage/work -mindepth 2 -maxdepth 2 -name manifest.md -type f 2>/dev/null | sed 's#^\./##' | sort | jq -R . | jq -sc .)"
    new_manifests_json="$(jq -nc --argjson before "$before_manifests_json" --argjson after "$manifests_json" '$after - $before')"
    changed_files_json="$(cd "$TARGET" && git status --porcelain -uall 2>/dev/null | sed 's#^...##' | awk '
        $0 !~ /^\.sage\/\.(session-baseline|session-mutations|mcp-incidents|auto-fixes)\.log$/
    ' | sort -u | jq -R . | jq -sc .)"
    changed_lines_total="$(cd "$TARGET" && git diff --numstat 2>/dev/null | awk '
        $3 ~ /^\.sage\/\.(session-baseline|session-mutations|mcp-incidents|auto-fixes)\.log$/ { next }
        $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ { total += $1 + $2 }
        END { print total + 0 }
    ')"
    incidents_json='[]'
    if [ -f "$TARGET/.sage/.mcp-incidents.log" ]; then
        incidents_json="$(read_json_or_key_value_log "$TARGET/.sage/.mcp-incidents.log" "$((before_incident_lines + 1))")"
    fi
    auto_fixes_json='[]'
    if [ -f "$TARGET/.sage/.auto-fixes.log" ]; then
        auto_fixes_json="$(read_json_or_key_value_log "$TARGET/.sage/.auto-fixes.log" "$((before_auto_fix_lines + 1))")"
    fi
    secondary_files_json='[]'
    secondary_changed_files_json='[]'
    if [ "$HARNESS_NEEDS_SECONDARY_TARGET" = "1" ] && [ -d "$SECONDARY_TARGET/.git" ]; then
        secondary_files_json="$(cd "$SECONDARY_TARGET" && find . -type f ! -path './.git/*' | sed 's#^\./##' | sort | jq -R . | jq -sc .)"
        secondary_changed_files_json="$(cd "$SECONDARY_TARGET" && git status --porcelain -uall 2>/dev/null | sed 's#^...##' | sort -u | jq -R . | jq -sc .)"
    fi
    jq -n \
        --arg prompt "$name" \
        --arg model "$HARNESS_MODEL" \
        --arg reasoning "$HARNESS_REASONING" \
        --arg mode "$HARNESS_TARGET_MODE" \
        --arg run_mode "$HARNESS_RUN_MODE" \
        --arg hook_mode "$HARNESS_HOOK_MODE" \
        --arg service_tier "${HARNESS_SERVICE_TIER:-unset}" \
        --argjson exit_code "$rc" \
        --argjson files "$files_json" \
        --argjson manifests "$manifests_json" \
        --argjson new_manifests "$new_manifests_json" \
        --argjson changed_files "$changed_files_json" \
        --argjson changed_lines_total "$changed_lines_total" \
        --arg secondary_target "$SECONDARY_TARGET" \
        --argjson secondary_files "$secondary_files_json" \
        --argjson secondary_changed_files "$secondary_changed_files_json" \
        --argjson incidents "$incidents_json" \
        --argjson auto_fixes "$auto_fixes_json" \
        '{prompt:$prompt, model:$model, reasoning_effort:$reasoning, target_mode:$mode, run_mode:$run_mode, hook_mode:$hook_mode, service_tier:$service_tier, exit_code:$exit_code, files:$files, manifests:$manifests, new_manifests:$new_manifests, changed_files:$changed_files, changed_lines_total:$changed_lines_total, secondary_target:$secondary_target, secondary_files:$secondary_files, secondary_changed_files:$secondary_changed_files, incidents:$incidents, auto_fixes:$auto_fixes}' \
        > "$out.state.json"

    # Commit each session's porcelain so the NEXT session's Stop hook
    # sees a clean working tree. Without this, prior-session uncommitted
    # mutations show up in the next session's git porcelain → false
    # bypass_mutation incidents (turn-audit's session_id filter only
    # matches the current session's claims). Mimics the realistic pattern
    # where the user commits between Codex sessions.
    (
        cd "$TARGET" || exit 1
        git add -A
        git commit -q -m "harness: $name" >/dev/null 2>&1 || true
    ) || true
    if [ "$HARNESS_NEEDS_SECONDARY_TARGET" = "1" ] && [ -d "$SECONDARY_TARGET/.git" ]; then
        (
            cd "$SECONDARY_TARGET" || exit 1
            git add -A
            git commit -q -m "harness: $name" >/dev/null 2>&1 || true
        ) || true
    fi
done

# --- Step 3: aggregate signals -------------------------------------
echo "==> Aggregating §13.2 signals..."
"$HARNESS_DIR/lib/aggregate-signals.sh" "$TARGET" "$TRANSCRIPTS" "$FRAMEWORK_ROOT" \
    > "$OUT_DIR/report.json"

echo
echo "==> Report: $OUT_DIR/report.json"
jq '.signals | to_entries | map({ key: .key, summary: (.value | del(.description, .note)) })' \
    < "$OUT_DIR/report.json"

echo
echo "==> Full output dir: $OUT_DIR"
