"""Acceptance tests for spec 110, R7 and R10: with path ranks earned by use, the headless run's
spending reaches each hero's first capstone in a fair stretch of play and its whole tree in three
hours, never leaves a point waiting while another path's node is open, and names when.

Run: python -m unittest discover tools/tests/godot   (the `tools` check step runs it too)
Needs Godot, found the way tools/dev.py finds it.
"""

from __future__ import annotations

import unittest
from concurrent.futures import ThreadPoolExecutor

from test_sim_command import run_sim

SEEDS = (1, 2, 3)
# R7's window for the first capstone, in game seconds: 25 to 50 minutes.
CAPSTONE_FROM = 1500
CAPSTONE_BY = 3000
NODES = 15


def _run(seed: int, minutes: int) -> dict:
    return run_sim(
        f"--seed={seed}",
        f"--minutes={minutes}",
        "--spend-talents",
        "--buy-upgrades",
        "--winding",
    )


class CapstoneInFairTimeTest(unittest.TestCase):
    runs: dict[int, dict] = {}

    @classmethod
    def setUpClass(cls) -> None:
        with ThreadPoolExecutor(len(SEEDS)) as pool:
            cls.runs = dict(zip(SEEDS, pool.map(lambda seed: _run(seed, 180), SEEDS)))

    def test_r7_capstone_in_fair_time(self) -> None:
        for seed, summary in self.runs.items():
            for hero in summary["heroes"]:
                where = f"seed {seed}, {hero['class']}"
                at = hero["capstone_at"]
                self.assertIsNotNone(at, f"{where}: no capstone in 180 minutes")
                self.assertGreaterEqual(at, CAPSTONE_FROM, f"{where}: capstone too soon, {at} s")
                self.assertLessEqual(at, CAPSTONE_BY, f"{where}: capstone too late, {at} s")
                self.assertIsNotNone(hero["full_at"], f"{where}: not every node in 180 minutes")
                self.assertEqual(len(hero["talents"]), NODES, where)

    def test_r10_spender_and_summary(self) -> None:
        # The summary's three new fields.
        for seed, summary in self.runs.items():
            for hero in summary["heroes"]:
                where = f"seed {seed}, {hero['class']}"
                self.assertIsInstance(hero["ranks"], list, where)
                self.assertEqual(len(hero["ranks"]), 3, where)
                for rank in hero["ranks"]:
                    self.assertIsInstance(rank, int, where)
                    self.assertGreaterEqual(rank, 0, where)
                self.assertIsInstance(hero["capstone_at"], (int, float), where)
                self.assertIsInstance(hero["full_at"], (int, float), where)
                self.assertLess(hero["capstone_at"], hero["full_at"], where)
        # Twenty minutes in, the first path's deeper tiers are still shut by its rank, yet no point
        # waits: each went to another path's open node.
        early = _run(1, 20)
        for hero in early["heroes"]:
            where = f"20 minutes, {hero['class']}"
            earned = min(hero["level"] // 2, NODES)
            # Points are spent before each step, so one earned on the last step is still unspent.
            self.assertIn(len(hero["talents"]), (earned, earned - 1), where)
            self.assertIsNone(hero["capstone_at"], f"{where}: no capstone yet")
            self.assertIsNone(hero["full_at"], where)
            self.assertEqual(len(hero["ranks"]), 3, where)
        spread = [hero for hero in early["heroes"] if _off_first_path(hero)]
        self.assertTrue(spread, f"some hero took another path's node: {early['heroes']}")
        bare = run_sim("--seed=1", "--minutes=2")
        for hero in bare["heroes"]:
            self.assertEqual(hero["ranks"], [0, 0, 0], "a run that takes no talents ranks nothing")
            self.assertIsNone(hero["capstone_at"])
            self.assertIsNone(hero["full_at"])


# Each class's first path, the one the spender walks first.
FIRST_PATHS = {
    "knight": {"taunt", "hold_the_line", "bottle_top_block", "bulwark", "rallying_cry"},
    "rogue": {"backstab", "mark_for_death", "finisher", "ambush", "killing_spree"},
    "mage": {"fireball", "ignite", "wildfire", "meteor", "inferno"},
    "cleric": {"prayer", "renewal", "blessing", "sanctuary", "miracle"},
}


def _off_first_path(hero: dict) -> bool:
    return any(node not in FIRST_PATHS[hero["class"]] for node in hero["talents"])


if __name__ == "__main__":
    unittest.main()
