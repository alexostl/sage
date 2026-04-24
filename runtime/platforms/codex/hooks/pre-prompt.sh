#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Sage UserPromptSubmit hook — pre-turn gate for Codex
#
# Reads the incoming user prompt. When it matches build / fix /
# architect keywords AND the required `.sage/work/` state is
# missing or inconsistent, the hook returns `decision: "block"` plus
# an `additionalContext` block that redirects the model to the right
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

# Explicit skill invocation ($build, /fix, $some-new-skill, ...) always
# passes through — the skill PREAMBLE handles the gate itself.
EXPLICIT_SKILL_RE = re.compile(r"^\s*[$/][a-z][a-z0-9-]*(?:\s|$)")
if EXPLICIT_SKILL_RE.match(prompt):
    sys.exit(0)

# Keyword classification — narrow on purpose. Tier 1 micro-edits should
# pass through; only match prompts that clearly describe Standard+ work.
#
# BUILD_RE requires a verb + a concrete noun. "add tests" is fine
# without a noun match (passes through); "build a new widget" matches.
# False negatives here are acceptable — AGENTS.md Rule 3 and the $build
# PREAMBLE are the second line of defense.
BUILD_NOUNS = (
    "feature|module|component|page|endpoint|api|service|system|"
    "integration|flow|screen|view|route|handler|migration|schema|"
    "workflow|skill|hook|platform|adapter|subagent|pipeline|job|"
    "dashboard|panel|form|widget|plugin|extension|cli|command|"
    "agent|bot|tool"
)
BUILD_RE = re.compile(
    r"\b(?:please\s+)?"
    r"(?:build|implement|create|develop|ship|deliver|introduce|add)"
    r"\b[^.?!\n]*?\b"
    rf"(?:{BUILD_NOUNS})\b",
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

# Tier 1 pass-through — read-only questions never hit the gate.
TINY_RE = re.compile(
    r"^\s*(?:please\s+)?(?:what|why|when|where|how|show|list|print|explain|tell|describe)\b",
    re.IGNORECASE,
)

# Tier 1 fix pass-through — trivial fixes explicitly carved out by
# fix.workflow.md (Surgical, 1-2 files, no plan required).
# If the fix prompt also matches one of these tokens it is allowed
# through with a hint to escalate if the work turns out deeper.
TIER1_FIX_RE = re.compile(
    r"\b(typo|typos|indentation|indent|whitespace|formatting|"
    r"rename|renaming|comment|comments|logging|log\s+statement|"
    r"log\s+line|import|imports|lint|linting|prettier|eslint|"
    r"docstring|docblock|jsdoc|spelling)\b",
    re.IGNORECASE,
)

# Tier 1 build pass-through — "add tests", "add logging", "add a docstring"
# are not Standard+ builds, they are code hygiene. BUILD_RE will catch
# them via stray nouns ("add tests for the utils module" → module); this
# gate lets them through with a hint, same pattern as TIER1_FIX_RE.
TIER1_BUILD_RE = re.compile(
    r"\btests?\b|\blogging\b|\blogs?\b|\blog\s+statement\b|"
    r"\blog\s+line\b|\bcomments?\b|\bdocstrings?\b|\bdocblocks?\b|"
    r"\bjsdoc\b|\btype\s+hints?\b|\btype\s+annotations?\b|"
    r"\bfixtures?\b|\bmocks?\b|\bstubs?\b|\bassertions?\b",
    re.IGNORECASE,
)

# Terminal frontmatter statuses — completed or abandoned work does NOT
# count as "active". An initiative in one of the non-terminal statuses
# (draft, in-progress, under-review, and anything else) is considered
# active for gate purposes.
TERMINAL_STATUSES = {"completed", "abandoned"}


def _frontmatter_status(path):
    """Return lowercased status frontmatter value, or empty string."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    if not text.startswith("---"):
        return ""
    # Walk to the next --- block.
    end = text.find("\n---", 4)
    if end < 0:
        return ""
    block = text[4:end]
    for line in block.splitlines():
        line = line.strip()
        if line.lower().startswith("status:"):
            _, _, val = line.partition(":")
            return val.strip().strip("\"").strip("\u0027").lower()
    return ""


def _initiative_is_active(dir_path):
    """True if any of spec/plan/brief/fix-plan frontmatter is non-terminal."""
    for artifact in ("plan.md", "spec.md", "brief.md", "fix-plan.md"):
        p = dir_path / artifact
        if not p.is_file():
            continue
        status = _frontmatter_status(p)
        if status and status not in TERMINAL_STATUSES:
            return True
    return False


def _active_initiatives():
    """List of .sage/work/<slug>/ dirs whose frontmatter is non-terminal."""
    if not sage_work.is_dir():
        return []
    active = []
    for child in sage_work.iterdir():
        if child.is_dir() and _initiative_is_active(child):
            active.append(child)
    return active


def _has_complete_build_pair(dir_path):
    return (dir_path / "spec.md").is_file() and (dir_path / "plan.md").is_file()


def emit_block(workflow, required, reason_line):
    missing = ", ".join("`" + r + "`" for r in required)
    context = (
        "Sage workflow gate — " + workflow + ".\n\n"
        "The request above matches the Sage " + workflow + " workflow. "
        "Required artifact(s) not found on disk: " + missing + ".\n\n"
        "Before responding to the prompt above:\n"
        "1. Announce `Sage \u2192 " + workflow + " workflow.` in your reply.\n"
        "2. Read .sage/decisions.md (last 5 entries) and scan "
        ".sage/work/*/ frontmatter for active initiatives.\n"
        "3. Call sage_memory_search with domain keywords (limit 5), then "
        "again with filter_tags [\"self-learning\"] (limit 5). Parameter "
        "types: limit is an integer, filter_tags is an array.\n"
        "4. Write the missing artifact(s) to "
        ".sage/work/<initiative>/ and present them to the user with "
        "[A] Approve / [R] Revise \u2014 wait for approval before any code edit.\n\n"
        + reason_line + "\n\n"
        "Do not start implementation in this turn."
    )
    print(json.dumps({
        "decision": "block",
        "reason": "Sage " + workflow + " gate: " + missing + " missing.",
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": context,
        },
    }))
    sys.exit(0)


def emit_pass_with_hint(workflow, hint):
    """Passthrough with a soft nudge injected as additionalContext."""
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": "Sage note \u2014 " + workflow + ": " + hint,
        },
    }))
    sys.exit(0)


# Skip tiny / read-only prompts.
if TINY_RE.search(prompt):
    sys.exit(0)

# Fix keyword → require root-cause checkpoint before coding,
# UNLESS the prompt also matches a Tier 1 fix token (typo, indent, ...).
if FIX_RE.search(prompt):
    if TIER1_FIX_RE.search(prompt):
        emit_pass_with_hint(
            "fix",
            "Tier 1 fix detected (typo / indent / log / rename / import / "
            "lint). Proceeding surgically per fix.workflow.md. If the work "
            "turns out to touch 3+ files or change behavior broadly, stop "
            "and escalate to $fix for a root-cause + scope checkpoint.",
        )
    # Fix gate is behavioral (root cause approved) rather than file-backed,
    # but we still redirect so the agent runs the gate instead of jumping
    # straight to an edit.
    context = (
        "Sage workflow gate — fix.\n\n"
        "The request above matches the Sage fix workflow.\n\n"
        "Before editing any file:\n"
        "1. Announce `Sage \u2192 fix workflow.` in your reply.\n"
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

# Architect keyword → require brief.md in an active initiative.
if ARCHITECT_RE.search(prompt):
    active = _active_initiatives()
    has_brief = any((d / "brief.md").is_file() for d in active)
    if not has_brief:
        emit_block(
            "architect",
            [".sage/work/<initiative>/brief.md"],
            "Architecture work requires a completed 3-round elicitation "
            "brief before any design output. \"I understand the system\" "
            "is not a brief.",
        )

# Build keyword → require spec.md AND plan.md inside an ACTIVE initiative
# (non-terminal frontmatter status). This closes the global-scope hole
# where a completed prior initiative would satisfy the gate forever.
if BUILD_RE.search(prompt):
    if TIER1_BUILD_RE.search(prompt):
        emit_pass_with_hint(
            "build",
            "Tier 1 build detected (tests / logging / comments / docstrings "
            "/ type hints / fixtures / mocks). Proceeding surgically. If "
            "this turns into a new feature or spans 3+ files with behavior "
            "change, stop and escalate to $build for spec + plan.",
        )
    active = _active_initiatives()
    if not active:
        emit_block(
            "build",
            [".sage/work/<new-initiative>/spec.md",
             ".sage/work/<new-initiative>/plan.md"],
            "Build work requires an active initiative (status: draft / "
            "in-progress / under-review) with spec.md and plan.md on disk. "
            "No active initiative found.",
        )
    if not any(_has_complete_build_pair(d) for d in active):
        missing = []
        any_has_spec = any((d / "spec.md").is_file() for d in active)
        any_has_plan = any((d / "plan.md").is_file() for d in active)
        if not any_has_spec:
            missing.append(".sage/work/<active>/spec.md")
        if not any_has_plan:
            missing.append(".sage/work/<active>/plan.md")
        if not missing:
            missing = [".sage/work/<active>/spec.md + plan.md (same initiative)"]
        emit_block(
            "build",
            missing,
            "Active initiative(s) found, but none has both spec.md and "
            "plan.md on disk. \"The design is clear\" is not a spec.",
        )

# Nothing matched / all gates satisfied — allow the turn through.
sys.exit(0)
PY
)"
