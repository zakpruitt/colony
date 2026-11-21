# 087 — World, effects and time-away tests that hold

- **Status:** landed (provisional)
- **Milestone:** M8 (cleanup)
- **Depends on:** 081
- **Pull request:** [#87](https://github.com/zakpruitt/colony/pull/87)

## Intent

The audit of 2026-11-20 found one world test that is broken (its second half never hears an event, so it
plays five game minutes and passes by luck), tests timed by the wall clock, the F3 developer clock
asserted in four files, and wipe assertions repeated between specs 008, 038, 048 and 054. This spec fixes
the broken ones and removes the repeats. Nothing the game does changes.

## Row rules

The row rules of spec 082 apply (line numbers at `a97d3c9`; open the survivor before cutting; a row that
cannot be confirmed is left and reported; a fix is seen to fail on broken code).

## Requirements

- **R1. The short crossing's second half hears its events.** `test_054::test_r2_a_short_crossing` switches
  `_world` to the main scene's world at 222-229 and never connects its `sim_event`, so `_play_frame()`
  returns nothing, the `break` at 251-252 never fires and the loop runs all of
  `LIMIT_TICKS_5_MIN * FRAMES_PER_TICK` frames. Connect it (`_hear_events()`), assert that the stage
  changed, and say in the report how long the test took before and after.
- **R2. No test here is timed by the wall clock.** `test_019::test_r3_replay_is_sliced`: cut 123-125 and
  132-136 (real milliseconds; the slice's budget is
  `tests/unit/test_away_replay.gd::test_a_slice_stops_at_its_budget`) and 126
  (`test_062::test_r6_catching_up_bar` line 497); "no world or HUD during the replay" and "the bar rises"
  stay. `test_032::test_r6_time_away_unaffected`'s `while back.is_catching_up()` loop (348) has no limit:
  it fails the test at a limit instead of hanging the run.
- **R3. `test_057`'s spell test checks what it says.** `test_r4_a_spell_shows_only_on_whom_it_reached`
  uses `_only_on` (`lively_moves_test_base.gd` 104-106), which skips any other fighter within 24 pixels,
  and heroes stand 16 apart. Find out whether "Blessing leaves the rogue out" is ever checked; if it is
  not, fix the helper so that it is, and report what was found either way.
- **R4. The developer clock is asserted once**, in `test_011::test_r7_dev_clock_hidden_until_f3`. Delete
  `test_001::test_r7_main_scene_shows_the_clock` and
  `test_009::test_r5_clock_label_uses_the_pixel_font`; cut `test_008` R1 159-162; remove `test_009`'s
  unused `FONT_PATH`.
- **R5. A wipe is told once per fact.**
  - `test_008` R2: cut 231-241 (`test_038::test_r1_wipe_leaves_the_party` 238-242). R3: cut 319-346
    except "keeps its sprite" (344) and "not attacking" (346).
  - `test_048::test_r6_far_cut_waits`: delete. Survivors: `test_054::test_r8_the_wipe_still_reads`
    695-722 and `tests/unit/test_world_fallen.gd::test_a_far_revival_is_a_cut` (same seed, same stage 8).
- **R6. Time away is compared with playing once**, in `test_019::test_r4_same_as_playing`. Move
  `total_ticks == 5000` and `fraction() == 1` from
  `tests/unit/test_away_replay.gd::test_a_replay_ends_where_stepping_does` into it, then delete that unit
  test and `test_031::test_r6_nothing_else_changes`. `test_019` R5: cut 190-217
  (`test_062::test_r5_away_report_window` 413-478).
- **R7. Other repeats and asserts that cannot fail go.**
  - `test_010` R5: cut line 221 (`velocity.y > -1000`).
  - `test_018` R1: cut the asserts on `main.hud_layer` (39-40, 50-51, 74), which holds nothing visible,
    and 60-68 (`test_061::test_r4_things_still_fly_to_it`); the zoom itself stays. R4: cut 106-107 (said
    at 104-105).
  - `test_032` R7: cut 412-440 (`test_030::test_r3_every_key_is_listed`); "F works with each panel open"
    (382-410) stays.
  - `test_057` R8: cut 827-833 and 843 (`test_056::test_r8_still_readable` 805-807).
  - `tests/unit/test_labyrinth_view.gd::test_variants_depend_only_on_position`: it compares a call with
    itself. Survivor: `test_006::test_r2_edges_and_variants` 87-107.

## Interfaces

None.

## Acceptance

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_054::test_r2_a_short_crossing` | fails when the game's veil is kept hidden through a crossing, passes on today's code, and ends at the crossing |
| R3 | `test_057::test_r4_a_spell_shows_only_on_whom_it_reached` | fails when Blessing's glow is also put on the rogue |
| R2, R4 to R7 | (lane's report) | each row as done or left, with the reason; the test names before and after; lines of `tests/` before and after |

## Out of scope

- Zak's decisions, left as they are: the un-zoned labyrinth view and its tests (`test_006` R1, R3 to R6,
  `test_012`'s three-level budgets), the demo scenes' smoke tests, `test_038`'s `MONSTER_REFERENCE` and
  its showcase test.
- Splitting long tests, moving `test_008` onto
  `PlayFixture`, renaming files. Anything under `sim/` or `game/`.

## Paths

- `tests/acceptance/`: `test_001_sim_clock.gd`, `test_008_world_integration.gd`, `test_009_pixel_font.gd`,
  `test_010_combat_effects.gd`, `test_018_seeing_the_loop.gd`, `test_019_away_progress.gd`,
  `test_031_away_report.gd`, `test_032_game_speed.gd` (R6's loop and R7 only), `test_048_a_wipe_told_whole.gd`,
  `test_054_zones_on_screen.gd` (R2 only), `test_057_lively_moves.gd`
- `tests/unit/test_away_replay.gd`, `tests/unit/test_labyrinth_view.gd`, `tests/unit/lively_moves_test_base.gd`

## Open questions
