#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Sage SessionStart hook for Codex
#
# Mirrors the richness of the Claude Code session-init hook: scans
# .sage/work/ frontmatter, counts docs, surfaces the 3 most recent
# decisions, and wraps the result in the Codex hook JSON schema
# (hookSpecificOutput.additionalContext).
#
# Zero runtime dependencies beyond bash + python3 (for JSON output).
# Exits silently with no output when .sage/ is absent.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ROOT="${SAGE_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SAGE_DIR="$ROOT/.sage"

if [ ! -d "$SAGE_DIR" ]; then
  exit 0
fi

# ── Scan active work via frontmatter ──
ACTIVE_WORK=""
WORK_COUNT=0
IN_PROGRESS=""
for dir in "$SAGE_DIR"/work/*/; do
  [ -d "$dir" ] || continue
  for artifact in "plan.md" "spec.md" "brief.md"; do
    f="$dir$artifact"
    [ -f "$f" ] || continue

    title=$(sed -n '/^---$/,/^---$/{ /^title:/s/^title: *"*\([^"]*\)"*/\1/p; }' "$f" 2>/dev/null || true)
    status=$(sed -n '/^---$/,/^---$/{ /^status:/s/^status: *//p; }' "$f" 2>/dev/null || true)
    phase=$(sed -n '/^---$/,/^---$/{ /^phase:/s/^phase: *//p; }' "$f" 2>/dev/null || true)

    [ -z "$title" ] && title=$(basename "$dir" | sed 's|/$||')
    [ -z "$status" ] && status="unknown"

    rel_path="${f#"$ROOT/"}"
    ACTIVE_WORK="${ACTIVE_WORK}  - ${title} [${status}, ${phase}] — ${rel_path}"$'\n'
    WORK_COUNT=$((WORK_COUNT + 1))
    [ "$status" = "in-progress" ] && IN_PROGRESS="$title"
    break
  done
done

# ── Scan docs ──
DOC_COUNT=0
for doc in "$SAGE_DIR"/docs/*.md; do
  [ -f "$doc" ] || continue
  DOC_COUNT=$((DOC_COUNT + 1))
done

# ── Recent decisions (3 latest headings) ──
RECENT_DECISIONS=""
if [ -f "$SAGE_DIR/decisions.md" ]; then
  RECENT_DECISIONS=$(grep "^### " "$SAGE_DIR/decisions.md" 2>/dev/null | head -3 || true)
fi

# ── Build context payload ──
CONTEXT=""
CONTEXT+=$'## Sage Context (auto-injected)\n\n'

if [ "$WORK_COUNT" -gt 0 ]; then
  if [ -n "$IN_PROGRESS" ]; then
    CONTEXT+="Sage: ${IN_PROGRESS} is in progress."$'\n\n'
  fi
  CONTEXT+="Active work (${WORK_COUNT}):"$'\n'
  CONTEXT+="${ACTIVE_WORK}"
else
  CONTEXT+=$'Sage: No active work. Ready for a new task.\n'
fi

if [ "$DOC_COUNT" -gt 0 ]; then
  CONTEXT+="Project docs: ${DOC_COUNT} files in .sage/docs/"$'\n'
fi

if [ -n "$RECENT_DECISIONS" ]; then
  CONTEXT+=$'\nRecent decisions:\n'
  CONTEXT+="${RECENT_DECISIONS}"$'\n'
fi

CONTEXT+=$'\nEntry: $sage, $build, $fix, $architect, $continue, $status, $review. '
CONTEXT+=$'Read AGENTS.md for the Sage Process Constitution. Never start fresh when .sage/ has content.\n'

# ── Emit hook JSON ──
# Pass the python source via -c (a string arg) so stdin stays intact.
# CONTEXT is passed via env var to avoid argv quoting edge cases.
export SAGE_HOOK_CONTEXT="$CONTEXT"
python3 -c "$(cat <<'PY'
import json
import os
import sys

context = os.environ.get("SAGE_HOOK_CONTEXT", "")

payload = {}
try:
    payload = json.load(sys.stdin)
except Exception:
    payload = {}

event = (
    payload.get("hook_event_name")
    or payload.get("event_name")
    or "SessionStart"
)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": event,
        "additionalContext": context,
    }
}))
PY
)"
