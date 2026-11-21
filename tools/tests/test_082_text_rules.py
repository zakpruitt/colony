"""Acceptance tests for spec 082 (text rules live in the harness), R1, R2 and R6.

Each R1 and R2 test builds a small git repository of made-up scripts in a temporary folder and
runs the harness step's rules on it. R3 to R5 are the pull request's list of tests removed.

Run: python -m unittest discover tools/tests   (the `art` check step runs it too)
"""

from __future__ import annotations

import contextlib
import io
import sys
import unittest
from pathlib import Path
from unittest import mock

TOOLS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import dev  # noqa: E402
from test_077_a_faster_check import TempTree  # noqa: E402

KEY_BOOK = (
    "class_name KeyBook\n"
    "extends RefCounted\n"
    "\n"
    "\n"
    "static func fresh_key(event: InputEvent) -> InputEventKey:\n"
    "\tvar key := event as InputEventKey\n"
    "\tif key == null or not key.pressed or key.echo:\n"
    "\t\treturn null\n"
    "\treturn key\n"
)
ASKS_KEY_BOOK = (
    "extends Node\n"
    "\n"
    "\n"
    "func _unhandled_input(event: InputEvent) -> void:\n"
    "\tif KeyBook.pressed(event, KEY_G):\n"
    "\t\tvisible = not visible\n"
)
# The guard as it was written by hand before KeyBook: the echo read on line 6.
READS_ECHO = (
    "extends Node\n"
    "\n"
    "\n"
    "func _unhandled_input(event: InputEvent) -> void:\n"
    "\tvar key := event as InputEventKey\n"
    "\tif key != null and key.pressed and not key.echo and key.keycode == KEY_G:\n"
    "\t\tvisible = not visible\n"
)
# A label coloured by hand, the call on line 6.
COLOURS_BY_HAND = (
    "extends Control\n"
    "\n"
    "\n"
    "func _ready() -> void:\n"
    "\tvar label := Label.new()\n"
    '\tlabel.add_theme_color_override("font_color", Palette.color(&"silver"))\n'
    "\tadd_child(label)\n"
)
# The same call as gdformat wraps a long one: it opens on line 5, its name is on line 6.
COLOURS_WRAPPED = (
    "extends Control\n"
    "\n"
    "\n"
    "func _show(label: Label, down: bool) -> void:\n"
    "\tlabel.add_theme_color_override(\n"
    '\t\t&"font_color", Palette.color(&"red") if down else Palette.color(&"silver")\n'
    "\t)\n"
)
ONLY_COMMENTS = (
    "extends Control\n"
    "## Never reads key.echo: KeyBook does.\n"
    "\n"
    "var shown: int = 0  # set with WindowText, not label.add_theme_color_override(\"font_color\", c)\n"
    "\n"
    "\n"
    "func _ready() -> void:\n"
    '\t# label.add_theme_color_override("font_color", Palette.color(&"silver"))\n'
    "\t# if key.echo:\n"
    "\tshown += 1\n"
)
A_TEST = "extends {0}\n## A made-up test.\n\n\nfunc test_one() -> void:\n\tassert_true(true)\n"


def functions(public: int, private: int = 0, static: int = 0) -> str:
    """A script with this many public, private and static functions."""
    text = "extends CanvasLayer\n"
    names = [f"shown_{n}" for n in range(public)] + [f"_made_{n}" for n in range(private)]
    for name in names:
        text += f"\n\nfunc {name}() -> void:\n\tpass\n"
    for n in range(static):
        text += f"\n\nstatic func word_{n}() -> String:\n\treturn \"\"\n"
    return text


def lines(count: int) -> str:
    """A script of exactly [count] lines."""
    return "extends RefCounted\n" + "var a: int = 1\n" * (count - 1)


