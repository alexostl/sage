"""Tests for runtime/platforms/codex/hooks/lib/verification_check.py

Run from runtime/platforms/codex/hooks/:
    python3 -m unittest discover -s tests -p 'test_*.py' -v

Fixtures are built by tests/fixtures/build_fixtures.sh — this test
auto-rebuilds them if missing.
"""
from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
HOOKS_DIR = HERE.parent
TMP = HERE / "tmp"
VERIF_DIR = TMP / "verifications"

# Ensure lib/ is importable.
sys.path.insert(0, str(HOOKS_DIR))

from lib.verification_check import (  # noqa: E402
    REQUIRED_FRONTMATTER,
    REQUIRED_SECTIONS,
    validate,
)


def _ensure_fixtures():
    if VERIF_DIR.is_dir() and (VERIF_DIR / "valid.md").is_file():
        return
    builder = HERE / "fixtures" / "build_fixtures.sh"
    subprocess.run(["bash", str(builder)], check=True)


class ValidatorPublicSurface(unittest.TestCase):
    def test_required_sections_constant(self):
        self.assertEqual(
            REQUIRED_SECTIONS,
            (
                "Pre-fix reproducer",
                "Implementation summary",
                "Test command + pasted output",
                "Close-out checklist",
            ),
        )

    def test_required_frontmatter_constant(self):
        self.assertEqual(
            REQUIRED_FRONTMATTER,
            ("cycle_id", "verified_at", "scope", "closed"),
        )

    def test_validate_signature_returns_tuple(self):
        _ensure_fixtures()
        result = validate(VERIF_DIR / "valid.md")
        self.assertIsInstance(result, tuple)
        self.assertEqual(len(result), 2)
        ok, reasons = result
        self.assertIsInstance(ok, bool)
        self.assertIsInstance(reasons, list)


class HappyPath(unittest.TestCase):
    def setUp(self):
        _ensure_fixtures()

    def test_valid_passes(self):
        ok, reasons = validate(VERIF_DIR / "valid.md")
        self.assertTrue(ok, msg=f"reasons={reasons}")
        self.assertEqual(reasons, [])

    def test_valid_closed_also_passes(self):
        # Shape doesn't depend on closed: false vs true.
        ok, reasons = validate(VERIF_DIR / "valid_closed.md")
        self.assertTrue(ok, msg=f"reasons={reasons}")
        self.assertEqual(reasons, [])


class MissingHeadings(unittest.TestCase):
    def setUp(self):
        _ensure_fixtures()

    def test_missing_pre_fix_reproducer(self):
        ok, reasons = validate(VERIF_DIR / "missing_prefix_reproducer.md")
        self.assertFalse(ok)
        joined = "\n".join(reasons)
        self.assertIn("Pre-fix reproducer", joined)

    def test_missing_implementation_summary(self):
        ok, reasons = validate(
            VERIF_DIR / "missing_implementation_summary.md"
        )
        self.assertFalse(ok)
        joined = "\n".join(reasons)
        self.assertIn("Implementation summary", joined)

    def test_missing_test_command(self):
        ok, reasons = validate(
            VERIF_DIR / "missing_test_command_+_pasted_output.md"
        )
        self.assertFalse(ok)
        joined = "\n".join(reasons)
        self.assertIn("Test command + pasted output", joined)

    def test_missing_close_out_checklist(self):
        ok, reasons = validate(VERIF_DIR / "missing_closeout_checklist.md")
        self.assertFalse(ok)
        joined = "\n".join(reasons)
        self.assertIn("Close-out checklist", joined)


class FrontmatterFailures(unittest.TestCase):
    def setUp(self):
        _ensure_fixtures()

    def test_no_frontmatter_block(self):
        ok, reasons = validate(VERIF_DIR / "no_frontmatter.md")
        self.assertFalse(ok)
        joined = "\n".join(reasons)
        self.assertIn("frontmatter", joined.lower())


class TestSectionShape(unittest.TestCase):
    def setUp(self):
        _ensure_fixtures()

    def test_no_fenced_block(self):
        ok, reasons = validate(VERIF_DIR / "no_fenced_block.md")
        self.assertFalse(ok)
        joined = "\n".join(reasons)
        self.assertIn("fenced", joined.lower())

    def test_empty_test_block_only_command(self):
        ok, reasons = validate(VERIF_DIR / "empty_test_block.md")
        self.assertFalse(ok)
        joined = "\n".join(reasons)
        # Either fence-missing or output-line-count message acceptable;
        # accept either as long as the test section is flagged.
        self.assertTrue(
            "test" in joined.lower() and (
                "fenced" in joined.lower() or "line" in joined.lower()
            ),
            msg=f"reasons={reasons}",
        )


class OrderCheck(unittest.TestCase):
    def setUp(self):
        _ensure_fixtures()

    def test_wrong_order_flagged(self):
        ok, reasons = validate(VERIF_DIR / "wrong_order.md")
        self.assertFalse(ok)
        joined = "\n".join(reasons)
        self.assertIn("order", joined.lower())


class FileNotFound(unittest.TestCase):
    def test_missing_file(self):
        ok, reasons = validate(TMP / "verifications" / "does_not_exist.md")
        self.assertFalse(ok)
        joined = "\n".join(reasons)
        self.assertIn("not found", joined.lower())


if __name__ == "__main__":
    unittest.main()
