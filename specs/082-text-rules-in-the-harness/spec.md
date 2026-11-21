# 082 — Text rules live in the harness; proofs that a refactor happened go

- **Status:** in-progress (provisional)
- **Milestone:** M8 (cleanup)
- **Depends on:** 081
- **Pull request:** —

## Intent

Twenty GUT tests read the text of `game/` and `sim/` files. A few hold a standing rule (only `KeyBook`
reads `.echo`); most only prove that a cleanup spec deleted or moved something, and now fail on a harmless
rename and catch nothing new. This spec puts the standing rules in `check`'s `harness` step, where the
other written rules already are, and removes the rest. It is the first of six specs (082 to 087) from
the test audit of 2026-11-20; nothing the game does changes.

## Row rules (the same in specs 082 to 087)

- Line numbers are those of `dev` at `a97d3c9`. "Cut a-b" removes those lines and whatever only they
  used; "delete" removes the test function and whatever only it used (helpers, constants, preloads).
  A file left with no test is deleted with its `.uid`.
- Before applying a row, open the test and the survivor the row names. If the survivor does not assert
  what is being removed (the same thing, in a situation at least as hard), do not apply the row: leave
  the test as it is and list the row in the report. A survivor must be a test this round leaves in place.
- "Move" puts the assert in the named test, adapted to that test's rig, and it must pass there.
- "Fix" changes a test so that it can fail: break the game code the fixed assert is about, see the test
  fail, restore the code, and say in the report what was broken and what the failure said.
- No other assert changes, and no bound on a wait is raised.
- A cut never leaves a test with no assert that always runs (GUT calls such a test risky and counts it
  as neither passed nor failed). If a row would, stop on that row and report it. The number of tests
  passing equals the number of `func test_` under `tests/`.

## Requirements

- **R1. Three rules are harness checks.** `check`'s `harness` step fails, naming the file and line, when:
  a script under `game/` other than `game/ui/key_book.gd` reads `.echo` or calls `is_echo(`; a script under `game/hud`,
  `game/ui`, `game/effects`, `game/save` or `game/main.gd`, other than `game/ui/windows/window_text.gd`,
  calls `add_theme_color_override("font_color"` outside a comment; a test script under `tests/unit` or
  `tests/acceptance` does not extend `ColonyTest`, itself or through its bases. Today's tree passes.
- **R2. The per-file caps are one table.** `harness` fails when `sim/expedition/expedition.gd` passes 900
  lines, `game/effects/combat_effects.gd` or `game/dev/showcase.gd` passes 750, or `game/hud/hud.gd` has
  more than 15 public methods (counted as `cap_warnings` counts them). The caps are one table in
  `tools/dev.py`; a new cap is a row.
- **R3. The GUT tests that held those rules are gone**, each only once its harness check is in:
  `test_074::test_r5_keys_are_guarded_one_way`; `test_075::test_r7_a_labels_colour_is_set_one_way` lines
  409-414 (415-424 stay); `test_075::test_r3_the_hud_has_few_public_methods`;
  `test_078::test_r4_expedition_has_room` with its list of method names;
  `test_079::test_r4_the_big_files_have_room`; `tests/unit/test_colony_test.gd::test_r1_every_test_script_extends_the_base`
  with its three helpers.
- **R4. Proofs that a refactor happened are gone.**
  - `test_070_game_tidy.gd`: the whole file.
  - `test_069::test_r4_seconds_become_ticks_in_one_place`, with `_scripts`.
  - `test_074::test_r6_no_sentence_spells_a_key_itself`: cut 289-306; the sentences as shown (308-328) stay.
  - `test_075::test_r2_nobody_borrows_from_the_hud`: cut 129-135.
  - `test_075::test_r3_the_hud_is_handed_what_it_needs`: cut 156-168; the keys (170-192) stay.
  - `test_076::test_r4_handlers_have_one_name`: cut 395-403; the live signal's half stays, and asserts
    without a condition: more than ten handlers hear the world's events, and each is `_on_sim_event` or
    anonymous (as cut, its one assert ran only for a wrongly named handler, so the test asserted nothing).
  - `test_078::test_r3_nothing_joins_the_sides_on_the_tick`.
  - `test_079::test_r7_sound_is_handed_its_goals`.
  - `test_080::test_r7_one_owner_advances`: cut 389-395.
  - `test_080::test_r8_small_leftovers`.
  - `tests/unit/test_colony_test.gd::test_r2_the_copied_helpers_are_gone`, with `COPIED`.
