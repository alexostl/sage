"""Sage active-state computation for the Codex UserPromptSubmit hook.

Produces a small, deterministic sticky-context block that is appended
to every turn's `additionalContext`. The block re-states which
initiative is active, what phase it is in, what's still missing, and
what the next gate is. It does NOT contain LLM-generated prose — every
line is derived mechanically from `.sage/work/` and `.sage/decisions.md`.

Public surface:
    compute(sage_root: str | Path) -> str
    SOFT_BUDGET_BYTES = 600
    HARD_BUDGET_BYTES = 1200

Design rules:
- Reuse the same "active" definition as `pre-prompt.sh`
  (`_initiative_is_active`) — non-terminal frontmatter on
  spec/plan/brief/fix-plan, with TERMINAL_STATUSES = {completed, abandoned}.
- Tie-breaker for multi-active: manifest.md mtime → frontmatter
  `updated:` mtime → alphabetical slug.
- "Ready to close" line is gated by validator success on
  `verification.md` AND frontmatter `closed: false` (single source of
  truth, no decisions.md format coupling).
- Hard cap at HARD_BUDGET_BYTES; truncate optional lines first.
- No regex {N,M} quantifiers — module is also imported via heredoc'd
  `python3 -c` calls.
"""
from __future__ import annotations

import os
import re
from pathlib import Path
from typing import List, Optional, Tuple

# Importable as `lib.verification_check.validate` from the hooks package.
try:
    from .verification_check import validate as _validate_verification
except ImportError:  # pragma: no cover - allow flat sys.path imports too
    from verification_check import validate as _validate_verification  # type: ignore

SOFT_BUDGET_BYTES = 600
HARD_BUDGET_BYTES = 1200

TERMINAL_STATUSES = frozenset({"completed", "abandoned"})

# Artifacts that mark "an initiative exists / is active". Order matters
# only for diagnostics; activeness is "any of these has non-terminal
# status".
KNOWN_ARTIFACTS = ("brief.md", "spec.md", "plan.md", "fix-plan.md")

# Frontmatter helpers — same shape as pre-prompt.sh._frontmatter_status.
_KEY_RE = re.compile(r"^([a-z_]+)\s*:\s*(.*)$", re.IGNORECASE)


def _read_frontmatter(path: Path) -> dict:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 4)
    if end < 0:
        return {}
    out: dict = {}
    for line in text[4:end].splitlines():
        line = line.strip()
        if not line or ":" not in line:
            continue
        m = _KEY_RE.match(line)
        if not m:
            continue
        key = m.group(1).strip().lower()
        val = m.group(2).strip().strip('"').strip("'")
        out[key] = val
    return out


def _status(path: Path) -> str:
    return _read_frontmatter(path).get("status", "").lower()


def _initiative_is_active(slug_dir: Path) -> bool:
    """Active = pre-prompt.sh's definition (non-terminal frontmatter on
    spec/plan/brief/fix-plan) UNION (verification.md exists and
    `closed != true`).

    The verification-pending case is intentionally wider than
    pre-prompt.sh's gate predicate: the build/fix gates do not need to
    fire on verification-pending initiatives (spec+plan are already
    completed by then), but sticky context MUST surface them so the
    agent sees "ready to close" and does not silently drop the work.
    """
    for artifact in KNOWN_ARTIFACTS:
        p = slug_dir / artifact
        if not p.is_file():
            continue
        st = _status(p)
        if st and st not in TERMINAL_STATUSES:
            return True
    verification = slug_dir / "verification.md"
    if verification.is_file():
        if _read_frontmatter(verification).get("closed", "").lower() != "true":
            return True
    return False


def _list_active_initiatives(work_dir: Path) -> List[Path]:
    if not work_dir.is_dir():
        return []
    out = [c for c in work_dir.iterdir()
           if c.is_dir() and _initiative_is_active(c)]
    return out


def _tie_break_key(slug_dir: Path) -> Tuple[float, float, str]:
    """Sort key for picking among multiple active initiatives.

    Higher (more recent) wins. Returns (manifest_mtime, max_updated_mtime,
    -slug_alphabetical_for_inverse_tiebreak).
    """
    manifest = slug_dir / "manifest.md"
    manifest_mtime = manifest.stat().st_mtime if manifest.is_file() else 0.0
    artifact_mtime = 0.0
    for artifact in KNOWN_ARTIFACTS:
        p = slug_dir / artifact
        if p.is_file():
            artifact_mtime = max(artifact_mtime, p.stat().st_mtime)
    # We want larger keys to mean "preferred" → invert the slug for the
    # alphabetical fallback so that earlier alphabetically wins ties.
    inverse_slug = "".join(chr(0x10FFFF - ord(c)) for c in slug_dir.name[:32])
    return (manifest_mtime, artifact_mtime, inverse_slug)


def _pick_active(initiatives: List[Path]) -> Optional[Path]:
    if not initiatives:
        return None
    return max(initiatives, key=_tie_break_key)


# ── Phase ladder ──────────────────────────────────────────────────────
# verification > implementation > plan > spec > brief

