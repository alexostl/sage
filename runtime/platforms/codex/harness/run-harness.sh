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

read_json_or_key_value_log() {
    local file="${1:?log file required}"
    local start_line="${2:-1}"
    local tmp
    tmp="$(mktemp)"
    if [ -f "$file" ]; then
        tail -n +"$start_line" "$file" > "$tmp"
    fi

    if jq -sc '.' "$tmp" >/dev/null 2>&1; then
        jq -sc '.' "$tmp"
        rm -f "$tmp"
        return
    fi

    awk -F'|' -v source_file="$file" '
        function emit_entry() {
            if (kind != "") {
                print kind "\t" severity
            }
            kind = ""
            severity = ""
        }
        {
            if ($0 ~ /^#{2,3} /) {
                emit_entry()
                heading = tolower($0)
                if (source_file ~ /\.auto-fixes\.log$/ || heading ~ /safe/ || heading ~ /auto-fix/ || heading ~ /scope repair/ || heading ~ /scope update/) {
                    kind = "safe_auto_fix"
                }
                next
            }
            if (kind != "" && $0 ~ /^-?[[:space:]]*Severity:/) {
                severity = $0
                sub(/^-?[[:space:]]*Severity:[[:space:]]*/, "", severity)
                next
            }
            pipe_kind = ""
            pipe_severity = ""
            for (i = 1; i <= NF; i++) {
                part = $i
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", part)
                if (part ~ /^kind=/) {
                    pipe_kind = substr(part, 6)
                }
                if (part ~ /^severity=/) {
                    pipe_severity = substr(part, 10)
                }
            }
            if (pipe_kind != "") {
                emit_entry()
                kind = pipe_kind
                severity = pipe_severity
                emit_entry()
            }
        }
        END { emit_entry() }
    ' "$tmp" | jq -Rsc '
        split("\n")
        | map(select(length > 0) | split("\t") | {kind: .[0], severity: (.[1] // "")})
    '
    rm -f "$tmp"
}

if [ "${HARNESS_TEST_READ_LOG:-}" = "1" ]; then
    read_json_or_key_value_log "${1:?log file required}" "${2:-1}"
    exit 0
fi

OUT_DIR="${HARNESS_OUT:-$(mktemp -d -t codex-harness.XXXXXX)}"
TARGET="$OUT_DIR/target"
TRANSCRIPTS="$OUT_DIR/transcripts"
HARNESS_MODEL="${HARNESS_MODEL:-gpt-5.4}"
HARNESS_REASONING="${HARNESS_REASONING:-medium}"
HARNESS_TARGET_MODE="${HARNESS_TARGET_MODE:-dummy-project}"
mkdir -p "$TARGET" "$TRANSCRIPTS"

case "$HARNESS_MODEL" in
    gpt-5.5|*gpt-5.5*)
        echo "ERROR: HARNESS_MODEL must not be gpt-5.5 for this extensive harness." >&2
        exit 2 ;;
esac

echo "==> Harness output: $OUT_DIR"
echo "==> Target dir:     $TARGET"
echo "==> Target mode:    $HARNESS_TARGET_MODE"
echo "==> Model profile:  $HARNESS_MODEL / reasoning=$HARNESS_REASONING"

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

# Codex 0.126.0-alpha.15 requires [history].persistence in config.toml
# for `codex exec` to start cleanly. The generator already emits this,
# but defensive guard for the harness.
if ! grep -q '\[history\]' "$TARGET/.codex/config.toml" 2>/dev/null; then
    cat >> "$TARGET/.codex/config.toml" <<'EOF'

[history]
persistence = "save-all"
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
prompt_total="$(find "$HARNESS_DIR/prompts" -maxdepth 1 -type f -name '*.txt' | wc -l | tr -d ' ')"
for prompt_file in "$HARNESS_DIR"/prompts/*.txt; do
    [ -f "$prompt_file" ] || continue
    prompt_idx=$((prompt_idx + 1))
    name="$(basename "$prompt_file" .txt)"
    out="$TRANSCRIPTS/$name.jsonl"

    prompt_text="$(cat "$prompt_file")"
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
    if codex exec --json --enable codex_hooks --skip-git-repo-check --ephemeral \
        --dangerously-bypass-approvals-and-sandbox \
        -m "$HARNESS_MODEL" -c "model_reasoning_effort=\"$HARNESS_REASONING\"" \
        -c 'service_tier="fast"' \
        -c "projects.\"$TARGET\".trust_level=\"trusted\"" \
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
    changed_files_json="$(cd "$TARGET" && git status --porcelain -uall 2>/dev/null | sed 's#^...##' | sort -u | jq -R . | jq -sc .)"
    incidents_json='[]'
    if [ -f "$TARGET/.sage/.mcp-incidents.log" ]; then
        incidents_json="$(read_json_or_key_value_log "$TARGET/.sage/.mcp-incidents.log" "$((before_incident_lines + 1))")"
    fi
    auto_fixes_json='[]'
    if [ -f "$TARGET/.sage/.auto-fixes.log" ]; then
        auto_fixes_json="$(read_json_or_key_value_log "$TARGET/.sage/.auto-fixes.log" "$((before_auto_fix_lines + 1))")"
    fi
    jq -n \
        --arg prompt "$name" \
        --arg model "$HARNESS_MODEL" \
        --arg reasoning "$HARNESS_REASONING" \
        --arg mode "$HARNESS_TARGET_MODE" \
        --argjson exit_code "$rc" \
        --argjson files "$files_json" \
        --argjson manifests "$manifests_json" \
        --argjson new_manifests "$new_manifests_json" \
        --argjson changed_files "$changed_files_json" \
        --argjson incidents "$incidents_json" \
        --argjson auto_fixes "$auto_fixes_json" \
        '{prompt:$prompt, model:$model, reasoning_effort:$reasoning, target_mode:$mode, exit_code:$exit_code, files:$files, manifests:$manifests, new_manifests:$new_manifests, changed_files:$changed_files, incidents:$incidents, auto_fixes:$auto_fixes}' \
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
