"""Acceptance test for spec 051, R11, as spec 109's R12 has it:
`python tools/dev.py sim --spend-talents` spends points, the first path's nodes first, tier by tier.

Run: python -m unittest discover tools/tests/godot   (the `tools` check step runs it too)
Needs Godot, found the way tools/dev.py finds it.
"""

from __future__ import annotations

import unittest

from test_sim_command import run_sim

# Each class's first path, its nodes in order: tier 1, tier 2 left and right, tier 3, tier 4.
FIRST_PATHS = {
    "knight": ["taunt", "hold_the_line", "bottle_top_block", "bulwark", "rallying_cry"],
    "rogue": ["backstab", "mark_for_death", "finisher", "ambush", "killing_spree"],
    "mage": ["fireball", "ignite", "wildfire", "meteor", "inferno"],
    "cleric": ["prayer", "renewal", "blessing", "sanctuary", "miracle"],
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
            earned = min(hero["level"] // 2, 15)
            # Points are spent before each step, so one earned on the last step is still unspent.
            self.assertIn(len(hero["talents"]), (earned, earned - 1), hero)
            self.assertGreaterEqual(len(hero["talents"]), 1, hero)
            taken = hero["talents"][:5]
            self.assertEqual(taken, FIRST_PATHS[hero["class"]][: len(taken)], "path 0 first")


if __name__ == "__main__":
    unittest.main()
