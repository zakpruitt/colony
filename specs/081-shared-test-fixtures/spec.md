# 081 — Shared test fixtures, and a check that keeps helpers shared

- **Status:** in-progress (provisional)
- **Milestone:** M8 (cleanup)
- **Depends on:** 071, 077, 080
- **Pull request:** —

## Intent

Spec 071 gave tests one base, but about a hundred helpers are still copied between test files:
`_before_guardian` is written 16 times, `_frame` 16, `_build_hud` and `_make_hud` 14, `_step_until` 11.
Tests are most of the repository, and a copied helper is where a new test starts from the wrong example.
This spec moves those helpers into shared fixtures and makes the check refuse a third copy of any helper,
so a new test extends what exists. No test stops proving what it proves.

## Requirements

- **R1. Every test still proves what it proved.** The suite passes with the same tests by name (count and
  names equal `dev`'s, plus this spec's). No `assert_…` line is added, removed or changed in an existing
  test: an edit there only replaces a call to a local helper with a call to the shared one, or deletes
  the local helper.
- **R2. The copied helpers live once.** Each of these is defined in one place and used from there:
  the ride to a guardian (`_before_guardian`), building a `World` + `CombatEffects` + `Hud` (`_build_hud`,
  `_make_hud`), stepping the sim with the world and Hud following (`_step_until`'s six such copies),
  one played frame (`_frame`, `_play_frame`), a click on a control (`_click_at`, `_click`), seconds to
  ticks (`_ticks`), the labels under a node (`_collect_labels`), the events of a kind (`_of_kind`),
  spending talents (`_spend_talents`), a save through JSON and back (`_through_json`), and the tick limit
  `LIMIT_TICKS` (a constant in 20 files). Where two copies of a name do different things, each thing gets
  its own shared name; none is merged by changing what a test does.
- **R3. Fixtures are classes to extend.** The shared helpers that build things are fixture classes under
  `tests/support/` (a Hud fixture, a played-game fixture, …) that a test makes or a per-spec base extends;
  `ColonyTest` keeps the small verbs and stays within gdlint's 20 public methods. The nine per-spec
  `*_test_base.gd` files are built on them and hold only what is their spec's own.
- **R4. Tests got smaller.** The `.gd` files under `tests/` total at least 1,200 lines fewer than on `dev`
  (not counting this spec's own test), and no test file is within 15 lines of gdlint's 1000.
- **R5. The check keeps helpers shared.** `harness` fails when a function of the same name is defined in
  more than two test scripts (GUT's hooks and `test_…` functions apart), naming the files. A name that
  must stay local in several files is listed, with its reason, in one tracked allow-list. Today's tree
  passes with that list holding no name from R2.
- **R6. The harness says how.** `docs/standards.md`'s test row and the `godot-headless-test` skill name
  the fixtures and say which to reach for; `CLAUDE.md`'s test rule points at them.

## Interfaces

Names and shapes are the lane's, since they must fit sixteen call sites each; report them. Two rules:
a fixture is handed what it needs (no reaching for a test's fields), and it frees what it makes.

## Acceptance

| Requirement | Test | What it shows |
|---|---|---|
| R1 | (lane's report) | the list of test names before and after, from GUT's output, differs only by this spec's tests; `git diff origin/dev -- tests/` has no changed `assert_` line outside this spec's test |
| R2, R3 | `tests/unit/test_fixtures.gd`: `test_the_hud_fixture_builds_a_working_hud`, `test_the_ride_to_a_guardian_arrives`, `test_a_played_frame_moves_everything_once` | each fixture does what its copies did: a Hud that shows the party, a party one chamber short of a guardian, one frame of sim, world and Hud |
| R4 | `tools/tests/test_081_shared_fixtures.py`: `test_r4_no_test_file_is_near_the_cap` | reads `tests/` |
| R5 | same file: `test_r5_a_third_copy_fails`, `test_r5_an_allowed_name_passes`, `test_r5_todays_tree_passes` | a temp tree with `_helper` in three test scripts fails naming them; allowed, it passes |

R4's line count is for the lane's report and the reviewer.

## Out of scope

- Making tests faster, merging tests, deleting tests, or changing any assertion. Tests that read source
  text. Anything under `sim/` or `game/`.

## Paths

- `tests/`, `tools/dev.py`, `tools/tests/`, a tracked allow-list beside `tools/test_times.json`
- `docs/standards.md`, `CLAUDE.md`, `.claude/skills/godot-headless-test/SKILL.md`

## Open questions

