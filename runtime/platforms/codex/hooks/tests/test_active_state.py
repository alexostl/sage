"""Tests for runtime/platforms/codex/hooks/lib/active_state.py"""
from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
HOOKS_DIR = HERE.parent
TMP = HERE / "tmp"

sys.path.insert(0, str(HOOKS_DIR))

from lib.active_state import (  # noqa: E402
    HARD_BUDGET_BYTES,
    SOFT_BUDGET_BYTES,
    compute,
)


def _ensure_fixtures():
    if (TMP / "sage_no_active").is_dir():
        return
    subprocess.run(
        ["bash", str(HERE / "fixtures" / "build_fixtures.sh")],
        check=True,
    )


class NoActive(unittest.TestCase):
    def setUp(self):
        _ensure_fixtures()

    def test_no_active_returns_explicit_message(self):
        block = compute(TMP / "sage_no_active")
        self.assertIn("no active initiative", block.lower())

    def test_size_within_soft_budget(self):
        block = compute(TMP / "sage_no_active")
        self.assertLessEqual(len(block.encode("utf-8")), SOFT_BUDGET_BYTES)


class PhaseLadder(unittest.TestCase):
    def setUp(self):
        _ensure_fixtures()

    def test_brief_only(self):
        block = compute(TMP / "sage_brief_only")
        self.assertIn("active: brief-init", block)
        self.assertIn("phase: brief", block)

    def test_spec_only(self):
        block = compute(TMP / "sage_spec_only")
        self.assertIn("active: spec-init", block)
        self.assertIn("phase: spec", block)

    def test_plan_only(self):
        block = compute(TMP / "sage_plan_only")
        self.assertIn("active: plan-init", block)
        # plan exists with status: in-progress → phase = plan
        self.assertIn("phase: plan", block)

    def test_verification_pending_ready_to_close(self):
        block = compute(TMP / "sage_verification_pending")
        self.assertIn("active: verify-init", block)
        self.assertIn("verification (ready)", block)
        self.assertIn("ready to close: bin/sage-close verify-init", block)


class TieBreaker(unittest.TestCase):
    def setUp(self):
        _ensure_fixtures()

    def test_multi_active_picks_most_recent_manifest(self):
        block = compute(TMP / "sage_multi_active")
        # init-c manifest was touched after init-a and init-b → wins.
        self.assertIn("active: init-c", block)
        self.assertIn("(1 of 3 active)", block)

    def test_multi_active_lists_others(self):
        block = compute(TMP / "sage_multi_active")
        self.assertIn("other active:", block)
        self.assertIn("init-a", block)
        self.assertIn("init-b", block)


class SizeBudget(unittest.TestCase):
    def setUp(self):
        _ensure_fixtures()

    def test_all_fixtures_under_hard_cap(self):
        for fixture in (
            "sage_no_active",
            "sage_brief_only",
            "sage_spec_only",
            "sage_plan_only",
            "sage_verification_pending",
            "sage_multi_active",
        ):
            with self.subTest(fixture=fixture):
                block = compute(TMP / fixture)
                self.assertLessEqual(
                    len(block.encode("utf-8")),
                    HARD_BUDGET_BYTES,
                    msg=f"fixture {fixture} exceeded hard budget: {block!r}",
                )

    def test_common_fixtures_under_soft_cap(self):
        # Single-active fixtures should fit comfortably under soft budget.
        for fixture in (
            "sage_no_active",
            "sage_brief_only",
            "sage_spec_only",
            "sage_plan_only",
        ):
            with self.subTest(fixture=fixture):
                block = compute(TMP / fixture)
                self.assertLessEqual(
                    len(block.encode("utf-8")),
                    SOFT_BUDGET_BYTES,
                    msg=f"fixture {fixture} exceeded soft budget: {block!r}",
                )


class DeterminismAndShape(unittest.TestCase):
    def setUp(self):
        _ensure_fixtures()

    def test_block_is_deterministic_across_runs(self):
        a = compute(TMP / "sage_verification_pending")
        b = compute(TMP / "sage_verification_pending")
        self.assertEqual(a, b)

    def test_first_line_starts_with_marker(self):
        for fixture in (
            "sage_brief_only",
            "sage_spec_only",
            "sage_plan_only",
            "sage_verification_pending",
            "sage_multi_active",
        ):
            with self.subTest(fixture=fixture):
                block = compute(TMP / fixture)
                first = block.split("\n", 1)[0]
                self.assertTrue(
                    first.startswith("Sage state — active:"),
                    msg=f"first={first!r}",
                )


if __name__ == "__main__":
    unittest.main()
