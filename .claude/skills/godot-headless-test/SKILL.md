---
name: godot-headless-test
description: Write, fix or read Colony's GUT tests (tests/unit, tests/acceptance) and diagnose failures of `python tools/dev.py check` or `test`. Use when adding an acceptance or unit test, when a test fails or prints SCRIPT ERROR, when a test passes with broken code, or when a check step fails in CI but not locally.
---

# Headless tests in Colony

Tests are GUT 9 scripts: `extends GutTest`, functions named `test_*`, in files named `test_*.gd` under `tests/`.
The whole suite runs in one Godot boot.

```
python tools/dev.py test                  # all tests
python tools/dev.py test --only=test_003  # scripts whose name contains this
python tools/dev.py check --only=compile,tests
```

## A test must be able to fail

- Write the test before the code and watch it fail because the behaviour is missing. A test that has never
  failed has not been shown to test anything.
- For a change to existing behaviour, put the old value back (copy the file aside; do not `git checkout` over
  uncommitted work), see the test fail, restore.
- Assert the outcome the requirement names. "No error occurred" and "the method was called" are not outcomes.

## Testing the sim

The sim is plain objects (`docs/architecture.md`), so most tests need no scene, no frames and no waiting.

- Build the state, step it, assert. Ten minutes of game time is a loop, not a wait.
- Fix the seed: `SimRng.new(1234)`. A test whose result depends on an unseeded roll is a flake.
- For "always" and "never" claims, run many seeds in a loop, and print the seed in the assertion message so a
  failure can be replayed.
- Determinism has its own kind of test: run the same seed and commands twice and compare the whole state.

## Testing nodes (`game/`)

- `add_child_autofree(node)` so GUT frees it; a leaked node is reported as an orphan.
- Do not time things with the wall clock. Headless frames do not take a frame's worth of time. Drive time
  yourself: call the method with a delta, or step the sim directly.
- `await get_tree().process_frame` resumes before that frame's `_process` calls have run. To see what a node's
  `_process` did, await two frames, or use GUT's `await wait_process_frames(2)`.
- The headless window is tiny. Send keys and actions with `Input.parse_input_event`, not mouse positions.

## Files

`user://` is one folder shared by every worktree on the machine. A test that writes there uses a per-process
name and deletes it:

```gdscript
var path: String = "user://test_save_%d.dat" % OS.get_process_id()
```

## Reading a failure

- `[format] FAIL`: run `python tools/dev.py format`. If `gdlint` complains, fix the code, not the rule.
- `[boundary] FAIL`: something under `sim/` named a node, a clock or a global random function. Pass the value
  in instead (ticks for time, a `SimRng` for rolls).
- `[compile] FAIL` with `Warning treated as error`: almost always a missing type. `var x := dict.get(k)` infers
  a `Variant`; write `var x: int = dict.get(k)`. The same goes for elements of an untyped `Array` or
  `Dictionary` passed straight to a typed parameter, `assert_eq` included (`requires the subtype "Variant" but
  the supertype "Variant" was provided`): copy the element into a typed local first.
- Code that is meant to `push_error` (a rejected input, say) fails the test unless the test claims the error
  with `assert_push_error("part of the message")`.
- `[compile] FAIL` with `is shadowing an already-declared function`: a local or parameter has the name of a
  method of the class (a `chamber()` method and a `var chamber` local). Rename the local.
- `[format] FAIL` with `max-file-lines`: gdlint caps a file at 1000 lines. A long acceptance file stays
  under it with small helpers (one that returns the amounts of every event of a kind, say) rather than
  repeated `if x.size() == 1:` guards.
- To prove a test can fail, break the code with a change that still compiles: `if false:` is dead code, a
  warning, so the script stops loading and everything fails (or a `SceneTree` script hangs) for the wrong
  reason. Prefer `if <condition> and <something never true>:`.
- `SCRIPT ERROR ... Could not find type "X"`: a new `class_name` the import cache has not seen. Run
  `python tools/dev.py import` (the full `check` does this for you).
- `[tests] FAIL`: GUT prints the failing assertion with its file and line above the summary.
- `dev.py test` shows a test's `print` output only when something fails. To read a trace while debugging,
  end the test with a failing assertion, and delete the test (and its `.uid`) afterwards.
- `[boot] FAIL`: the main scene printed an error while starting; the line is in the output.
- **Passes locally, fails in CI:** CI is Linux, where paths are case-sensitive (`res://Sim/x.gd` is not
  `res://sim/x.gd`) and nothing untracked exists. `git status` for files you forgot to add, `.uid` files included.
