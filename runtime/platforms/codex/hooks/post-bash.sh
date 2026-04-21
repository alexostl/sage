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

mutation_markers = [
    "apply_patch",
    "cat >",
    "cp ",
    "mv ",
    "rm ",
    "sed -i",
    "perl -pi",
    "tee ",
    "touch ",
]

if any(marker in command for marker in mutation_markers):
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": (
                        "This Bash command may have changed repository files. "
                        "Review the resulting diff before you call the work done."
                    ),
                }
            }
        )
    )
PY