class TextRules(TempTree):
    def fails_the_step(self) -> None:
        with self.assertRaises(dev.StepFailed), contextlib.redirect_stdout(io.StringIO()):
            dev.step_harness(self.root)

    def test_r1_an_echo_read_outside_key_book_fails(self) -> None:
        self.write("game/ui/key_book.gd", KEY_BOOK)
        self.write("game/hud/goals.gd", ASKS_KEY_BOOK)
        # Only game/ is held to it.
        self.write("tools/godot/shot.gd", READS_ECHO)
        self.assertEqual(dev.rule_problems(self.root), [], "KeyBook reads it, the rest ask KeyBook")

        self.write("game/world/world.gd", READS_ECHO)
        problems = dev.rule_problems(self.root)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("game/world/world.gd:6:", problems[0])
        self.assertIn("KeyBook.pressed", problems[0], "it says what to do instead")
        self.fails_the_step()

    def test_r1_a_font_colour_set_by_hand_fails(self) -> None:
        self.write("game/ui/windows/window_text.gd", COLOURS_BY_HAND)
        # The developers' scenes outside the UI's code set their own.
        self.write("game/art/gallery.gd", COLOURS_BY_HAND)
        self.write("game/entities/character_demo.gd", COLOURS_BY_HAND)
        other = COLOURS_BY_HAND.replace('"font_color"', '"font_outline_color"')
        self.write("game/ui/ui_tip.gd", other)
        self.assertEqual(dev.rule_problems(self.root), [], "the setter, and another colour")

        places = {
            "game/hud/goals.gd": (COLOURS_BY_HAND, 6),
            "game/ui/frame/purse.gd": (COLOURS_WRAPPED, 5),
            "game/effects/fx_text.gd": (COLOURS_BY_HAND, 6),
            "game/save/away_window.gd": (COLOURS_BY_HAND, 6),
            "game/main.gd": (COLOURS_BY_HAND, 6),
        }
        for path, (text, _line) in places.items():
            self.write(path, text)
        problems = dev.rule_problems(self.root)
        self.assertEqual(len(problems), len(places), problems)
        for path, (_text, line) in places.items():
            named = [problem for problem in problems if problem.startswith(f"{path}:{line}:")]
            self.assertEqual(len(named), 1, f"{path}:{line} in {problems}")
            self.assertIn("WindowText.set_colour", named[0], "it says what to do instead")
        self.fails_the_step()

    def test_r1_a_comment_does_not_count(self) -> None:
        self.write("game/hud/hud.gd", ONLY_COMMENTS)
        self.write("game/main.gd", ONLY_COMMENTS)
        self.assertEqual(dev.rule_problems(self.root), [])

    def test_r1_a_test_script_off_the_base_fails(self) -> None:
        fixture = "res://tests/support/main_fixture.gd"
        base = "res://tests/acceptance/made_up_test_base.gd"
        self.write("tests/colony_test.gd", "class_name ColonyTest\nextends GutTest\n")
        self.write("tests/support/main_fixture.gd", "extends ColonyTest\n")
        self.write("tests/unit/test_direct.gd", A_TEST.format("ColonyTest"))
        self.write("tests/acceptance/test_on_a_fixture.gd", A_TEST.format(f'"{fixture}"'))
        self.write("tests/acceptance/made_up_test_base.gd", f'## A base.\nextends "{fixture}"\n')
        self.write("tests/acceptance/test_on_a_base.gd", A_TEST.format(f'"{base}"'))
        self.assertEqual(dev.rule_problems(self.root), [], "by name, by a fixture, by a base")

        # Straight onto GUT, and onto a base that never reaches ColonyTest.
        self.write("tests/unit/test_off.gd", A_TEST.format("GutTest"))
        self.write("tests/acceptance/off_test_base.gd", "## A base.\nextends GutTest\n")
        off = "res://tests/acceptance/off_test_base.gd"
        self.write("tests/acceptance/test_far_off.gd", A_TEST.format(f'"{off}"'))
        problems = dev.rule_problems(self.root)
        self.assertEqual(len(problems), 3, problems)
        joined = "\n".join(problems)
        for where in (
            "tests/unit/test_off.gd:1:",
            "tests/acceptance/off_test_base.gd:2:",
            "tests/acceptance/test_far_off.gd:1:",
        ):
            self.assertIn(where, joined)
        for problem in problems:
            self.assertIn("ColonyTest", problem, "it says what to do instead")
        self.fails_the_step()


class Caps(TempTree):
    OVER = {
        "sim/expedition/expedition.gd": lines(901),
        "game/effects/combat_effects.gd": lines(751),
        "game/dev/showcase.gd": lines(751),
    }

    def test_r2_a_file_over_its_cap_fails(self) -> None:
        for path, text in self.OVER.items():
            with self.subTest(path=path):
                self.write(path, text)
                problems = dev.cap_problems(self.root)
                self.assertEqual(len(problems), 1, problems)
                self.assertIn(path, problems[0])
                count = len(text.splitlines())
                self.assertIn(f"{count} lines", problems[0])
                self.assertIn(str(count - 1), problems[0], "the cap is named")
                with self.assertRaises(dev.StepFailed), contextlib.redirect_stdout(io.StringIO()):
                    dev.step_harness(self.root)
                self.write(path, lines(count - 1))
                self.assertEqual(dev.cap_problems(self.root), [])

    def test_r2_a_class_over_its_methods_fails(self) -> None:
        self.write("game/hud/hud.gd", functions(16))
        problems = dev.cap_problems(self.root)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("game/hud/hud.gd", problems[0])
        self.assertIn("16 public methods", problems[0])
        self.assertIn("15", problems[0], "the cap is named")
        with self.assertRaises(dev.StepFailed), contextlib.redirect_stdout(io.StringIO()):
            dev.step_harness(self.root)

    def test_r2_at_the_cap_passes(self) -> None:
        for path, text in self.OVER.items():
            self.write(path, lines(len(text.splitlines()) - 1))
        # Private and static functions are not counted, as gdlint does not count them.
        self.write("game/hud/hud.gd", functions(15, private=30, static=4))
        # Another script is held to gdlint's caps alone.
        self.write("game/hud/goals.gd", lines(950))
        self.write("game/ui/ui_root.gd", functions(18))
        self.assertEqual(dev.cap_problems(self.root), [])
        self.commit("feat: files at their caps")
        with contextlib.redirect_stdout(io.StringIO()):
            dev.step_harness(self.root)

        # A new cap is a row of the table.
        row = ("game/ui/ui_root.gd", dev.PUBLIC_METHODS, 17)
        with mock.patch.object(dev, "CAPS", (*dev.CAPS, row)):
            problems = dev.cap_problems(self.root)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("game/ui/ui_root.gd", problems[0])


class ArtStep(unittest.TestCase):
    def test_r6_the_art_step_runs_the_tool_tests_once(self) -> None:
        commands: list[list[str]] = []

        def run(command: list[str], timeout: int) -> tuple[int, str]:
            commands.append(list(command))
            return 0, "Ran 7 tests\n\nOK\n"

        with mock.patch.object(dev, "run", run):
            summary = dev.step_art()
        tests = [command for command in commands if "unittest" in command]
        self.assertEqual(len(tests), 1, commands)
        self.assertIn("tools/tests", tests[0])
        self.assertIn("7 tool tests", summary)


if __name__ == "__main__":
    unittest.main()
