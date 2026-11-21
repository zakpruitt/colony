"""Acceptance tests for spec 021 (sound effects), R1: recipes bake to WAVs and the lint checks them.

Run: python -m unittest discover tools/tests   (the `art` check step runs it too)
"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

TOOLS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOOLS))

import dev  # noqa: E402
import sfx  # noqa: E402

GOOD = """
# a short blip
[blip]
wave = square
duty = 0.25
pitch = 880
slide = 1320
length = 0.1
volume = 0.4
"""

LONG = """
[drone]
wave = triangle
pitch = 220
length = 1.5
volume = 0.3
"""

LOUD = """
[shout]
wave = square
pitch = 440
length = 0.2
volume = 1.0
"""


class R1BakeAndLint(unittest.TestCase):
    def setUp(self) -> None:
        self._dir = tempfile.TemporaryDirectory()
        self.folder = Path(self._dir.name)

    def tearDown(self) -> None:
        self._dir.cleanup()

    def recipe(self, name: str, text: str) -> Path:
        path = self.folder / f"{name}.sfx"
        path.write_text(text, encoding="utf-8")
        return path

    def test_r1_bake_and_lint(self) -> None:
        good = self.recipe("good", GOOD)
        first = sfx.bake_file(good).read_bytes()
        second = sfx.bake_file(good).read_bytes()
        self.assertEqual(first, second, "baking twice gives identical bytes")
        rate, samples = sfx.decode_wav(first)
        self.assertEqual(rate, sfx.SAMPLE_RATE)
        self.assertAlmostEqual(len(samples) / rate, 0.1, places=3)
        self.assertEqual(sfx.lint(self.folder), [], "a fresh, short, quiet sound passes")

        missing = self.recipe("missing", GOOD)
        problems = sfx.lint(self.folder)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("missing.wav", problems[0])
        self.assertIn("missing", problems[0])
        sfx.bake_file(missing)

        stale = self.recipe("stale", GOOD)
        sfx.bake_file(stale)
        stale.write_text(GOOD.replace("880", "660"), encoding="utf-8")
        problems = sfx.lint(self.folder)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("stale.wav", problems[0])
        self.assertIn("stale", problems[0])
        sfx.bake_file(stale)

        sfx.bake_file(self.recipe("long", LONG))
        problems = sfx.lint(self.folder)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("long.wav", problems[0])
        self.assertIn("too long", problems[0])
        (self.folder / "long.sfx").unlink()
        (self.folder / "long.wav").unlink()

        sfx.bake_file(self.recipe("loud", LOUD))
        problems = sfx.lint(self.folder)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("loud.wav", problems[0])
        self.assertIn("too loud", problems[0])

    def test_every_part_starts_and_ends_at_silence(self) -> None:
        samples = sfx.render(sfx.parse_sfx(GOOD))
        self.assertLess(abs(samples[0]), 0.01)
        self.assertEqual(samples[-1], 0.0)

    def test_a_malformed_recipe_is_named(self) -> None:
        self.recipe("bad", "[x]\nwave = kazoo\n")
        problems = sfx.lint(self.folder)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("bad.sfx", problems[0])
        self.assertIn("malformed", problems[0])

    def test_the_art_step_runs_the_sfx_lint(self) -> None:
        commands: list[list[str]] = []

        def run(command: list[str], timeout: int) -> tuple[int, str]:
            commands.append(list(command))
            return 0, "Ran 7 tests\n\nOK\n"

        with mock.patch.object(dev, "run", run):
            dev.step_art()
        lints = [command for command in commands if command[-2:] == ["tools/sfx.py", "lint"]]
        self.assertEqual(len(lints), 1, f"the art step runs the sfx lint: {commands}")


if __name__ == "__main__":
    unittest.main()
