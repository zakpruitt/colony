"""Spec 071 R5: the `harness` step of `python tools/dev.py check`.

Each test builds a small git repository of made-up scripts in a temporary folder and runs the
step's checks on it.
"""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import dev  # noqa: E402

WRITES = 'extends GutTest\n\nvar _path: String = "user://made_up_%d.save" % OS.get_process_id()\n'
CLEANS = "\n\nfunc after_all() -> void:\n\tpass\n"


class HarnessCheck(unittest.TestCase):
    def setUp(self) -> None:
        self._folder = tempfile.TemporaryDirectory()
        self.root = Path(self._folder.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)

    def tearDown(self) -> None:
        self._folder.cleanup()

    def write(self, path: str, text: str, uid: bool = True) -> None:
        """Writes and tracks a script, with its .uid unless [uid] is false."""
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8", newline="\n")
        added = [path]
        if uid:
            (self.root / (path + ".uid")).write_text("uid://made_up\n", encoding="utf-8")
            added.append(path + ".uid")
        subprocess.run(["git", "-C", str(self.root), "add", *added], check=True)

    def problems(self) -> list[str]:
        return dev.harness_problems(self.root)

    def test_r5_a_test_writing_files_without_after_all_fails(self) -> None:
        self.write("tests/unit/test_writes.gd", WRITES)
        problems = self.problems()
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("tests/unit/test_writes.gd", problems[0])
        self.assertIn("after_all", problems[0])

        # It passes once it has one.
        self.write("tests/unit/test_writes.gd", WRITES + CLEANS)
        self.assertEqual(self.problems(), [])

        # Or once it extends a base that has one, by path or by class name.
        self.write("tests/made_up_base.gd", "class_name MadeUpBase\nextends GutTest\n" + CLEANS)
        self.write("tests/unit/test_writes.gd", WRITES.replace("GutTest", "MadeUpBase"))
        self.assertEqual(self.problems(), [])
        self.write("tests/unit/mid_test_base.gd", 'extends "res://tests/made_up_base.gd"\n')
        mid = WRITES.replace("GutTest", '"res://tests/unit/mid_test_base.gd"')
        self.write("tests/unit/test_writes.gd", mid)
        self.assertEqual(self.problems(), [])

        # A base without one does not count.
        self.write("tests/unit/mid_test_base.gd", "extends GutTest\n")
        problems = self.problems()
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("tests/unit/test_writes.gd", problems[0])

    def test_r5_a_script_without_its_uid_fails(self) -> None:
        self.write("game/made_up.gd", "extends Node\n", uid=False)
        problems = self.problems()
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("game/made_up.gd", problems[0])
        self.assertIn(".uid", problems[0])

        self.write("game/made_up.gd", "extends Node\n")
        self.assertEqual(self.problems(), [])

    def test_the_step_is_in_the_check(self) -> None:
        self.assertIn("harness", dev.STEPS)
        self.assertEqual(dev.STEPS["harness"], dev.step_harness)


if __name__ == "__main__":
    unittest.main()
