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

OUT_DIR="${HARNESS_OUT:-$(mktemp -d -t codex-harness.XXXXXX)}"
TARGET="$OUT_DIR/target"
TRANSCRIPTS="$OUT_DIR/transcripts"
mkdir -p "$TARGET" "$TRANSCRIPTS"

echo "==> Harness output: $OUT_DIR"
echo "==> Target dir:     $TARGET"

# --- Step 1: init target -------------------------------------------
(
    cd "$TARGET" || exit 1
    git init -q -b main
    git config user.email "harness@sage.local"
    git config user.name "harness"
    echo "harness seed" > README.md
    git add README.md
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
for prompt_file in "$HARNESS_DIR"/prompts/*.txt; do
    [ -f "$prompt_file" ] || continue
    prompt_idx=$((prompt_idx + 1))
    name="$(basename "$prompt_file" .txt)"
    out="$TRANSCRIPTS/$name.jsonl"

    prompt_text="$(cat "$prompt_file")"
    echo "==> [${prompt_idx}/5] $name"
    echo "    prompt: $prompt_text"

    # codex exec --json: non-interactive JSON-line transcript.
    # --skip-git-repo-check + --ephemeral + --dangerously-bypass-... per
    # ADR-9 / cycle test setup; -C runs in target dir.
    # < /dev/null closes stdin (codex hangs on shell-special chars).
    if codex exec --json --skip-git-repo-check --ephemeral \
        --dangerously-bypass-approvals-and-sandbox \
        -C "$TARGET" "$prompt_text" > "$out" 2> "$out.stderr" < /dev/null; then
        echo "    transcript: $(wc -l < "$out" | tr -d ' ') events"
    else
        echo "    WARN: codex exec returned non-zero — see $out.stderr" >&2
    fi

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
