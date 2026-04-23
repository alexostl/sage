#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Sage UserPromptSubmit hook — pre-turn gate for Codex
#
# Reads the incoming user prompt. When it matches build / fix /
# architect keywords AND the required `.sage/work/` artifact is
# missing, the hook returns `decision: "block"` plus an
# `additionalContext` block that redirects the model to the right
# workflow. This is Codex's only pre-turn gate and the strongest
# lever for keeping the agent on the Sage rulebook.
#
# Belt-and-suspenders — the AGENTS.md constitution still applies
# when hooks are off. Enable by copying into .codex/hooks/ and
# setting [features].codex_hooks = true in .codex/config.toml.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

# Pass the python source via -c (a string arg) so stdin stays intact
# for the Codex hook JSON payload. `cat <<'PY'` captures the script,
# `$()` substitutes it into the -c arg.
python3 -c "$(cat <<'PY'
import json
import os
import re
import sys
from pathlib import Path

try:
    payload = json.load(sys.stdin)
except Exception:
    # If stdin is not parseable, do nothing — never break the turn.
    sys.exit(0)

prompt = (
    payload.get("tool_input", {}).get("prompt")
    or payload.get("prompt")
    or payload.get("user_prompt")
    or ""
)

if not isinstance(prompt, str) or not prompt.strip():
    sys.exit(0)

# Project root resolution — Codex sets CWD to project root for hooks,
# but we also accept an explicit SAGE_PROJECT_ROOT override.
root = Path(os.environ.get("SAGE_PROJECT_ROOT") or os.getcwd())
sage_work = root / ".sage" / "work"

# Escape hatches — do not block when the user is explicitly opting out
# or invoking a Sage skill that will handle the gate itself.
lower = prompt.lower().strip()
explicit_skill = lower.startswith(("$build", "$fix", "$architect", "$sage",
                                   "$continue", "$research", "$design",
                                   "$analyze", "$qa", "$review", "$reflect",
                                   "/build", "/fix", "/architect", "/sage"))
if explicit_skill:
    sys.exit(0)

# Keyword classification — narrow on purpose. Tier 1 micro-edits should
# pass through; only match prompts that clearly describe Standard+ work.
BUILD_RE = re.compile(
    r"\b("
    r"(?:please\s+)?(?:build|implement|add|create|develop|ship|deliver|introduce)"
    r")\b",
    re.IGNORECASE,
)
FIX_RE = re.compile(
    r"\b(fix|debug|broken|crash|crashing|failing|regression|bug|error)\b",
    re.IGNORECASE,
)
ARCHITECT_RE = re.compile(
    r"\b(architect|redesign|migrate|rewrite|refactor\s+(the\s+)?(entire|whole|system))\b",
    re.IGNORECASE,
)

# Tier 1 pass-through — trivial micro-tasks never hit the gate.
TINY_RE = re.compile(
    r"^\s*(?:please\s+)?(?:what|why|when|where|how|show|list|print|explain|tell|describe)\b",
    re.IGNORECASE,
)

def any_initiative_has(name: str) -> bool:
    if not sage_work.is_dir():
        return False
    for child in sage_work.iterdir():
        if child.is_dir() and (child / name).is_file():
            return True
    return False

def emit_block(workflow: str, required: list[str], reason_line: str) -> None:
    missing = ", ".join(f"`{r}`" for r in required)
    context = (
        f"Sage workflow gate — {workflow}.\n\n"
        f"The request above matches the Sage {workflow} workflow. "
        f"Required artifact(s) not found on disk: {missing}.\n\n"
        f"Before responding to the user's prompt:\n"
        f"1. Announce `Sage → {workflow} workflow.` in your reply.\n"
        f"2. Read .sage/decisions.md (last 5 entries) and scan "
        f".sage/work/*/ frontmatter for active initiatives.\n"
        f"3. Call sage_memory_search with domain keywords (limit 5), then "
        f"again with filter_tags [\"self-learning\"] (limit 5). Parameter "
        f"types: limit is an integer, filter_tags is an array.\n"
        f"4. Write the missing artifact(s) to "
        f".sage/work/<initiative>/ and present them to the user with "
        f"[A] Approve / [R] Revise — wait for approval before any code edit.\n\n"
        f"{reason_line}\n\n"
        f"Do not start implementation in this turn."
    )
    print(json.dumps({
        "decision": "block",
        "reason": f"Sage {workflow} gate: {missing} missing.",
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": context,
        },
    }))
    sys.exit(0)

# Skip tiny / read-only prompts.
if TINY_RE.search(prompt):
    sys.exit(0)

# Fix keyword → require root-cause checkpoint before coding.
# Fix gate is behavioral (root cause approved) rather than file-backed,
# but we still redirect so the agent runs the gate instead of jumping
# straight to an edit.
if FIX_RE.search(prompt):
    # Emit a redirect even when no .sage/work exists — root cause
    # investigation has to happen before edits regardless of artifacts.
    context = (
        "Sage workflow gate — fix.\n\n"
        "The request above matches the Sage fix workflow.\n\n"
        "Before editing any file:\n"
        "1. Announce `Sage → fix workflow.` in your reply.\n"
        "2. Call sage_memory_search on the bug domain / error text with "
        "filter_tags [\"self-learning\"] (limit 5). Parameter types: "
        "limit is an integer, filter_tags is an array.\n"
        "3. Investigate the root cause with evidence (logs, stack, repro, "
        "code paths). Present root cause + evidence to the user and wait "
        "for [A] Approve / [R] Revise / [S] Skip review.\n"
        "4. After [A], scope the fix (Surgical / Moderate / Systemic). "
        "Moderate+ writes plan.md first. Systemic escalates to $build or "
        "$architect.\n\n"
        "Do not edit code in this turn until the root cause is approved."
    )
    print(json.dumps({
        "decision": "block",
        "reason": "Sage fix gate: root cause must be approved before edits.",
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": context,
        },
    }))
    sys.exit(0)

# Architect keyword → require brief.md first.
if ARCHITECT_RE.search(prompt):
    if not any_initiative_has("brief.md"):
        emit_block(
            "architect",
            [".sage/work/<initiative>/brief.md"],
            "Architecture work requires a completed 3-round elicitation "
            "brief before any design output. \"I understand the system\" "
            "is not a brief.",
        )

# Build keyword → require spec.md AND plan.md.
if BUILD_RE.search(prompt):
    has_spec = any_initiative_has("spec.md")
    has_plan = any_initiative_has("plan.md")
    if not (has_spec and has_plan):
        missing = []
        if not has_spec:
            missing.append(".sage/work/<initiative>/spec.md")
        if not has_plan:
            missing.append(".sage/work/<initiative>/plan.md")
        emit_block(
            "build",
            missing,
            "Build work requires spec and plan files on disk before "
            "implementation. \"The design is clear\" is not a spec.",
        )

# Nothing matched / all gates satisfied — allow the turn through.
sys.exit(0)
PY
)"
