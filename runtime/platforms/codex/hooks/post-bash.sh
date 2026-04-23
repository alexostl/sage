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
)"