- **R5. Tests that cannot fail, or repeat another, are gone.**
  - `test_076::test_r7_every_moment_is_one_row`, with `MOMENTS`: it compares `Showcase.ROWS` with a hand
    copy. Survivor: `test_018::test_r2_showcase_plays_every_moment`.
  - `test_079::test_r2_every_pooled_effect_is_an_fx_node`, with `_is_fx_node` and `SHOW_FRAME`:
    `FxPool.add` takes an `FxNode`, so nothing else can be in the pool.
  - `test_075::test_r4_a_change_shows_on_the_next_frame`: cut 273-278. Survivor:
    `test_080::test_r5_a_change_shows_on_the_next_frame` 242-247.
  - `test_072`: `_getter`'s `"talents"` arm (95-96), which nothing reaches.
  - `tests/unit/test_fixtures.gd::test_a_main_frame_moves_its_parts_in_order`: its expected names are a
    copy of `MainFixture.frame_calls`. In `test_the_ride_to_a_guardian_arrives`, cut 43-48 and 55-62
    (they read back what `before_guardian` assigned); the fight that starts (50-53) stays.
- **R6. The tool tests check the tools once.**
  - Delete `test_007_part_pivots.py::test_r2_repository_sheets_without_part_pivots_are_unchanged`,
    `test_021_sound_effects.py::test_the_sounds_in_the_repository_pass_the_lint`,
    `test_art.py::test_r6_repository_assets_pass_the_lint`,
    `test_077_a_faster_check.py`'s `Comments.test_r5_todays_tree_passes`, and line 79 of
    `test_081_shared_fixtures.py::test_r5_todays_tree_passes`: `check` runs each of those lints on the
    repository in the same step.
  - `test_021_sound_effects.py::test_the_art_step_runs_the_sfx_lint` reads `tools/dev.py`'s text: make it
    run `step_art` with `dev.run` patched and see the lint command, as `test_077`'s `Imports` does.
  - `test_art_font.py::test_r3_other_categories_are_unchanged`: cut 65-72. Survivors: `test_art.py`'s
    `test_r4_lint_accepts_a_correct_sprite` and `test_r4_lint_rejects_outline_gap_at_canvas_edge`.
  - `test_077::test_r4_art_starts_no_godot` calls the real `step_art`, which runs every tool test again:
    after this spec one `check` runs the tool tests once. What that test held stays held: the `art` step
    runs its tool tests with `GODOT` naming a program that fails, so a tool test outside
    `tools/tests/godot/` that starts Godot fails the real `check`, and `test_077` sees that environment
    on the command `step_art` runs.
- **R7. The harness says where rules live.** `CLAUDE.md`'s key rule and its `expedition.gd` sentence name
  the harness instead of spec 074's and 078's tests; `docs/standards.md` likewise; the
  `godot-headless-test` skill says a rule about source text is a `harness` check, never a GUT test.

- **R8. A test that asserts nothing fails the check.** `check`'s `tests` step (and `dev.py test`) fails,
  naming the test, when GUT reports a test as risky (it made no assert) or pending. Today's tree has none.

## Interfaces

Names in `tools/dev.py` are the lane's; report them. A rule's message says what to do instead.

## Acceptance

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `tools/tests/test_082_text_rules.py`: `test_r1_an_echo_read_outside_key_book_fails`, `test_r1_a_font_colour_set_by_hand_fails`, `test_r1_a_comment_does_not_count`, `test_r1_a_test_script_off_the_base_fails` | a temp tree with the realistic mistake fails naming file and line; the allowed file and a comment pass |
| R2 | same file: `test_r2_a_file_over_its_cap_fails`, `test_r2_a_class_over_its_methods_fails`, `test_r2_at_the_cap_passes` | a temp tree one line or one method over fails; at the cap it passes |
| R3 to R6 | (lane's report) | each row as done or left, with the reason; the list of test names before and after |
| R8 | `test_082_text_rules.py::test_r8_a_test_without_an_assert_fails_the_tests_step` | GUT output with a risky test fails the step naming it; the same output with none passes |
| R6 | `test_082_text_rules.py::test_r6_a_tool_test_that_starts_godot_fails_the_art_step` | a temp tool test that calls `dev.godot` fails when run as the `art` step runs its tool tests; it does not fail on `dev`'s `step_art` |

## Out of scope

- The other source-reading tests: `test_030::test_r3_every_key_is_listed`,
  `test_076::test_r3_listeners_ask_the_gate`, the vocabulary scans in `test_054` and `test_068`,
  `test_064::test_r4`'s, `test_078::test_r6`'s. The recorded baselines (`test_080` R1, `test_079` R4's
  positions, `test_075` R7's colours, `test_078` R3's targeting reference): Zak decides those.
- Anything under `sim/` or `game/`. Splitting or renaming tests.

## Paths

- `tools/dev.py`, `tools/tests/`, `tools/local_test_helpers.json` (entries naming a removed script)
- `tests/acceptance/test_069_sim_tidy.gd`, `test_070_game_tidy.gd` (and `.uid`), `test_072_content_table.gd`,
  `test_074_one_list_of_windows_and_keys.gd`, `test_075_a_smaller_hud.gd`, `test_076_one_pool_for_effects.gd`,
  `test_078_sim_base_types.gd`, `test_079_effect_nodes.gd`, `test_080_frame_pieces.gd`
- `tests/unit/test_colony_test.gd`, `tests/unit/test_fixtures.gd`
- `CLAUDE.md`, `docs/standards.md`, `.claude/skills/godot-headless-test/SKILL.md`

## Open questions
