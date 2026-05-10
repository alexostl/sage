#!/usr/bin/env bash
# F-1 Phase 1 — long-cycle workflow runner against real Codex 0.126.
#
# Sequential codex exec calls — files persist in TARGET, so each session
# reads prior turn's state from disk. This is more strict than real
# conversation (no memory between turns) — good for testing whether
# the agent's [A]/[R] discipline holds when it has only file evidence.
#
# Output: $OUT_DIR/{transcripts/T*.jsonl, porcelain-T*.txt,
#         session-mutations-T*.log, doctor-T*.txt, status-T*.txt,
#         report.md}.

set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SAGE_BIN="$FRAMEWORK_ROOT/bin/sage"
QA_DIR="$(cd "$(dirname "$0")" && pwd)"

OUT_DIR="${F1_OUT:-$QA_DIR/run-$(date -u +%Y%m%dT%H%M%S)}"
TARGET="$OUT_DIR/target"
TRANSCRIPTS="$OUT_DIR/transcripts"
EVIDENCE="$OUT_DIR/evidence"
mkdir -p "$TARGET" "$TRANSCRIPTS" "$EVIDENCE"

echo "==> F-1 phase 1 output: $OUT_DIR"

# Pre-flight
for cmd in jq codex git; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd not found"; exit 1; }
done

# --- Init target -----------------------------------------------------
(
    cd "$TARGET" || exit 1
    git init -q -b main
    git config user.email "qa-f1@sage.local"
    git config user.name  "qa-f1"
    echo "qa f1 seed" > README.md
    git add README.md
    git commit -q -m "seed"
) || exit 1

echo "==> bin/sage init --platform codex --preset base"
( cd "$TARGET" && "$SAGE_BIN" init --platform codex --preset base ) \
    >"$OUT_DIR/sage-init.log" 2>&1 || {
    echo "ERROR: bin/sage init failed"; tail -30 "$OUT_DIR/sage-init.log"; exit 1;
}

# History persistence guard (harness pattern).
if ! grep -q '\[history\]' "$TARGET/.codex/config.toml"; then
    printf '\n[history]\npersistence = "save-all"\n' >> "$TARGET/.codex/config.toml"
fi

(
    cd "$TARGET" || exit 1
    git add -A
    git commit -q -m "sage init: codex platform" >/dev/null 2>&1 || true
)

# --- Define prompt chain --------------------------------------------
# 5 turns. Each is an independent codex exec session — files persist
# but conversation does not. The agent must drive [A]/[R] purely from
# file state on disk.
T1='/sage:build I need a small feature: a bash health-check script at scripts/health-check.sh that prints OK and exits 0. This is a Standard scope task — please write a brief and a spec under .sage/work/.'
T2='[A] I approve the spec. Please continue: write the plan now and present it for my next [A].'
T3='[A] I approve the plan. Begin implementation. Write tests first if applicable, then the script. Then present verification for my [A].'
T4='Run the script yourself to verify it works. Report results.'
T5='[A] I approve the verification. Close the cycle: flip plan.md and manifest.md frontmatter status to completed.'

run_turn () {
    local idx="$1" prompt="$2" name="$3"
    local out="$TRANSCRIPTS/T${idx}-${name}.jsonl"
    local err="$out.stderr"

    echo "==> Turn ${idx} (${name})"
    echo "    prompt[1:60]: $(printf '%s' "$prompt" | head -c 60)..."
    local start_ts end_ts
    start_ts="$(date +%s)"
    if codex exec --json --skip-git-repo-check --ephemeral \
        --dangerously-bypass-approvals-and-sandbox \
        -C "$TARGET" "$prompt" > "$out" 2> "$err" < /dev/null; then
        end_ts="$(date +%s)"
        echo "    transcript: $(wc -l < "$out" | tr -d ' ') events, $((end_ts - start_ts))s"
    else
        end_ts="$(date +%s)"
        echo "    WARN rc != 0 — see $err ($((end_ts - start_ts))s)"
    fi

    # Snapshot per-turn evidence BEFORE auto-commit so we can correlate
    # what changed within this turn.
    (
        cd "$TARGET" || exit 1
        git status --porcelain > "$EVIDENCE/T${idx}-porcelain-pre-commit.txt" 2>&1 || true
        if [ -f .sage/.session-mutations.log ]; then
            cp .sage/.session-mutations.log "$EVIDENCE/T${idx}-session-mutations.log"
        fi
        if [ -f .sage/.mcp-incidents.log ]; then
            cp .sage/.mcp-incidents.log "$EVIDENCE/T${idx}-mcp-incidents.log"
        fi
        if [ -d .sage/work ]; then
            ls -la .sage/work/*/ 2>/dev/null > "$EVIDENCE/T${idx}-work-listing.txt" || true
            for f in .sage/work/*/manifest.md .sage/work/*/spec.md .sage/work/*/plan.md .sage/work/*/brief.md; do
                [ -f "$f" ] || continue
                base="$(basename "$(dirname "$f")")-$(basename "$f")"
                head -15 "$f" > "$EVIDENCE/T${idx}-frontmatter-$base.txt"
            done
        fi
    )

    # Per-turn doctor + status snapshot.
    ( cd "$TARGET" && "$SAGE_BIN" doctor > "$EVIDENCE/T${idx}-doctor.txt" 2>&1 ) || true
    ( cd "$TARGET" && "$SAGE_BIN" status > "$EVIDENCE/T${idx}-status.txt" 2>&1 ) || true

    # Commit between turns (harness pattern — clears porcelain).
    (
        cd "$TARGET" || exit 1
        git add -A
        git commit -q -m "qa-f1: T${idx} ${name}" >/dev/null 2>&1 || true
    )
}

run_turn 1 "$T1" "build-trigger"
run_turn 2 "$T2" "spec-approve"
run_turn 3 "$T3" "plan-approve"
run_turn 4 "$T4" "verify"
run_turn 5 "$T5" "close-cycle"

# --- Run harness aggregator over the captured transcripts -----------
echo "==> Aggregating §13.2 signals over F-1 transcripts..."
"$FRAMEWORK_ROOT/runtime/platforms/codex/harness/lib/aggregate-signals.sh" \
    "$TARGET" "$TRANSCRIPTS" "$FRAMEWORK_ROOT" \
    > "$OUT_DIR/signals-report.json" 2>&1 || true

echo
echo "==> Done. Output: $OUT_DIR"
echo "==> Signals: $OUT_DIR/signals-report.json"
echo "==> Evidence: $EVIDENCE/"
