"""Acceptance tests for spec 077 (a faster check that holds the standards).

R2 is shown by the pull request's own five green jobs; R8 and R9 by the reviewer.

Run: python -m unittest discover tools/tests   (the `art` check step runs it too)
"""

from __future__ import annotations

import argparse
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

import dev  # noqa: E402

ROOT = TOOLS.parent

# Set while this file's R4 test runs the art step, whose tool tests include this file again.
INSIDE_ART_STEP = "COLONY_TEST_077_INSIDE_ART_STEP"


def git(root: Path, *args: str) -> str:
    done = subprocess.run(
        ["git", "-C", str(root), "-c", "user.name=t", "-c", "user.email=t@t", *args],
        capture_output=True,
        text=True,
        check=True,
    )
    return done.stdout.strip()


class Shards(unittest.TestCase):
    def test_r1_every_script_is_in_one_shard(self) -> None:
        every = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "tests").rglob("test_*.gd"))
        self.assertGreater(len(every), 50, "the suite's scripts were found")
        self.assertEqual(sorted(dev.test_scripts()), every)
        for count in (1, 3, 4):
            seen: list[str] = []
            for index in range(1, count + 1):
                part = dev.shard_scripts(every, index, count)
                self.assertTrue(part, f"shard {index}/{count} has scripts")
                self.assertEqual(part, dev.shard_scripts(list(reversed(every)), index, count))
                seen += part
            self.assertEqual(sorted(seen), every, f"N={count}: every script once")
            self.assertEqual(len(seen), len(set(seen)), f"N={count}: no script twice")

    def test_r1_a_bad_shard_is_refused(self) -> None:
        for shard in ("0/4", "5/4", "x"):
            done = subprocess.run(
                [sys.executable, str(TOOLS / "dev.py"), "test", f"--shard={shard}"],
                cwd=ROOT,
                capture_output=True,
                text=True,
                timeout=60,
                check=False,
            )
            self.assertNotEqual(done.returncode, 0, shard)
            self.assertIn("shard", (done.stdout + done.stderr).lower(), shard)


class FakeGodot:
    """Stands in for Godot: records each run and reports a clean one."""

    def __init__(self) -> None:
        self.calls: list[list[str]] = []

    def __call__(self, args: list[str], timeout: int) -> tuple[int, str]:
        self.calls.append(list(args))
        return 0, "Passing Tests 3\n"

    def imports(self) -> int:
        return sum(1 for call in self.calls if "--import" in call)


