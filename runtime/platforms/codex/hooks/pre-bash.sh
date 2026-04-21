#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import sys

payload = json.load(sys.stdin)
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
