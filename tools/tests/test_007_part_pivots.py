"""Acceptance tests for spec 007 (character sprites), requirement R2: part pivots in the baker and lint.

Run: python -m unittest discover tools/tests   (the `art` check step runs it too)
"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOOLS))

import art  # noqa: E402

PALETTE_PATH = TOOLS.parent / "assets" / "style" / "palette.txt"


def square(size: int, start: int, end: int) -> list[str]:
    """A steel square from start to end (inclusive) with an ink border."""
    rows = []
    for y in range(size):
        row = ""
        for x in range(size):
            inside = start <= x <= end and start <= y <= end
            edge = x in (start, end) or y in (start, end)
            row += ("p" if edge else "l") if inside else "."
        rows.append(row)
    return rows


def source_text(arm_header: str) -> str:
    lines = ["category = item", "size = 16x16", "", "[body]", *square(16, 2, 13), "", arm_header]
    lines += square(16, 5, 9)
    return "\n".join(lines) + "\n"


class TestPartPivots(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.assets = Path(self._tmp.name) / "assets"
        self.assets.mkdir()
        self.palette = art.load_palette(PALETTE_PATH)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def bake(self, name: str, text: str) -> Path:
        source = self.assets / f"{name}.px"
        source.write_text(text, encoding="utf-8")
        art.bake_file(source, self.palette)
        return source

    def test_r2_part_pivots_bake_and_lint(self) -> None:
        # The pivot syntax bakes into the JSON, beside the sprite's own pivot.
        with_pivot = self.bake("with", source_text("[arm] pivot=12,14"))
        described = json.loads(with_pivot.with_suffix(".json").read_text(encoding="utf-8"))
        self.assertEqual(described["parts"], ["body", "arm"])
        self.assertEqual(described["part_pivots"], {"arm": [12, 14]})
        self.assertEqual(described["pivot"], [8, 15])
        self.assertEqual(art.lint(self.assets, PALETTE_PATH), [], "a declared pivot is lint-clean")

        # A file without part pivots bakes exactly as before: same PNG, no new JSON key.
        without = self.bake("without", source_text("[arm]"))
        self.assertEqual(
            without.with_suffix(".png").read_bytes(), with_pivot.with_suffix(".png").read_bytes()
        )
        described = json.loads(without.with_suffix(".json").read_text(encoding="utf-8"))
        self.assertEqual(
            described,
            {"category": "item", "width": 16, "height": 16, "pivot": [8, 15], "parts": ["body", "arm"]},
        )

        # A pivot outside the canvas is a lint failure naming the file and the part.
        outside = self.assets / "outside.px"
        outside.write_text(source_text("[arm] pivot=16,3"), encoding="utf-8")
        problems = [p for p in art.lint(self.assets, PALETTE_PATH) if "outside.px" in p]
        self.assertTrue(problems, "an out-of-canvas part pivot fails the lint")
        self.assertTrue(any("arm" in p and "outside" in p.lower() for p in problems), problems)

        # A malformed pivot is rejected too.
        with self.assertRaises(art.ArtError):
            art.parse_px(source_text("[arm] pivot=twelve"), self.palette)

    def test_r2_repository_sheets_without_part_pivots_are_unchanged(self) -> None:
        # The parser keeps no pivots for parts that declare none.
        sprite = art.parse_px(source_text("[arm]"), self.palette)
        self.assertEqual(sprite.part_pivots, {})


if __name__ == "__main__":
    unittest.main()