class Imports(unittest.TestCase):
    def check(self, only: str | None) -> int:
        fake = FakeGodot()
        real_run = dev.run

        def run(command: list[str], timeout: int) -> tuple[int, str]:
            if command[0] == "git":
                return real_run(command, timeout)
            return 0, "Ran 7 tests\n\nOK\n"

        quiet = {name: (lambda: "stub") for name in ("format", "boundary", "harness", "art")}
        with (
            mock.patch.dict(os.environ),
            mock.patch.dict(dev.STEPS, quiet),
            mock.patch.object(dev, "godot", fake),
            mock.patch.object(dev, "run", run),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            os.environ.pop(dev.IMPORTED, None)
            code = dev.command_check(argparse.Namespace(only=only))
        self.assertEqual(code, 0, only)
        return fake.imports()

    def test_r3_a_check_imports_once(self) -> None:
        self.assertEqual(self.check(None), 1, "the whole check")
        self.assertEqual(self.check("compile,tools,tests,data,boot"), 1)
        for step in ("compile", "tools", "tests", "data", "boot"):
            self.assertEqual(self.check(step), 1, f"{step} alone imports for itself")
        self.assertEqual(self.check("format,boundary,harness,art"), 0, "nothing needs Godot")


class ArtStep(unittest.TestCase):
    def test_r4_art_starts_no_godot(self) -> None:
        if os.environ.get(INSIDE_ART_STEP):
            self.skipTest("already inside the art step this test runs")

        def no_godot(args: list[str], timeout: int) -> tuple[int, str]:
            raise AssertionError(f"the art step started Godot: {args}")

        # The tool tests run in a child process, which finds Godot through GODOT: a Python that
        # fails on Godot's arguments.
        with (
            mock.patch.dict(os.environ, {"GODOT": sys.executable, INSIDE_ART_STEP: "1"}),
            mock.patch.object(dev, "godot", no_godot),
        ):
            summary = dev.step_art()
        self.assertIn("tool tests", summary)
        self.assertIn("tools", dev.STEPS)
        names = list(dev.STEPS)
        self.assertEqual(names.index("tools"), names.index("compile") + 1, "tools follows compile")


class TempTree(unittest.TestCase):
    def setUp(self) -> None:
        self._folder = tempfile.TemporaryDirectory()
        self.root = Path(self._folder.name)
        git(self.root, "init", "-q")

    def tearDown(self) -> None:
        self._folder.cleanup()

    def write(self, path: str, text: str) -> None:
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8", newline="\n")
        added = [path]
        if path.endswith(".gd"):
            (self.root / (path + ".uid")).write_text("uid://made_up\n", encoding="utf-8")
            added.append(path + ".uid")
        git(self.root, "add", *added)

    def commit(self, message: str) -> str:
        git(self.root, "commit", "-q", "--allow-empty", "-m", message)
        return git(self.root, "rev-parse", "--short", "HEAD")


class Comments(TempTree):
    def test_r5_a_spec_number_in_a_comment_fails(self) -> None:
        clean = (
            "extends Node\n"
            "## The events recorded since the last call, oldest first.\n"
            'var a: String = "# spec 12"  # a hash inside a string\n'
        )
        self.write("sim/clean.gd", clean)
        self.write("tools/clean.py", '"""A tool."""\n\n# Spaces, not tabs.\nX = "# spec 9"\n')
        self.assertEqual(dev.comment_problems(self.root), [])

        self.write("sim/said.gd", "extends Node\n\nvar a: int = 1  # as spec 12 says\n")
        self.write("game/wrapped.gd", "extends Node\n## Held to what the spec\n## 12 asks for.\n")
        self.write("tools/history.py", "X = 1\n# since the old way\n")
        self.write("tests/colony_test.gd", "extends GutTest\n# R14: a rule\n")
        problems = dev.comment_problems(self.root)
        self.assertEqual(len(problems), 4, problems)
        joined = "\n".join(problems)
        for where in ("sim/said.gd:3", "game/wrapped.gd:2", "tools/history.py:2"):
            self.assertIn(where, joined)
        self.assertIn("tests/colony_test.gd:2", joined)

        # Tests name their requirements; only the shared base is held to the rule.
        self.write("tools/tests/test_made_up.py", "# Spec 12 R3\n")
        self.write("tests/unit/test_made_up.gd", "extends GutTest\n# Spec 12 R3\n")
        self.assertEqual(len(dev.comment_problems(self.root)), 4)

        with self.assertRaises(dev.StepFailed):
            dev.step_harness(self.root)

    def test_r5_todays_tree_passes(self) -> None:
        self.assertEqual(dev.comment_problems(ROOT), [])


class Attribution(TempTree):
    LINES = (
        "Co-Authored-By: Someone <someone@example.com>",
        "\N{ROBOT FACE} Generated with [a tool](https://example.com)",
        "https://claude.ai/code/session_0123",
    )

    def test_r6_an_attribution_line_fails(self) -> None:
        self.commit("feat: a clean change\n\nWhy it was made.")
        self.assertEqual(dev.attribution_problems(self.root), [], "HEAD alone, clean")
        git(self.root, "update-ref", "refs/remotes/origin/dev", "HEAD")

        for line in self.LINES:
            with self.subTest(line=line):
                commit = self.commit(f"feat: a change\n\nWhy.\n\n{line}")
                self.commit("fix: a later clean change")
                problems = dev.attribution_problems(self.root)
                self.assertEqual(len(problems), 1, problems)
                self.assertIn(commit, problems[0])
                with self.assertRaises(dev.StepFailed):
                    dev.step_harness(self.root)
                # Once on dev, it is no longer this branch's to answer for.
                git(self.root, "update-ref", "refs/remotes/origin/dev", "HEAD")
                self.assertEqual(dev.attribution_problems(self.root), [])

        # With no origin/dev, HEAD alone is read.
        git(self.root, "update-ref", "-d", "refs/remotes/origin/dev")
        commit = self.commit(f"feat: last\n\n{self.LINES[0]}")
        problems = dev.attribution_problems(self.root)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn(commit, problems[0])


class Caps(TempTree):
    def test_r7_a_file_near_the_cap_is_named(self) -> None:
        self.write("game/big.gd", "extends Node\n" + "var a: int = 1\n" * 989)
        self.write("game/small.gd", "extends Node\n" + "var a: int = 1\n" * 900)
        functions = "".join(f"\n\nfunc f{n}() -> void:\n\tpass\n" for n in range(19))
        self.write("sim/wide.gd", "extends RefCounted\n" + functions)
        self.write("sim/narrow.gd", "extends RefCounted\n" + functions.replace("func f1(", "func _f1("))
        self.commit("feat: big files")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            summary = dev.step_harness(self.root)
        shown = output.getvalue() + summary
        self.assertIn("game/big.gd", shown)
        self.assertNotIn("game/small.gd", shown)
        self.assertIn("sim/wide.gd", shown)
        self.assertNotIn("sim/narrow.gd", shown)


if __name__ == "__main__":
    unittest.main()
