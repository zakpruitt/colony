"""Acceptance test for spec 089, R8: `python tools/dev.py sim --winding` plays on winding stages.

Run: python -m unittest discover tools/tests/godot   (the `tools` check step runs it too)
Needs Godot, found the way tools/dev.py finds it.
"""

from __future__ import annotations

import unittest

from test_sim_command import FIELDS, run_sim

OPTIONS = ("--seed=3", "--minutes=10", "--buy-upgrades", "--spend-talents")


class SimWindingTest(unittest.TestCase):
    def test_r8_winding_run(self) -> None:
        flat = run_sim(*OPTIONS)
        winding = run_sim(*OPTIONS, "--winding")
        self.assertEqual(
            set(winding), set(flat) | {"caches_opened"}, "the flat summary and the caches opened"
        )
        self.assertIsInstance(winding["caches_opened"], int, "caches_opened")
        for field, kind in FIELDS.items():
            self.assertIsInstance(winding[field], kind, field)
        self.assertGreaterEqual(winding["stage"], 2, "ten minutes takes it to stage 2")
        self.assertGreater(winding["battles_won"], 0, "with fights on the way")
        # The summary carries no state hash: a different run shows in what it counts.
        self.assertNotEqual(winding, flat, "a winding run is not the flat one")
        self.assertNotEqual(winding["battles_won"], flat["battles_won"], "more rooms, more fights")
        self.assertEqual(run_sim(*OPTIONS, "--winding"), winding, "same seed, same run")


if __name__ == "__main__":
    unittest.main()