def _phase(slug_dir: Path) -> str:
    """Compute phase from most-advanced artifact present + its status."""
    verification = slug_dir / "verification.md"
    plan = slug_dir / "plan.md"
    spec = slug_dir / "spec.md"
    brief = slug_dir / "brief.md"
    fix_plan = slug_dir / "fix-plan.md"
    if verification.is_file():
        ok, _reasons = _validate_verification(verification)
        return "verification (ready)" if ok else "verification (incomplete)"
    if plan.is_file():
        return "implementation" if _status(plan) == "completed" else "plan"
    if fix_plan.is_file():
        return ("implementation"
                if _status(fix_plan) == "completed"
                else "fix-plan")
    if spec.is_file():
        return "plan-pending" if _status(spec) == "completed" else "spec"
    if brief.is_file():
        return "brief"
    return "empty"


_NEXT_GATE_BY_PHASE = {
    "verification (ready)": "run bin/sage-close <slug>",
    "verification (incomplete)": "complete verification.md per template",
    "implementation": "implement plan tasks → write verification.md",
    "plan": "complete plan.md → present [A]/[R]",
    "fix-plan": "complete fix-plan.md → present [A]/[R]",
    "plan-pending": "write plan.md (spec is completed)",
    "spec": "complete spec.md → present [A]/[R]",
    "brief": "write spec.md from approved brief",
    "empty": "scaffold spec.md (no artifacts present)",
}


def _missing_artifacts(slug_dir: Path, phase: str) -> List[str]:
    """List artifacts that the current phase implies should exist but don't."""
    missing: List[str] = []
    needs = []
    if phase in ("plan", "implementation", "verification (ready)",
                 "verification (incomplete)", "plan-pending"):
        needs.append("spec.md")
    if phase in ("implementation", "verification (ready)",
                 "verification (incomplete)"):
        needs.append("plan.md")
    if phase == "verification (incomplete)":
        needs.append("verification.md")
    for n in needs:
        if not (slug_dir / n).is_file():
            missing.append(n)
    return missing


def _present_artifacts(slug_dir: Path) -> List[str]:
    out: List[str] = []
    for artifact in ("brief.md", "spec.md", "plan.md", "fix-plan.md",
                     "verification.md", "manifest.md"):
        p = slug_dir / artifact
        if p.is_file():
            st = _status(p)
            out.append(artifact + (":" + st if st else ""))
    return out


def _close_pending(slug_dir: Path) -> bool:
    verification = slug_dir / "verification.md"
    if not verification.is_file():
        return False
    fm = _read_frontmatter(verification)
    if fm.get("closed", "").lower() == "true":
        return False
    ok, _reasons = _validate_verification(verification)
    return ok


def _truncate_to_budget(lines: List[str], soft: int, hard: int) -> List[str]:
    """Drop optional lines (those marked with leading '· ') until under
    hard cap. Required lines (no leading marker) are never dropped."""
    def total(ls: List[str]) -> int:
        return sum(len(l) + 1 for l in ls)

    if total(lines) <= hard:
        return lines

    keep: List[str] = []
    optional_idx: List[int] = []
    for i, l in enumerate(lines):
        keep.append(l)
        if l.startswith("· "):
            optional_idx.append(i)

    # Drop optional lines from the back until under hard.
    while total(keep) > hard and optional_idx:
        drop_at = optional_idx.pop()
        keep[drop_at] = "· …"
        if total(keep) > hard:
            keep.pop(drop_at)
    return keep


def compute(sage_root) -> str:
    """Return the deterministic sticky-context block as a single string.

    Block is empty (returns "") when there is no useful state to surface
    (no `.sage/work/` directory, no active initiatives, no signal).
    """
    root = Path(sage_root)
    work_dir = root / ".sage" / "work"
    active = _list_active_initiatives(work_dir)
    n = len(active)

    if n == 0:
        # Surface emptiness explicitly — agent should know there is no
        # active initiative when keyword-gated workflows fire.
        return "Sage state — no active initiative."

    chosen = _pick_active(active)
    assert chosen is not None
    slug = chosen.name
    phase = _phase(chosen)
    next_gate = _NEXT_GATE_BY_PHASE.get(phase, "(unknown phase)")
    present = _present_artifacts(chosen)
    missing = _missing_artifacts(chosen, phase)
    close_pending = _close_pending(chosen)

    header_count = "" if n == 1 else " (1 of " + str(n) + " active)"
    lines: List[str] = [
        "Sage state — active: " + slug + header_count,
        "phase: " + phase,
        "next: " + next_gate,
    ]
    # Optional lines start with "· " so the truncator can drop them.
    if present:
        lines.append("· artifacts: " + ", ".join(present))
    if missing:
        lines.append("· missing: " + ", ".join(missing))
    if close_pending:
        lines.append("ready to close: bin/sage-close " + slug)
    if n > 1:
        others = sorted(d.name for d in active if d != chosen)
        lines.append("· other active: " + ", ".join(others))

    return "\n".join(_truncate_to_budget(lines, SOFT_BUDGET_BYTES,
                                          HARD_BUDGET_BYTES))


__all__ = [
    "compute",
    "SOFT_BUDGET_BYTES",
    "HARD_BUDGET_BYTES",
    "TERMINAL_STATUSES",
]
