"""Acceptance test for spec 049, R11: `python tools/dev.py sim` knows areas.

It prints the area and stage the party is in, each area's safe and furthest stage and the open
areas, and `--area=<id>` sends the party to that area at the start, opening it for the run.

Run: python -m unittest discover tools/tests   (the `art` check step runs it too)
Needs Godot, found the way tools/dev.py finds it.
"""

from __future__ import annotations

import unittest

from test_sim_command import run_sim

AREAS = ["mossy_hollow", "claypits", "old_crypt", "ember_deep"]


class SimAreasTest(unittest.TestCase):
    def test_r11_the_headless_run_knows_areas(self) -> None:
        summary = run_sim("--seed=3", "--minutes=1")
        self.assertEqual(summary["area"], "mossy_hollow", "a new game is in Mossy Hollow")
        self.assertIsInstance(summary["stage"], int)
        self.assertEqual(summary["stage"], summary["final_depth"], "the stage is the depth")
        self.assertEqual(sorted(summary["areas"]), sorted(AREAS), "every area's progress")
        here = summary["areas"]["mossy_hollow"]
        self.assertEqual(here["safe"], summary["last_stable_depth"])
        self.assertEqual(here["furthest"], summary["deepest_depth"])
        self.assertEqual(summary["areas"]["claypits"], {"safe": 1, "furthest": 0}, "never been")
        self.assertEqual(summary["open_areas"], ["mossy_hollow"], "only the first area is open")

        sent = run_sim("--seed=3", "--minutes=1", "--area=old_crypt")
        self.assertEqual(sent["area"], "old_crypt", "sent to the Old Crypt")
        self.assertEqual(sent["open_areas"], ["mossy_hollow", "old_crypt"], "opened for the run")
        self.assertGreaterEqual(sent["areas"]["old_crypt"]["furthest"], 1, "it got there")
        self.assertEqual(sent["areas"]["mossy_hollow"], {"safe": 1, "furthest": 1}, "it left")
        self.assertGreater(sent["battles_won"] + sent["battles_lost"], 0, "it fought there")
        killed = set(sent["kills"])
        self.assertTrue(killed <= {"skeleton", "ghoul", "wraith"}, f"crypt monsters: {killed}")


if __name__ == "__main__":
    unittest.main()
