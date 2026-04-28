"""Sage verification.md shape validator.

Single source of truth for the shape of `.sage/work/<slug>/verification.md`.
Consumed by:

- L1 (`active_state.py`) to decide whether to emit the "ready to close"
  sticky reminder.
- L4 (`bin/sage-close`) to gate the close-out script.
- L5 (`.githooks/pre-commit`) to gate Standard+ implementation commits.

Public surface:
    REQUIRED_SECTIONS:        tuple of canonical headings, in order.
    REQUIRED_FRONTMATTER:     tuple of frontmatter keys that must be present.
    validate(path) -> (ok: bool, reasons: list[str])

Design rules:
- Returns (False, [...]) for ANY problem, including OS errors. Never raises.
- One reason string per problem. Reasons read as one-line UI strings.
- No regex {N,M} quantifiers — this module is also imported by code that
  inlines Python via `python3 -c "$(cat <<'PY' ... PY)"` heredocs, which
  Bash brace-expands {N,M} into garbage. Use `*?` and explicit anchors.
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Iterable, List, Tuple

REQUIRED_SECTIONS: Tuple[str, ...] = (
    "Pre-fix reproducer",
    "Implementation summary",
    "Test command + pasted output",
    "Close-out checklist",
)

REQUIRED_FRONTMATTER: Tuple[str, ...] = (
    "cycle_id",
    "verified_at",
    "scope",
    "closed",
)

# A markdown ATX heading at level 2 (## Foo). Capture the title text.
# Avoid {N,M} quantifiers so Bash brace expansion doesn't mangle inlined
# copies of this module.
_H2_RE = re.compile(r"^##\s+(.*?)\s*$")


def _read_text(path: Path) -> Tuple[str, List[str]]:
    """Return (text, reasons). On read error, text is empty and reasons
    carries the failure."""
    try:
        return path.read_text(encoding="utf-8", errors="replace"), []
    except OSError as exc:
        return "", [f"verification.md: cannot read file ({exc.__class__.__name__})"]


def _parse_frontmatter(text: str) -> Tuple[dict, bool]:
    """Return (frontmatter_dict, has_block).

    Recognises the standard `---\\n...\\n---\\n` block at the very top of
    the file. Values are kept as strings, stripped of surrounding quotes
    and whitespace. Lines without a colon are skipped.
    """
    if not text.startswith("---"):
        return {}, False
    end = text.find("\n---", 4)
    if end < 0:
        return {}, False
    block = text[4:end]
    out: dict = {}
    for line in block.splitlines():
        line = line.strip()
        if not line or ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        out[key] = val
    return out, True


def _h2_titles(text: str) -> List[str]:
    """Return all level-2 heading titles in document order."""
    out: List[str] = []
    for line in text.splitlines():
        m = _H2_RE.match(line)
        if m:
            out.append(m.group(1).strip())
    return out


def _check_test_section_body(text: str) -> List[str]:
    """Verify the '## Test command + pasted output' section has a fenced
    block whose body contains at least one line beyond the command line.

    Returns a list of reason strings (empty on success).
    """
    target = "Test command + pasted output"
    lines = text.splitlines()
    # Find the heading line.
    start = -1
    for i, line in enumerate(lines):
        m = _H2_RE.match(line)
        if m and m.group(1).strip() == target:
            start = i + 1
            break
    if start < 0:
        # Heading absence is reported separately by section-order check;
        # don't double-report here.
        return []

    # Collect lines until the next H2 or EOF.
    body: List[str] = []
    for line in lines[start:]:
        if _H2_RE.match(line):
            break
        body.append(line)

    # Find the first fenced code block in body.
    fence_open = -1
    fence_close = -1
    for i, line in enumerate(body):
        stripped = line.strip()
        if stripped.startswith("```"):
            if fence_open < 0:
                fence_open = i
            else:
                fence_close = i
                break
    if fence_open < 0 or fence_close < 0:
        return [
            "verification.md: '## Test command + pasted output' section is "
            "missing a fenced code block (use ``` … ```)."
        ]

    inside = body[fence_open + 1:fence_close]
    # Drop blank-only lines for the count.
    non_blank = [ln for ln in inside if ln.strip()]
    if len(non_blank) < 2:
        return [
            "verification.md: '## Test command + pasted output' fenced block "
            "must contain at least one line of output beyond the command "
            "(found "
            + str(len(non_blank))
            + " non-blank line(s))."
        ]
    return []


def validate(path) -> Tuple[bool, List[str]]:
    """Validate the shape of a verification.md file.

    Returns (True, []) on full pass; (False, [reason, ...]) on any
    problem. Multiple issues produce multiple reasons in stable order.
    """
    p = Path(path)
    if not p.is_file():
        return False, [f"verification.md: file not found at {p}"]

    text, reasons = _read_text(p)
    if reasons:
        return False, reasons

    # 1. Frontmatter present + required keys
    fm, has_block = _parse_frontmatter(text)
    if not has_block:
        reasons.append(
            "verification.md: frontmatter block missing "
            "(expected '---' fenced YAML at top of file)."
        )
    else:
        for key in REQUIRED_FRONTMATTER:
            if key not in fm or fm[key] == "":
                reasons.append(
                    "verification.md: frontmatter missing required key '"
                    + key
                    + "'."
                )

    # 2. Required headings present + in canonical order
    found = _h2_titles(text)
    missing = [h for h in REQUIRED_SECTIONS if h not in found]
    for h in missing:
        reasons.append(
            "verification.md: required section '## " + h + "' is missing."
        )
    if not missing:
        # Order check only when all are present (otherwise the missing ones
        # already explain the failure).
        present_in_order = [h for h in found if h in REQUIRED_SECTIONS]
        if tuple(present_in_order) != REQUIRED_SECTIONS:
            reasons.append(
                "verification.md: required sections present but out of "
                "canonical order. Expected: "
                + " → ".join(REQUIRED_SECTIONS)
                + ". Found: "
                + " → ".join(present_in_order)
                + "."
            )

    # 3. Test section body shape (only worth checking if heading is present)
    if "Test command + pasted output" in found:
        reasons.extend(_check_test_section_body(text))

    return (len(reasons) == 0), reasons


__all__ = ["REQUIRED_SECTIONS", "REQUIRED_FRONTMATTER", "validate"]
