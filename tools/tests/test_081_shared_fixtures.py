"""Spec 081 R4 and R5: tests stay clear of gdlint's file cap, and a helper is not copied a third time.

The R5 tests build a small git repository of made-up test scripts in a temporary folder and run
the harness step's checks on it; the others read this repository's own tests/.
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import dev  # noqa: E402

HELPER = "extends GutTest\n\n\nfunc test_{0}() -> void:\n\t_helper()\n\n\nfunc _helper() -> void:\n\tpass\n"
SCRIPTS = ("tests/unit/test_one.gd", "tests/unit/test_two.gd", "tests/acceptance/test_three.gd")


class SharedHelpers(unittest.TestCase):
    def setUp(self) -> None:
        self._folder = tempfile.TemporaryDirectory()
        self.root = Path(self._folder.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)

    def tearDown(self) -> None:
        self._folder.cleanup()

    def write(self, path: str, text: str) -> None:
        """Writes and tracks a file (a script with its .uid)."""
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8", newline="\n")
        added = [path]
        if path.endswith(".gd"):
            (self.root / (path + ".uid")).write_text("uid://made_up\n", encoding="utf-8")
            added.append(path + ".uid")
        subprocess.run(["git", "-C", str(self.root), "add", *added], check=True)

    def test_r5_a_third_copy_fails(self) -> None:
        for index, script in enumerate(SCRIPTS[:2]):
            self.write(script, HELPER.format(index))
        self.assertEqual(dev.harness_problems(self.root), [], "two copies are allowed")

        self.write(SCRIPTS[2], HELPER.format(2))
        problems = dev.harness_problems(self.root)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("_helper", problems[0])
        for script in SCRIPTS:
            self.assertIn(script, problems[0])

        # GUT's hooks and the tests themselves are every script's own.
        hooks = "".join(f"\n\nfunc {hook}() -> void:\n\tpass\n" for hook in dev.GUT_HOOKS)
        for index, script in enumerate(SCRIPTS):
            self.write(script, "extends GutTest\n\n\nfunc test_same() -> void:\n\tpass\n" + hooks)
        self.assertEqual(dev.harness_problems(self.root), [])

    def test_r5_an_allowed_name_passes(self) -> None:
        for index, script in enumerate(SCRIPTS):
            self.write(script, HELPER.format(index))
        self.assertEqual(len(dev.harness_problems(self.root)), 1)

        entry = {"reason": "each script's helper reads a different made-up thing"}
        allowed = {"_helper": {**entry, "scripts": list(SCRIPTS)}}
        self.write(dev.LOCAL_TEST_HELPERS, json.dumps(allowed))
        self.assertEqual(dev.harness_problems(self.root), [])

        # The entry names its scripts: a fourth defining the name is a copy like any other.
        self.write("tests/unit/test_four.gd", HELPER.format(4))
        problems = dev.harness_problems(self.root)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("_helper", problems[0])
        self.assertIn("tests/unit/test_four.gd", problems[0])
        for script in SCRIPTS:
            self.assertNotIn(script, problems[0])

    def test_r5_todays_tree_passes(self) -> None:
        allowed: dict[str, dict] = json.loads(
            (dev.ROOT / dev.LOCAL_TEST_HELPERS).read_text(encoding="utf-8")
        )
        shared = (
            "_before_guardian _build_hud _make_hud _step_until _frame _play_frame _click_at _click"
            " _ticks _collect_labels _of_kind _spend_talents _through_json"
        ).split()
        for name in shared:
            self.assertNotIn(name, allowed, "a copied helper the spec shares is not allowed")
        for name, entry in allowed.items():
            self.assertTrue(entry["reason"].strip(), f"{name} is allowed with its reason")
            self.assertGreater(len(entry["scripts"]), dev.MAX_HELPER_COPIES, f"{name} names its scripts")
            for script in entry["scripts"]:
                self.assertTrue((dev.ROOT / script).is_file(), f"{name}: {script} exists")

    def test_r4_no_test_file_is_near_the_cap(self) -> None:
        for path in sorted((dev.ROOT / "tests").rglob("*.gd")):
            lines = len(path.read_text(encoding="utf-8").splitlines())
            self.assertLess(
                lines,
                dev.MAX_FILE_LINES - dev.FILE_LINES_WARNING,
                f"{path.relative_to(dev.ROOT).as_posix()} has {lines} lines",
            )


if __name__ == "__main__":
    unittest.main()
