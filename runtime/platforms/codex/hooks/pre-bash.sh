#!/usr/bin/env bash
set -euo pipefail

# Pass python source via -c so stdin stays intact for json.load.
python3 -c "$(cat <<'PY'
import json
import sys

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)
command = (
    payload.get("tool_input", {}).get("command")
    or payload.get("tool_input", {}).get("cmd")
    or ""
)

blocked_patterns = [
    "git reset --hard",
    "git clean -fd",
    "git clean -xfd",
    "rm -rf /",
]

if any(pattern in command for pattern in blocked_patterns):
    print(
        json.dumps(
            {
                "decision": "block",
                "reason": "Blocked by the starter Codex Bash hook. Review the command before retrying.",
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "additionalContext": (
                        "The starter hook only blocks a tiny set of clearly "
                        "destructive Bash commands. Expand or relax it to match "
                        "your repo's policy."
                    ),
                },
            }
        )
    )
PY
)"
