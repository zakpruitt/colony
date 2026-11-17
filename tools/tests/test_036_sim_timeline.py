"""Acceptance test for spec 036, R9: `python tools/dev.py sim --timeline` reports each first.

Run: python -m unittest discover tools/tests   (the `art` check step runs it too)
Needs Godot, found the way tools/dev.py finds it.
"""

from __future__ import annotations

import unittest

from test_sim_command import run_sim

KEYS = [
    "level_2",
    "level_5",
    "depth_2",
    "depth_5",
    "upgrade_affordable",
    "guardian_met",
    "guardian_beaten",
]


class SimTimelineTest(unittest.TestCase):
    def test_r9_timeline(self) -> None:
        plain = run_sim("--seed=1", "--minutes=3")
        self.assertNotIn("timeline", plain, "only with --timeline")

        summary = run_sim("--seed=1", "--minutes=3", "--timeline")
        timeline = summary["timeline"]
        self.assertEqual(sorted(timeline), sorted(KEYS))
        for key in ("level_2", "depth_2", "upgrade_affordable"):
            self.assertIsInstance(timeline[key], (int, float), key)
            self.assertGreater(timeline[key], 0, key)
            self.assertLessEqual(timeline[key], 180, f"{key} within the run")
        for key in ("depth_5", "guardian_met", "guardian_beaten"):
            self.assertIsNone(timeline[key], f"{key} does not happen in three minutes")
        # The rest of the summary is the same run with or without the timeline.
        del summary["timeline"]
        self.assertEqual(summary, plain)


if __name__ == "__main__":
    unittest.main()
