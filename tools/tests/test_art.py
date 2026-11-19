"""Acceptance tests for spec 002 (art foundation): the palette, baking and the lint.

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
import dev  # noqa: E402

PALETTE_PATH = TOOLS.parent / "assets" / "style" / "palette.txt"

SPEC_HEX = (
    "be4a2f d77643 ead4aa e4a672 b86f50 733e39 3e2731 a22633 e43b44 f77622 feae34 fee761 63c74d "
    "3e8948 265c42 193c3e 124e89 0099db 2ce8f5 ffffff c0cbdc 8b9bb4 5a6988 3a4466 262b44 181425 "
    "ff0044 68386c b55088 f6757a e8b796 c28569"
).split()

INK = "p"  # 181425, the outline colour
STEEL = "l"  # 8b9bb4
INK_RGBA = (0x18, 0x14, 0x25, 255)
STEEL_RGBA = (0x8B, 0x9B, 0xB4, 255)
CLEAR = (0, 0, 0, 0)


def blank(size: int) -> list[str]:
    return ["." * size for _ in range(size)]


def outlined_square(size: int, start: int, end: int) -> list[str]:
    """A square of steel from start to end (inclusive) with a one-pixel ink border."""
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            inside = start <= x <= end and start <= y <= end
            edge = x in (start, end) or y in (start, end)
            row.append((INK if edge else STEEL) if inside else ".")
        rows.append("".join(row))
    return rows


def px_text(category: str, size: str, parts: list[tuple[str, list[str]]], pivot: str = "") -> str:
    lines = ["# a test sprite", f"category = {category}", f"size = {size}"]
    if pivot:
        lines.append(f"pivot = {pivot}")
    for name, rows in parts:
        lines += ["", f"[{name}]", *rows]
    return "\n".join(lines) + "\n"


class ArtTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.assets = Path(self._tmp.name) / "assets"
        self.assets.mkdir()
        self.palette = art.load_palette(PALETTE_PATH)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write(self, relative: str, text: str) -> Path:
        path = self.assets / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def lint(self) -> list[str]:
        return art.lint(self.assets, PALETTE_PATH)

    def write_png(self, relative: str, width: int, height: int, pixels: list[tuple]) -> Path:
        path = self.assets / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        raw = bytes(channel for pixel in pixels for channel in pixel)
        path.write_bytes(art.encode_png(width, height, raw))
        return path

    def assert_one_problem_naming(self, problems: list[str], file_name: str, words: str) -> None:
        self.assertTrue(problems, "the lint passed but should have failed")
        matching = [p for p in problems if file_name in p and words in p.lower()]
        self.assertTrue(matching, f"no problem names {file_name} and says '{words}': {problems}")


class TestPalette(unittest.TestCase):
    def test_r1_palette_file_is_the_32_colours(self) -> None:
        lines = [line for line in PALETTE_PATH.read_text(encoding="utf-8").splitlines() if line]
        self.assertEqual(len(lines), 32)
        fields = [line.split(" ") for line in lines]
        self.assertTrue(all(len(f) == 3 for f in fields), "each line is `<symbol> <hex> <name>`")
        symbols = [f[0] for f in fields]
        hexes = [f[1] for f in fields]
        names = [f[2] for f in fields]
        self.assertEqual(symbols, list("0123456789abcdefghijklmnopqrstuv"))
        self.assertEqual(hexes, SPEC_HEX)
        self.assertEqual(len(set(names)), 32, "names are unique")
        for name in names:
            self.assertRegex(name, r"^[a-z][a-z0-9]*(_[a-z0-9]+)*$", "names are snake_case")
        self.assertEqual(dict(zip(names, hexes))["ink"], "181425")
        self.assertEqual(len(art.load_palette(PALETTE_PATH)), 32)


class TestBake(ArtTestCase):
    def two_part_source(self) -> Path:
        first = outlined_square(16, 2, 13)
        second = blank(16)
        second[15] = INK + "." * 15  # one ink pixel, bottom-left
        return self.write("sprites/two.px", px_text("item", "16x16", [("a", first), ("b", second)]))

    def test_r3_bake_writes_sheet_and_json(self) -> None:
        source = self.two_part_source()
        art.bake_file(source, self.palette)

        width, height, raw = art.decode_png(source.with_suffix(".png").read_bytes())
        self.assertEqual((width, height), (32, 16))

        def pixel(x: int, y: int) -> tuple:
            i = (y * width + x) * 4
            return tuple(raw[i : i + 4])

        self.assertEqual(pixel(0, 0), CLEAR)
        self.assertEqual(pixel(2, 2), INK_RGBA)
        self.assertEqual(pixel(5, 5), STEEL_RGBA)
        self.assertEqual(pixel(13, 13), INK_RGBA)
        self.assertEqual(pixel(14, 14), CLEAR)
        self.assertEqual(pixel(16, 15), INK_RGBA, "the second part starts at x=16")
        self.assertEqual(pixel(17, 15), CLEAR)
        self.assertEqual(pixel(18, 5), CLEAR, "nothing of the first part leaks into the second")

        described = json.loads(source.with_suffix(".json").read_text(encoding="utf-8"))
        self.assertEqual(
            described,
            {"category": "item", "width": 16, "height": 16, "pivot": [8, 15], "parts": ["a", "b"]},
        )

    def test_r3_bake_keeps_an_explicit_pivot(self) -> None:
        rows = outlined_square(16, 2, 13)
        source = self.write("one.px", px_text("item", "16x16", [("only", rows)], pivot="3,4"))
        art.bake_file(source, self.palette)
        described = json.loads(source.with_suffix(".json").read_text(encoding="utf-8"))
        self.assertEqual(described["pivot"], [3, 4])

    def test_r3_bake_is_deterministic(self) -> None:
        source = self.two_part_source()
        art.bake_file(source, self.palette)
        first = (source.with_suffix(".png").read_bytes(), source.with_suffix(".json").read_bytes())
        art.bake_file(source, self.palette)
        second = (source.with_suffix(".png").read_bytes(), source.with_suffix(".json").read_bytes())
        self.assertEqual(first, second)

    def test_r3_bake_all_bakes_every_source(self) -> None:
        self.two_part_source()
        self.write("sprites/deep/other.px", px_text("tile", "16x16", [("t", [STEEL * 16] * 16)]))
        baked = art.bake_all(self.assets, PALETTE_PATH)
        self.assertEqual(len(baked), 2)
        self.assertTrue((self.assets / "sprites" / "deep" / "other.png").exists())


class TestLint(ArtTestCase):
    def baked(self, relative: str, text: str) -> Path:
        source = self.write(relative, text)
        art.bake_file(source, self.palette)
        return source

    def item(self, rows: list[str], name: str = "x") -> str:
        return px_text("item", "16x16", [(name, rows)])

    def test_r4_lint_accepts_a_correct_sprite(self) -> None:
        self.baked("sprites/good.px", self.item(outlined_square(16, 0, 15)))
        self.baked("sprites/small.px", self.item(outlined_square(16, 4, 9)))
        self.assertEqual(self.lint(), [])

    def test_r4_lint_passes_with_no_assets(self) -> None:
        self.assertEqual(self.lint(), [])

    def test_r4_lint_rejects_off_palette_colour(self) -> None:
        self.baked("sprites/odd.px", self.item(outlined_square(16, 0, 15)))
        pixels = [CLEAR] * 256
        pixels[0] = (1, 2, 3, 255)
        self.write_png("sprites/odd.png", 16, 16, pixels)
        self.assert_one_problem_naming(self.lint(), "odd.png", "not in the palette")

    def test_r4_lint_rejects_half_transparent_pixel(self) -> None:
        self.baked("sprites/ghost.px", self.item(outlined_square(16, 0, 15)))
        pixels = [CLEAR] * 256
        pixels[0] = (*INK_RGBA[:3], 128)
        self.write_png("sprites/ghost.png", 16, 16, pixels)
        self.assert_one_problem_naming(self.lint(), "ghost.png", "transparent")

    def test_r4_lint_rejects_png_with_no_source(self) -> None:
        self.write_png("sprites/orphan.png", 16, 16, [CLEAR] * 256)
        self.assert_one_problem_naming(self.lint(), "orphan.png", "no .px source")

    def test_r4_lint_rejects_stale_png(self) -> None:
        source = self.baked("sprites/stale.px", self.item(outlined_square(16, 0, 15)))
        source.write_text(self.item(outlined_square(16, 2, 13)), encoding="utf-8")
        self.assert_one_problem_naming(self.lint(), "stale.png", "differs")

    def test_r4_lint_rejects_unreadable_png(self) -> None:
        self.baked("sprites/bad.px", self.item(outlined_square(16, 0, 15)))
        (self.assets / "sprites" / "bad.png").write_bytes(b"not a png at all")
        self.assert_one_problem_naming(self.lint(), "bad.png", "png")

    def test_r4_lint_rejects_unknown_symbol(self) -> None:
        rows = outlined_square(16, 0, 15)
        rows[5] = rows[5][:5] + "z" + rows[5][6:]
        self.write("sprites/sym.px", self.item(rows))
        self.assert_one_problem_naming(self.lint(), "sym.px", "unknown symbol")

    def test_r4_lint_rejects_ragged_rows(self) -> None:
        rows = outlined_square(16, 0, 15)
        rows[3] = rows[3][:-1]
        self.write("sprites/ragged.px", self.item(rows))
        self.assert_one_problem_naming(self.lint(), "ragged.px", "ragged")

    def test_r4_lint_rejects_wrong_grid_size(self) -> None:
        rows = outlined_square(16, 0, 15)[:15]
        self.write("sprites/short.px", self.item(rows))
        self.assert_one_problem_naming(self.lint(), "short.px", "grid")

    def test_r4_lint_rejects_missing_header_field(self) -> None:
        text = self.item(outlined_square(16, 0, 15)).replace("category = item\n", "")
        self.write("sprites/headless.px", text)
        self.assert_one_problem_naming(self.lint(), "headless.px", "category")

    def test_r4_lint_rejects_duplicate_part_name(self) -> None:
        square = outlined_square(16, 0, 15)
        self.write("sprites/twice.px", px_text("item", "16x16", [("a", square), ("a", square)]))
        self.assert_one_problem_naming(self.lint(), "twice.px", "duplicate part")

    def test_r4_lint_rejects_unknown_category(self) -> None:
        self.write("sprites/what.px", px_text("dragon", "16x16", [("x", outlined_square(16, 0, 15))]))
        self.assert_one_problem_naming(self.lint(), "what.px", "unknown category")

    def test_r4_lint_rejects_wrong_size(self) -> None:
        self.baked("sprites/big.px", px_text("item", "32x32", [("x", outlined_square(32, 0, 31))]))
        self.assert_one_problem_naming(self.lint(), "big.px", "size")

    def test_r4_lint_rejects_fx_over_64(self) -> None:
        self.baked("fx/huge.px", px_text("fx", "65x8", [("x", ["." * 65] * 8)]))
        self.assert_one_problem_naming(self.lint(), "huge.px", "size")

    def test_r4_lint_rejects_outline_gap(self) -> None:
        rows = outlined_square(16, 2, 13)
        rows[2] = rows[2][:6] + STEEL + rows[2][7:]  # a steel pixel on the top edge
        self.baked("sprites/gap.px", self.item(rows))
        problems = self.lint()
        self.assert_one_problem_naming(problems, "gap.px", "outline")
        self.assertTrue(any("6,2" in p for p in problems), f"names the pixel: {problems}")

    def test_r4_lint_rejects_outline_gap_at_canvas_edge(self) -> None:
        rows = outlined_square(16, 0, 15)
        rows[15] = rows[15][:8] + STEEL + rows[15][9:]
        self.baked("sprites/edge.px", self.item(rows))
        self.assert_one_problem_naming(self.lint(), "edge.px", "outline")

    def test_r5_tile_needs_no_outline(self) -> None:
        self.baked("tiles/dirt.px", px_text("tile", "16x16", [("dirt", [STEEL * 16] * 16)]))
        self.assertEqual(self.lint(), [])

    def test_r5_category_sizes(self) -> None:
        self.assertEqual(art.CATEGORIES["hero"], ((32, 32), True))
        self.assertEqual(art.CATEGORIES["monster_small"], ((24, 24), True))
        self.assertEqual(art.CATEGORIES["monster_large"], ((32, 32), True))
        self.assertEqual(art.CATEGORIES["boss"], ((64, 64), True))
        self.assertEqual(art.CATEGORIES["item"], ((16, 16), True))
        self.assertEqual(art.CATEGORIES["tile"], ((16, 16), False))
        self.assertEqual(art.CATEGORIES["fx"], (None, False))
        self.assertEqual(art.CATEGORIES["ui"], (None, False))


class TestCheck(unittest.TestCase):
    def test_r6_check_has_art_step(self) -> None:
        steps = list(dev.STEPS)
        self.assertIn("art", steps)
        self.assertEqual(steps.index("art"), steps.index("harness") + 1)

    def test_r6_repository_assets_pass_the_lint(self) -> None:
        self.assertEqual(art.lint(TOOLS.parent / "assets", PALETTE_PATH), [])


if __name__ == "__main__":
    unittest.main()
