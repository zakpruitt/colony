"""Acceptance tests for spec 058 (a sharp UI layer and windows), requirement R9: the shot's size.

`python tools/dev.py shot` saves the whole composed window at 1280x720, and with `--ui-room=960x540` as a
1920x1080 window shows it. The size arithmetic is checked everywhere; the real shot needs a display (it
opens a window), so it is skipped where there is none, as on CI.

Run: python -m unittest discover tools/tests   (the `art` check step runs it too)
"""

from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOOLS))

import dev  # noqa: E402

ROOT = TOOLS.parent
SHOTS = ROOT / ".shots"


def has_display() -> bool:
    """True where Godot can open a real window."""
    if sys.platform in ("win32", "darwin"):
        return True
    return bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))


class ShotSize(unittest.TestCase):
    def test_the_room_for_each_window(self) -> None:
        # As UiRoot.room_for works it out (spec 058 R1).
        self.assertEqual(dev.ui_room_for((1280, 720)), (1280, 720))
        self.assertEqual(dev.ui_room_for((1920, 1080)), (960, 540))
        self.assertEqual(dev.ui_room_for((2560, 1440)), (1280, 720))
        self.assertEqual(dev.ui_room_for((3840, 2160)), (960, 540))

    def test_the_window_for_each_room(self) -> None:
        self.assertEqual(dev.shot_window("1280x720"), (1280, 720), "the default room: a 1280x720 window")
        self.assertEqual(dev.shot_window("960x540"), (1920, 1080), "960x540: a 1920x1080 window")
        for bad in ("960", "960x", "big", "100x100"):
            with self.assertRaises(dev.StepFailed, msg=bad):
                dev.shot_window(bad)

    def test_the_command_takes_the_room(self) -> None:
        parser = dev.build_parser()
        self.assertEqual(parser.parse_args(["shot"]).ui_room, "1280x720", "1280x720 unless told")
        self.assertEqual(parser.parse_args(["shot", "--ui-room=960x540"]).ui_room, "960x540")


@unittest.skipUnless(has_display(), "a real shot needs a display")
class RealShot(unittest.TestCase):
    """Takes real shots of the main scene and reads their size back."""

    def shot(self, *extra: str) -> tuple[int, int]:
        name = f"test_058_shot_{os.getpid()}"
        path = SHOTS / f"{name}.png"
        try:
            command = [sys.executable, str(TOOLS / "dev.py"), "shot", f"--name={name}", "--seconds=1"]
            done = subprocess.run(
                [*command, *extra], cwd=ROOT, capture_output=True, text=True, timeout=180, check=False
            )
            self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
            self.assertTrue(path.exists(), done.stdout)
            header = path.read_bytes()[:24]  # the signature, then the IHDR chunk: width, height
            self.assertEqual(header[12:16], b"IHDR", "a PNG")
            return int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")
        finally:
            path.unlink(missing_ok=True)

    def test_the_whole_window_at_1280x720(self) -> None:
        self.assertEqual(self.shot(), (1280, 720))

    def test_as_a_1920x1080_window_shows_it(self) -> None:
        self.assertEqual(self.shot("--ui-room=960x540"), (1920, 1080))


if __name__ == "__main__":
    unittest.main()
