# 071 — A shared test base

- **Status:** landed (approved 2026-11-19)
- **Milestone:** M8 (cleanup)
- **Depends on:** none
- **Pull request:** [#71](https://github.com/zakpruitt/colony/pull/71)

## Intent

The tests are the largest part of the repository (about 43,000 lines) and have no shared base, so every
lane copies the same helpers: pressing a key (15 copies), raising a hero's level (14), standing before
a guardian (16), building a `Main` (14 builders). This spec gives the tests one base to reuse, moves the
copies onto it, and makes two written rules into checks. No test's assertions change.

## Requirements

- **R1. One base.** `tests/colony_test.gd` (`class_name ColonyTest`, `extends GutTest`) holds the shared
  helpers. Every test script and every per-spec helper base extends it, directly or through a per-spec
  base. The per-spec bases keep what is theirs alone.
- **R2. The copied helpers live there once:** press a key, click and move the mouse, raise a hero to a
  level, step a simulation until something holds (with a tick limit that fails the test), build the main
  scene, and a save path that is per process, under `user://`, and removed with its backup and temporary
  files in `after_each` and in `after_all`. A copy that is identical to the shared helper is deleted and
  its callers use the shared one. A copy that differs in behaviour (as `_before_guardian` does between
  tests 027 and 033) keeps its difference, as an argument or a local helper: do not make two tests
  behave alike to merge them.
- **R3. No assertion changes.** The same 744 test functions exist under the same names, and the diff
  changes no `assert_…` line. The whole suite passes.
- **R4. Leaks and leftovers fixed.** `test_019_away_progress.gd` cleans up in `after_all`;
  `test_014` uses `SaveStore`'s suffix constants; `tests/unit/test_ability_kit.gd` is renamed so GUT
  no longer loads it as an empty test; the orphan doc comments in `test_057_lively_moves.gd` and
  `test_058_windows_beside_the_old_hud.gd` and that file's stale header are removed; helper bases are
  all named `*_test_base.gd`; `tests/acceptance/.gitkeep` and `assets/.gitkeep` are deleted.
- **R5. Two rules become checks.** `python tools/dev.py check` gains a step `harness` that fails, naming
  the file, when a test script mentions `user://` and neither it nor a base it extends defines
  `after_all`, and when a tracked `.gd` file has no tracked `.gd.uid` beside it. CI runs it with the rest.
- **R6. Lanes are told to reuse.** The `godot-headless-test` skill describes `ColonyTest` and tells a
  lane to add a helper there when a second test needs it, in place of its advice to copy a per-spec
  base. `CLAUDE.md`'s command table lists the new step and its test-files rule points at the base.

## Interfaces

```gdscript
# tests/colony_test.gd
class_name ColonyTest
extends GutTest

func press(keycode: Key) -> void
func mouse_move(at: Vector2) -> void
func click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void
func raise(hero: Hero, level: int) -> void
func step_until(simulation: Simulation, done: Callable, limit: int) -> bool
func make_main() -> Main          # instantiated, not yet in the tree, no save store, no window settings
func save_path(tag: String = "") -> String
```

Names and signatures may be adjusted to fit what the copies really do; report the final list.

## Acceptance

In `tools/tests/test_071_harness_check.py`:

| Requirement | Test | What it shows |
|---|---|---|
| R5 | `test_r5_a_test_writing_files_without_after_all_fails` | the step fails on a made-up test script that uses `user://` with no `after_all`, and passes once it has one or extends a base that has |
| R5 | `test_r5_a_script_without_its_uid_fails` | the step fails on a made-up `.gd` with no `.uid` |

In `tests/unit/test_colony_test.gd`:

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_every_test_script_extends_the_base` | reads `tests/`; every script's `extends` chain reaches `ColonyTest` |
| R2 | `test_r2_the_copied_helpers_are_gone` | reads `tests/`; `func _key(` and `func _mouse(` are declared nowhere but the base's own helpers |
| R2 | `test_r2_a_save_path_is_removed_with_its_backups` | a file written at `save_path()` with backup and temporary siblings is gone after the cleanup runs |

R3 is shown by the reviewer: `git diff` filtered to `assert_` lines is empty, and the count of
`func test_` in the files that existed before is 744. R4 and R6 are for the reviewer.

## Out of scope

- Changing what any test checks, splitting long test files, deleting tests.
- Any change under `sim/` or `game/`. If a helper cannot be shared without one, leave it and report it.
- Making the `art` step faster.

## Paths

- `tests/` (existing test files change only to use the base and for R4)
- `tools/dev.py`, `tools/tests/test_071_harness_check.py` (new), `tools/tests/test_art.py` (only its
  assertion of the step order)
- `.github/workflows/` (only if the steps are listed there)
- `.claude/skills/godot-headless-test/SKILL.md`, `CLAUDE.md`
- `assets/.gitkeep`
- This lane lands after 069 and 070. Their new files (`tests/acceptance/test_069_sim_tidy.gd`,
  `test_070_game_tidy.gd`) are in its Paths only to move them onto the base when it rebases.

## Open questions
