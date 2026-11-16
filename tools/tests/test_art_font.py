"""Acceptance test for spec 009 (pixel font), R3: the lint's `font` category.

Run: python -m unittest discover tools/tests   (the `art` check step runs it too)
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import art  # noqa: E402
from test_art import STEEL, ArtTestCase, outlined_square, px_text  # noqa: E402

# Two 5x8 glyphs, an H and an i, in white on transparency.
GLYPH_H = ["j..j.", "j..j.", "jjjj.", "j..j.", "j..j.", ".....", ".....", "....."]
GLYPH_I = ["j....", ".....", "j....", "j....", "j....", ".....", ".....", "....."]


class TestFontCategory(ArtTestCase):
    def baked(self, relative: str, text: str) -> Path:
        source = self.write(relative, text)
        art.bake_file(source, self.palette)
        return source

    def font(self, parts: list[tuple[str, list[str]]], size: str = "5x8") -> str:
        return px_text("font", size, parts)

    def test_r3_font_category_lint(self) -> None:
        # A font sheet in white only passes, with no outline.
        self.baked("fonts/good.px", self.font([("cap_h", GLYPH_H), ("i", GLYPH_I)]))
        self.assertEqual(self.lint(), [])

        # Any size the font needs, even past the 64x64 of `fx` and `ui`.
        wide = ["j" * 80] + ["." * 80] * 69
        self.baked("fonts/big.px", self.font([("block", wide)], size="80x70"))
        self.assertEqual(self.lint(), [])

        # One opaque pixel that is not white fails, naming the file, the part and the pixel.
        tinted = list(GLYPH_I)
        tinted[2] = STEEL + tinted[2][1:]
        self.baked("fonts/tinted.px", self.font([("cap_h", GLYPH_H), ("i", tinted)]))
        problems = self.lint()
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("assets/fonts/tinted.px", problems[0].replace("\\", "/"))
        self.assertIn("part `i`", problems[0])
        self.assertIn("white", problems[0])
        self.assertIn("0,2", problems[0])

    def test_r3_other_categories_are_unchanged(self) -> None:
        self.assertEqual(art.CATEGORIES["font"], (None, False))
        # ui still stops at 64x64 and still allows any palette colour.
        self.baked("ui/big.px", px_text("ui", "65x8", [("x", [STEEL * 65] * 8)]))
        problems = self.lint()
        self.assertTrue(any("ui/big.px" in p and "over 64x64" in p for p in problems), problems)
        (self.assets / "ui" / "big.px").unlink()
        (self.assets / "ui" / "big.png").unlink()
        (self.assets / "ui" / "big.json").unlink()
        self.baked("ui/steel.px", px_text("ui", "8x8", [("x", [STEEL * 8] * 8)]))
        self.assertEqual(self.lint(), [])
        # Outlined categories still need their outline.
        self.baked("items/ok.px", px_text("item", "16x16", [("x", outlined_square(16, 0, 15))]))
        self.assertEqual(self.lint(), [])
        gap = outlined_square(16, 0, 15)
        gap[0] = STEEL + gap[0][1:]
        self.baked("items/gap.px", px_text("item", "16x16", [("x", gap)]))
        problems = self.lint()
        self.assertTrue(any("items/gap.px" in p and "outline gap" in p for p in problems), problems)


if __name__ == "__main__":
    unittest.main()
