#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import sys

payload = json.load(sys.stdin)
event = payload.get("hook_event_name") or payload.get("event_name") or "SessionStart"

print(
    json.dumps(
        {
            "hookSpecificOutput": {
                "hookEventName": event,
                "additionalContext": (
                    "Sage workspace detected. Before substantial work, read "
                    ".sage/work/ for active initiatives and .sage/decisions.md "
                    "for recent context."
                ),
            }
        }
    )
)
PY
