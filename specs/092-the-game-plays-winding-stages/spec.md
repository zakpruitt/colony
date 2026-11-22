# 092 — The game plays winding stages

- **Status:** landed (provisional)
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 091
- **Pull request:** [#92](https://github.com/zakpruitt/colony/pull/92)

## Intent

Specs 088 to 091 built winding stages and a preview that plays them. This spec makes them the game: a new
game, a loaded save, the time away and the showcase all play stages three floors tall. It switches the game
only. Tests that make their own flat simulation keep it (a trial with winding as the default everywhere
failed 47 of 112 test scripts; those move later, in batches, and the flat generator goes with the last), so
this lane repairs just the tests that start the real game and expected a row of rooms.

## Requirements

- **R1. A new game is winding.** The simulation `Main` makes for a new game is `Labyrinth.Shape.WINDING`,
  in every area.
- **R2. A saved game comes back winding, with its progress.** A save of any version loads through `Main`
  as a winding simulation with the same gold, heroes, upgrades, talents, orders, resources, areas, safe
  and furthest stages and target as it loads with today; the party stands at the `entry` of its safe
  stage. Nothing is added to the save and `SAVE_VERSION` stays 8: the shape is not saved, it is what the
  game plays. `Simulation.from_save(data)` with no shape still gives a flat simulation, so the
  simulation's own tests stand.
- **R3. Time away is played on winding stages.** The replay of a loaded save steps the winding simulation
  `Main` loaded, and the away report tells of it.
- **R4. The showcase plays every moment on winding stages.** Every row of `Showcase.ROWS` begins and is
  seen as it is today (the showcase's own test passes): the cuts that place the party (to the way on, to a
  guardian's room, to a side quest) put it by course distance, entering the room from the side the course
  comes from, and no showcase code writes `Expedition.x` as a world column or reads a shaft.
- **R5. The preview is gone.** `game/dev/winding.tscn` and `winding_preview.gd` are removed with their
  test (`test_r7_the_preview_plays_a_winding_game`), their rows in `CLAUDE.md` and the wiki, and the
  harness lesson about shooting one moment of the preview is reworded for the game (a throwaway scene
  whose script `extends Main`).
- **R6. The tests that start the game hold on winding stages.** The existing tests listed in Paths fail
  today only because the game they start is now winding (24 tests in 11 scripts in the lead's trial).
  Each is repaired to prove what it proved, on a winding stage, in a situation at least as hard: a stage
  further on is still another stage, a real click is still a real click, a count is still counted. None
  is removed, none is made to build a flat game instead, and the lane's report lists each with one line
  on what changed. A test that turns out to prove something only a flat stage has is reported, not cut.
- **R7. The opening keeps its pace, and the lane says how it reads.** The lane reports
  `python tools/dev.py sim --winding --timeline --seed=N --minutes=30 --buy-upgrades --spend-talents` for
  N = 1 to 3 beside the same flat runs (the time of each first), and looks at the game itself for five
  game minutes in shots at 1280x720 and `--ui-room=960x540`, and at the showcase's shots, saying what it
  saw. Retuning is not this spec's: the numbers are for Zak.
- **R8. The wiki says what a stage is now.** `docs/wiki/index.html` describes a stage as it plays: floors,
  ladders, a doorway in and a doorway on.

## Interfaces

```gdscript
# sim/simulation.gd
static func from_save(data: Dictionary, shape: Labyrinth.Shape = Labyrinth.Shape.FLAT) -> Simulation
```

`Main` passes `Labyrinth.Shape.WINDING` to both. Nothing else in `sim/` changes: `Simulation.new(seed)` and
`Labyrinth.new(seed)` stay flat, `Expedition.monster_id` keeps its span, and `python tools/dev.py sim`
stays flat without `--winding`.

## Acceptance

In `tests/acceptance/test_092_the_game_plays_winding_stages.gd` (extends `ColonyTest`):

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_a_new_game_is_winding` | `make_main()`'s simulation is winding; after a journey to a second area that area's labyrinth is too; the stage on screen has a ladder |
| R2 | `test_r2_a_save_comes_back_winding_with_its_progress` | a version 8 save and a version 1 save written to the store: `Main` loads each winding with every field of progress equal to what `Simulation.from_save(data)` gives flat, the party at `entry` of its safe stage |
| R2 | `test_r2_from_save_alone_is_flat` | `Simulation.from_save(data)` is flat, with the shape winding |
| R3 | `test_r3_time_away_is_played_winding` | a stamped save an hour old: the replayed simulation is winding and the report counts fights |
| R4 | `test_r4_the_showcase_cuts_by_the_course` | after each of the three cuts the party stands on its course, in or beside the room meant, facing into it along the course |
| R5 | `test_r5_the_preview_is_gone` | the scene does not exist |

R4's "every row plays" is the showcase's own test (spec 018's). R6 is the listed tests passing and the
lane's list. R7 and R8 are the lane's report and Zak's playtest.

## Out of scope

- Any test not listed in Paths. If one fails, stop and report it.
- Moving tests that make their own flat simulation or world to winding; removing the flat generator, the
  un-zoned view, the demos, `floor_y`, `shaft_down` or `shaft_column`; widening `monster_id`.
- Side paths, the dark, room shapes, retuning.

## Paths

- `game/main.gd`, `game/dev/` (the showcase; the preview's removal), `game/save/` if the replay needs it
- `game/hud/depth_ladder.gd`, `game/hud/goals.gd`: only where each asks whether a stage's guardian is
  beaten, which reads the room the way on leaves from by the course
  (`ChamberRules.way_on_room(level.course)`) instead of a shaft's room, null on a winding stage
- `sim/simulation.gd` (`from_save`'s parameter only)
- `tests/acceptance/test_092_the_game_plays_winding_stages.gd` (new), `tests/colony_test.gd`, `tests/support/`
- The tests the trial saw fail, to repair as R6 says: `test_014_save_progress.gd`,
  `test_018_seeing_the_loop.gd`, `test_032_game_speed.gd`, `test_035_party_orders.gd`,
  `test_038_rough_edges.gd`, `test_049_areas.gd`, `test_054_zones_on_screen.gd`,
  `test_061_the_frame_of_the_screen.gd` (and its test base), `test_062_goals_stages_and_news.gd` (and
  `frame_062_test_base.gd`), `test_066_milestones_announced.gd`, `test_080_frame_pieces.gd`,
  `test_019_away_progress.gd` (its reference loads the save in the shape `Main` plays), all under
  `tests/acceptance/`; and `test_090_a_winding_stage_drawn.gd` (its R7 test goes)
- `docs/architecture.md`, `docs/wiki/index.html`, `CLAUDE.md` (the preview's rows and lesson)

## Open questions

None.
