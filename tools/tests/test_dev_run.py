"""The dev tool's runner: output is kept on disk with a limit, and a runaway run is stopped."""

import sys
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import dev  # noqa: E402


class RunCapped(unittest.TestCase):
    def test_an_ordinary_run_returns_its_code_and_output(self) -> None:
        code, output = dev.run_capped(
            [sys.executable, "-c", "print('one'); print('two'); raise SystemExit(3)"], 30, 1024
        )
        self.assertEqual(code, 3)
        self.assertEqual(output.splitlines(), ["one", "two"])

    def test_a_run_that_prints_without_end_is_stopped(self) -> None:
        started = time.monotonic()
        with self.assertRaises(dev.StepFailed) as failed:
            dev.run_capped(
                [sys.executable, "-c", "while True: print('ERROR: again' * 50, flush=True)"],
                60,
                1024 * 1024,
            )
        self.assertLess(time.monotonic() - started, 30, "stopped by the limit, not the timeout")
        text = str(failed.exception)
        self.assertIn("more than 1 MB of output", text)
        self.assertIn("ERROR: again", text, "the end of the output is reported")
        self.assertLess(len(text), dev.TAIL_BYTES + 200, "and only its end")

    def test_a_run_that_never_ends_times_out(self) -> None:
        with self.assertRaises(dev.StepFailed) as failed:
            dev.run_capped([sys.executable, "-c", "import time; time.sleep(60)"], 1, 1024)
        self.assertIn("timed out after 1s", str(failed.exception))


if __name__ == "__main__":
    unittest.main()
