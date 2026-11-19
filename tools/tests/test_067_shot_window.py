"""Acceptance test for spec 067 (opens at a size you can read), requirement R5: tools are unchanged.

`python tools/dev.py shot` tells the game to leave its window as the project opens it
(`--window-default`), so a shot is never of a maximized window or of one as the player left it, and
runs it by a script, which keeps the window's settings file out of it. The game's side
(`WindowSettings.wanted`) is tested in tests/acceptance/test_067_opens_at_a_size_you_can_read.gd.

Run: python -m unittest discover tools/tests   (the `art` check step runs it too)
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOOLS))

import dev  # noqa: E402


class ShotWindow(unittest.TestCase):
    def command(self, *options: str) -> list[str]:
        try:
            return dev.shot_command(dev.build_parser().parse_args(["shot", *options]), "out/shot")
        except dev.StepFailed as failure:  # no Godot on this machine: the test cannot say
            self.skipTest(str(failure))

    def test_r5_a_shot_leaves_the_window_as_the_project_opens_it(self) -> None:
        for options in ([], ["--ui-room=960x540"], ["--scene=res://game/art/gallery.tscn"]):
            command = self.command(*options)
            told = command[command.index("--") + 1 :]
            self.assertIn("--window-default", told, f"{options}: told to the game")
            self.assertIn("-s", command[: command.index("--")], f"{options}: run by a script")
            self.assertNotIn("--headless", command, f"{options}: still in a real window")

    def test_r5_a_shot_is_the_size_it_was(self) -> None:
        self.assertIn("--window=1280x720", self.command())
        self.assertIn("--window=1920x1080", self.command("--ui-room=960x540"))


if __name__ == "__main__":
    unittest.main()
