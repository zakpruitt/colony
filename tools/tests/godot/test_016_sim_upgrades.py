"""Acceptance test for spec 016, R8: the headless sim summary shows upgrade ranks and can buy them.

Run: python -m unittest discover tools/tests/godot   (the `tools` check step runs it too)
Needs Godot, found the way tools/dev.py finds it.
"""

from __future__ import annotations

import unittest

from test_sim_command import run_sim

UPGRADE_IDS = ["sharp_blades", "stout_armor", "field_medicine", "quick_march", "fat_purse"]


class SimUpgradesTest(unittest.TestCase):
    def test_r8_sim_command_upgrades(self) -> None:
        plain = run_sim("--seed=7", "--minutes=10")
        self.assertIn("upgrades", plain)
        self.assertEqual(sorted(plain["upgrades"]), sorted(UPGRADE_IDS))
        for upgrade, rank in plain["upgrades"].items():
            self.assertIsInstance(rank, int, upgrade)
            self.assertEqual(rank, 0, f"{upgrade}: nothing is bought without --buy-upgrades")

        buying = run_sim("--seed=7", "--minutes=10", "--buy-upgrades")
        self.assertEqual(sorted(buying["upgrades"]), sorted(UPGRADE_IDS))
        self.assertGreater(sum(buying["upgrades"].values()), 0, "ranks above 0")
        for upgrade, rank in buying["upgrades"].items():
            self.assertIsInstance(rank, int, upgrade)
            self.assertGreaterEqual(rank, 0, upgrade)


if __name__ == "__main__":
    unittest.main()
