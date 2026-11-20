"""Acceptance tests for spec 058 (a sharp UI layer and windows), requirement R9: the shot's size.

Takes real shots of the main scene and reads their size back. A shot needs a display (it opens a
window), so it is skipped where there is none, as on CI. The size arithmetic is checked without
Godot in tools/tests/test_058_shot.py.

Run: python -m unittest discover tools/tests/godot   (the `tools` check step runs it too)
"""

from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[2]
ROOT = TOOLS.parent
SHOTS = ROOT / ".shots"


def has_display() -> bool:
    """True where Godot can open a real window."""
    if sys.platform in ("win32", "darwin"):
        return True
    return bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))


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
