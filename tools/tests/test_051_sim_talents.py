"""Acceptance test for spec 051, R11: `python tools/dev.py sim --spend-talents` spends points.

Run: python -m unittest discover tools/tests   (the `art` check step runs it too)
Needs Godot, found the way tools/dev.py finds it.
"""

from __future__ import annotations

import unittest

from test_sim_command import run_sim

FIRST_NODES = {
    "knight": "shield_bash",
    "rogue": "backstab",
    "mage": "fireball",
    "cleric": "prayer",
}


class SimTalentsTest(unittest.TestCase):
    def test_r11_spend_talents(self) -> None:
        plain = run_sim("--seed=1", "--minutes=4")
        for hero in plain["heroes"]:
            self.assertEqual(hero["talents"], [], "without the option nothing is spent")
        self.assertIn("slime_king_won", plain)
        self.assertIn("wipes_before_slime_king", plain)

        spent = run_sim("--seed=1", "--minutes=4", "--spend-talents")
        for hero in spent["heroes"]:
            self.assertGreaterEqual(hero["level"], 2, "four minutes earn a talent point")
            self.assertEqual(len(hero["talents"]), min(hero["level"] // 2, 7), hero)
            self.assertEqual(hero["talents"][0], FIRST_NODES[hero["class"]], "the trunk first")


if __name__ == "__main__":
    unittest.main()
