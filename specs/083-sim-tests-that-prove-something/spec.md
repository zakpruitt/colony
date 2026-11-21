# 083 — Simulation tests that each prove something

- **Status:** landed (provisional)
- **Milestone:** M8 (cleanup)
- **Depends on:** 081
- **Pull request:** [#84](https://github.com/zakpruitt/colony/pull/84)

## Intent

The simulation's tests are the soundest part of the suite, but the audit of 2026-11-20 found the same
recorded run compared in five tests, a balance test for fights the game no longer rolls, expected values
taken from the function under test, and asserts that cannot fail. This spec removes those and fixes the
two that hide a failure. Nothing the game does changes.

## Row rules

The row rules of spec 082 apply (line numbers at `a97d3c9`; open the survivor before cutting; a row that
cannot be confirmed is left and reported; a fix is seen to fail on broken code).

## Requirements

- **R1. A default run is compared with its recording once.** `test_016::test_r5_no_upgrades_changes_nothing`
  is the one test that steps an untouched `Simulation` and compares state hashes with a recorded list.
  Where another test runs the same loop (same ticks, same sampling), its seeds' recordings move into
  `test_016`'s `RECORDED_HASHES` and its copy goes:
  - `test_051_talent_trees_and_paragon::test_r12_deterministic`: cut 888-900 (it preloads 016's constant).
  - `test_022::test_r5_off_changes_nothing`, with its constant.
  - `test_039::test_r5_nothing_else_changes`, with its constant (seed 7 is the first ten samples of 035's).
  - `test_035::test_r5_defaults_change_nothing`: the recorded loop (388-398) goes; "an order away from its
    default changes the hash" (399-408) stays, compared with a default run made in the test.
  A loop that samples differently stays where it is and is reported.
- **R2. Stale and duplicate tests are gone.**
  - `test_013::test_r6_stone_band_is_hard_but_fair`, with `_win_rate` and its constants: it mixes every
    monster up to depth 12, and `sim/expedition/encounter_roll.gd` now rolls only the area's monsters.
  - `test_013::test_r4_bands_have_their_own_inhabitants`: move "each new monster turns up at its first
    stage and three on" (194-195, with `_met_at`) into `test_049_areas::test_r3_only_the_areas_monsters`;
    delete the rest (survivor: that test, 231-240).
  - `test_040::test_r5_names_live_in_the_view`. Survivors: `test_035::test_r7_orders_panel` 561-568 and
    `tests/unit/test_expedition_orders.gd::test_names_line_up_with_the_enums`.
  - `tests/unit/test_simulation.gd::test_tick_length_is_a_tenth_of_a_second` and
    `::test_seconds_follows_ticks`. Survivors: `test_001` R2 (51-59) and R1 (line 48).
  - `tests/unit/test_main_save.gd::test_a_run_without_a_store_neither_loads_nor_saves`. Survivors:
    `test_019::test_r7_no_store_no_replay` and `test_018::test_r4_showcase_is_separate` 113-118.
- **R3. Repeats inside tests are cut.**
  - `test_005` R14: cut 742-745 (R7's `_check_rewards`) and 764-770 (R13 line 690, R3 line 172).
    R16: cut 810-815 (R2 152-157).
  - `test_020` R2: cut 137-145 (`test_049::test_r3` 224-249). `test_r8_guardians_build_and_animate`: cut
    355-365 (`test_013::test_r7_demo_shows_all_thirteen` 257-261).
  - `test_022` R6: cut the label, lit, B and click asserts that `test_065::test_r7_the_foot_and_the_keys`
    542-561 makes; 255-260 and 282-293 stay.
  - `test_025` R3: stop calling `_reading_changes_nothing` and delete it with `_read_all` (289-332), after
    adding those side-quest reads to `test_023`'s `_storm` so `test_023` R1 and R2 cover them.
  - `test_035` R7: cut 536-552 (`test_058_sharp_ui_and_windows::test_r8` and `test_030` R3), 592-596
    (`test_040` R2), 611-627 (`test_058` R8 642-649). R9: cut the bar button's tooltip and the help line
    (`test_074` R2 154-155); each choice's own tooltip stays.
  - `test_036` R1: cut 168-199 (`test_027::test_r2_road_to_stable` 276-303).
  - `test_039` R2: cut the lines `test_027` R2 and `test_061::test_r2_the_countdown` 123-127, 145-147
    make; 196-215 and 224-230 stay.
- **R4. Asserts that cannot fail are gone.**
  - A constant against a literal, or a value against itself: `test_015` 100 and 206; `test_016` 126-127
    (a copy of `UpgradeDef.cost_at`) and 345; `test_020` 233; `test_022` 191; `test_023` 186;
    `test_025` 154; `test_035` 207 and 288-290; `test_036` 294-295; `test_044` 147-160;
    `test_051_talent_trees_and_paragon` 620-625.
  - `test_005` R17: cut 919-926 (three hour-long runs asserting only that the tick is the tick; R18 runs
    five).
  - `test_051_every_ability_is_seen` R14: cut 132-145 (fields of two `.tres` files restated).
  - `test_052_resources_kept` R10: cut 112-132 (it only prints).
  - The save version is pinned once, in `test_014::test_r5_upgrade_is_a_pass_through`: cut the pins at
    `test_022` 199, `test_035` 333-335, `test_049` 531 and `test_052_resources_kept` 13-15.
- **R5. Two tests are fixed.**
  - `test_022::test_r2_buys_the_cheapest` takes its expected upgrade from `upgrades.cheapest_affordable`,
    the function the sim buys with. Work the cheapest out in the test from the definitions' prices, and
    make line 143 an `assert_gte`.
  - `test_015`'s loops at 94 and 199 have no limit: each fails the test at a limit instead of hanging
    the run.
- **R6. `SimEvent.Kind` is free of the test.** `test_005::test_r18_plays_like_the_design` (977-978) names
  the kinds every run must produce instead of taking the enum from `ENCOUNTER_STARTED` to its end, and the
  sentence in `sim/sim_event.gd` that orders the enum for that test goes.
- **R7. Dead setup is gone.** The audio-bus unmute in `after_each` of `test_039` and
  `test_051_talent_trees_and_paragon` (nothing there can mute it); `test_049`'s
  `_ui.bar.set_process(false)` (735: `UiButtonBar` has no `_process`); `test_036`'s unused `STEP`;
  `test_051`'s `_of` in favour of `ColonyTest._of_kind`.

## Interfaces

None.

## Acceptance

| Requirement | Test | What it shows |
|---|---|---|
| R1 to R4, R7 | (lane's report) | each row as done or left, with the reason; the test names before and after; lines of `tests/` before and after |
| R5 | `test_022::test_r2_buys_the_cheapest` | fails when `cheapest_affordable` is made to return the dearest, passes on today's code |
| R5 | (lane's report) | each bounded loop fails at its limit when the fight is made endless |
| R6 | `test_005::test_r18_plays_like_the_design` | passes with a kind moved to another place in the enum (tried, not committed) |

## Out of scope

- Zak's decisions, left as they are: the balance runs (`test_004` R12, `test_005` R18, `test_016` R6,
  `test_035` R6, `test_036`, `test_051` R11, `test_052` R10); the three files that each run seeds 1 to 5
  for an hour; `test_036`'s `KILL_VALUE`s; `test_049` R10's old-formula pin; `test_052`'s
  `HASHES_BEFORE`; `test_015` R6.
- Splitting long tests, renaming, moving files. Any other change under `sim/` or `game/`.

## Paths

- `tests/acceptance/`: `test_005_expedition_loop.gd`, `test_013_deeper_monsters.gd`, `test_015_standing_room.gd`,
  `test_016_camp_upgrades.gd`, `test_020_guardians.gd`, `test_022_auto_buy.gd`, `test_023_steady_monster_ids.gd`,
  `test_025_microskills_and_side_quests.gd`,
  `test_035_party_orders.gd`, `test_036_a_livelier_start.gd`, `test_039_the_countdown.gd`,
  `test_040_orders_that_hold.gd`, `test_044_old_saves_level_up.gd`, `test_049_areas.gd`,
  `test_051_every_ability_is_seen.gd`, `test_051_talent_trees_and_paragon.gd`, `test_052_resources_kept.gd`
- `tests/unit/test_simulation.gd`, `tests/unit/test_main_save.gd`
- `sim/sim_event.gd` (the comment only)

## Open questions
