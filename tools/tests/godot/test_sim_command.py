"""Acceptance test for spec 005, R19: `python tools/dev.py sim` prints a run as one JSON object.

Run: python -m unittest discover tools/tests/godot   (the `tools` check step runs it too)
Needs Godot, found the way tools/dev.py finds it.
"""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

FIELDS = {
    "seed": int,
    "minutes": (int, float),
    "final_depth": int,
    "last_stable_depth": int,
    "target_depth": int,
    "deepest_depth": int,
    "battles_won": int,
    "battles_lost": int,
    "wipes": int,
    "gold": int,
    "heroes": list,
    "kills": dict,
}


def run_sim(*options: str) -> dict:
    done = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "dev.py"), "sim", *options],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        encoding="utf-8",
        errors="replace",
        timeout=600,
    )
    if done.returncode != 0:
        raise AssertionError(f"dev.py sim failed (exit {done.returncode})\n{done.stdout}")
    lines = [line for line in done.stdout.splitlines() if line.strip()]
    if len(lines) != 1:
        raise AssertionError(f"expected one line of JSON, got:\n{done.stdout}")
    return json.loads(lines[0])


class SimCommandTest(unittest.TestCase):
    def test_r19_sim_command_output(self) -> None:
        summary = run_sim("--seed=7", "--minutes=2")
        for field, kind in FIELDS.items():
            self.assertIn(field, summary)
            self.assertIsInstance(summary[field], kind, field)
        self.assertEqual(summary["seed"], 7)
        self.assertEqual(summary["minutes"], 2)
        self.assertGreater(summary["battles_won"], 0, "two minutes has fights")
        self.assertGreaterEqual(summary["deepest_depth"], summary["final_depth"])
        classes = [hero["class"] for hero in summary["heroes"]]
        self.assertEqual(classes, ["knight", "rogue", "mage", "cleric"])
        for hero in summary["heroes"]:
            self.assertIsInstance(hero["level"], int)
            self.assertIsInstance(hero["xp"], int)
            self.assertGreaterEqual(hero["level"], 1)
        self.assertGreater(sum(summary["kills"].values()), 0)
        for monster, count in summary["kills"].items():
            self.assertIsInstance(monster, str)
            self.assertIsInstance(count, int)

        # Same seed, same run; the options reach the simulation.
        self.assertEqual(run_sim("--seed=7", "--minutes=2"), summary)
        pushed = run_sim("--seed=7", "--minutes=2", "--target-depth=3", "--stable-seconds=30")
        self.assertGreaterEqual(pushed["deepest_depth"], 3, "a target of 3 takes it to depth 3")


if __name__ == "__main__":
    unittest.main()
