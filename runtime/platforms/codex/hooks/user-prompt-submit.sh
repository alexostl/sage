#!/usr/bin/env bash
# user-prompt-submit.sh — Codex UserPromptSubmit hook for literal A/a overrides.
set -euo pipefail
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$HOOK_DIR/lib/approval_pending.sh"

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

payload="$(cat 2>/dev/null || true)"
if ! printf '%s' "$payload" | jq -e . >/dev/null 2>&1; then
    exit 0
fi

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$PWD"
session_id="$(printf '%s' "$payload" | jq -r '.session_id // "unknown"')"
turn_id="$(printf '%s' "$payload" | jq -r '.turn_id // "unknown"')"
prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty')"
trimmed_prompt="$(printf '%s' "$prompt" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

case "$trimmed_prompt" in
    A|a)
        approval_pending_approve "$cwd" "$session_id" "$turn_id" || true ;;
    *)
        approval_pending_reject "$cwd" "$session_id" || true ;;
esac

exit 0
