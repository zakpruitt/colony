"""Acceptance tests for spec 082 (text rules live in the harness), R1, R2 and R6.

Each R1 and R2 test builds a small git repository of made-up scripts in a temporary folder and
runs the harness step's rules on it. R3 to R5 are the pull request's list of tests removed.

Run: python -m unittest discover tools/tests   (the `art` check step runs it too)
"""

from __future__ import annotations

import contextlib
import io
import os
import subprocess
import sys
import tempfile
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
# The same guard through the event's method: is_echo() on line 5.
ASKS_IS_ECHO = (
    "extends Node\n"
    "\n"
    "\n"
    "func _unhandled_input(event: InputEvent) -> void:\n"
    "\tif event.is_pressed() and not event.is_echo() and event.is_action(&\"ui_cancel\"):\n"
    "\t\tvisible = false\n"
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

        self.write("game/world/world.gd", ASKS_KEY_BOOK)
        self.write("game/ui/ui_windows.gd", ASKS_IS_ECHO)
        problems = dev.rule_problems(self.root)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("game/ui/ui_windows.gd:5:", problems[0], "is_echo() is a read too")
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


# A tool test put among those that need no Godot, which starts Godot and wants it to work.
STARTS_GODOT = (
    "import sys\n"
    "import unittest\n"
    "\n"
    "sys.path.insert(0, {tools!r})\n"
    "import dev\n"
    "\n"
    "\n"
    "class StartsGodot(unittest.TestCase):\n"
    "    def test_the_version_prints(self) -> None:\n"
    "        code, output = dev.godot(['--version'], timeout=60)\n"
    "        self.assertEqual(code, 0, output)\n"
)


class ArtStep(unittest.TestCase):
    def setUp(self) -> None:
        self._folder = tempfile.TemporaryDirectory()
        self.folder = Path(self._folder.name)
        tests = self.folder / "tests"
        tests.mkdir()
        (tests / "test_starts_godot.py").write_text(
            STARTS_GODOT.format(tools=str(TOOLS)), encoding="utf-8"
        )
        self.tests = tests
        # A Godot that does what it is asked, so the made-up test passes wherever Godot is real.
        if os.name == "nt":
            self.godot = self.folder / "godot.cmd"
            self.godot.write_text("@exit /b 0\r\n", encoding="utf-8")
        else:
            self.godot = self.folder / "godot"
            self.godot.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            self.godot.chmod(0o755)

    def tearDown(self) -> None:
        self._folder.cleanup()

    def run_tool_tests(
        self, command: list[str], timeout: int, env: dict[str, str] | None = None
    ) -> tuple[int, str]:
        """The art step's tool tests run for real on the made-up folder, with the environment
        the step gives them; its lints pass untouched."""
        if "unittest" not in command:
            return 0, "ok\n"
        self.runs += 1
        folder = str(self.tests)
        command = [folder if part == "tools/tests" else part for part in command]
        done = subprocess.run(
            command,
            cwd=dev.ROOT,
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, "GODOT": str(self.godot), **(env or {})},
            check=False,
        )
        return done.returncode, done.stdout + done.stderr

    def test_r6_a_tool_test_that_starts_godot_fails_the_art_step(self) -> None:
        # Outside the step, the made-up test passes: its Godot works.
        self.runs = 0
        python = sys.executable or "python"
        discover = [python, "-m", "unittest", "discover", "-s", "tools/tests", "-t", "tools/tests"]
        code, output = self.run_tool_tests(discover, 120)
        self.assertEqual(code, 0, output)

        self.runs = 0
        with mock.patch.object(dev, "run", self.run_tool_tests):
            with self.assertRaises(dev.StepFailed) as failed:
                dev.step_art()
        self.assertEqual(self.runs, 1, "the tool tests ran once")
        self.assertIn("test_the_version_prints", str(failed.exception))


ESC = "\x1b"
# GUT's output for two scripts, as the tests step reads it; {risky} and {pending} are the lines
# GUT prints under a test that made no assert or called pending(), or nothing.
GUT_OUTPUT = (
    "res://tests/acceptance/test_one.gd\n"
    "* test_a_frame_moves\n"
    "* test_handlers_have_one_name\n"
    "{risky}"
    "2/2 passed.\n"
    "res://tests/unit/test_two.gd\n"
    "* test_waits_for_later\n"
    "{pending}"
    "* test_saves\n"
    f"{ESC}[1m2/2 passed.\n"
    f"{ESC}[33m==============================================\n"
    f"{ESC}[0m{ESC}[33m= Run Summary\n"
    f"{ESC}[0m{ESC}[33m==============================================\n"
    "{summary}"
    "Totals\n"
    "------\n"
    "Scripts               2\n"
    "Tests                 4\n"
    "Passing Tests         {passing}\n"
    "{totals}"
    "Asserts             120\n"
)
RISKY = f"{ESC}[33m    [Risky]:  {ESC}[0mtest_handlers_have_one_name did not assert\n"
PENDING = f"{ESC}[33m    [Pending]:  {ESC}[0mnot yet\n"


def gut_output(risky: bool, pending: bool) -> str:
    """GUT_OUTPUT with a risky test in the first script, a pending one in the second, or neither."""
    summary = ""
    if risky:
        summary += f"{ESC}[0m- test_handlers_have_one_name\n{ESC}[33m    [Risky]:  Did not assert\n"
    if pending:
        summary += f"{ESC}[0m- test_waits_for_later\n{ESC}[33m    [Pending]:  not yet\n"
    unasserted = int(risky) + int(pending)
    return GUT_OUTPUT.format(
        risky=RISKY if risky else "",
        pending=PENDING if pending else "",
        summary=summary,
        passing=4 - unasserted,
        totals=f"Risky/Pending         {unasserted}\n" if unasserted else "",
    )


class TestsStep(unittest.TestCase):
    def step(self, output: str) -> str:
        """The tests step's verdict on GUT's [output], Godot itself not started."""
        with (
            mock.patch.object(dev, "godot", lambda args, timeout: (0, output)),
            mock.patch.object(dev, "ensure_imported", lambda: None),
        ):
            return dev.step_tests()

    def test_r8_a_test_without_an_assert_fails_the_tests_step(self) -> None:
        self.assertEqual(self.step(gut_output(False, False)), "4 passing")

        with self.assertRaises(dev.StepFailed) as failed:
            self.step(gut_output(True, False))
        message = str(failed.exception)
        self.assertIn("res://tests/acceptance/test_one.gd::test_handlers_have_one_name", message)
        self.assertNotIn("test_a_frame_moves", message)
        self.assertNotIn("test_saves", message)

        with self.assertRaises(dev.StepFailed) as failed:
            self.step(gut_output(False, True))
        self.assertIn("res://tests/unit/test_two.gd::test_waits_for_later", str(failed.exception))

        with self.assertRaises(dev.StepFailed) as failed:
            self.step(gut_output(True, True))
        message = str(failed.exception)
        self.assertIn("test_handlers_have_one_name", message)
        self.assertIn("test_waits_for_later", message)


if __name__ == "__main__":
    unittest.main()
