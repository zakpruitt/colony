# 089 — Winding stages in the simulation

- **Status:** in-progress (provisional)
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 088
- **Pull request:** —

## Intent

Spec 088 made the party walk a course. This spec makes a second shape of stage for it to walk: three floors
tall, seven to ten rooms on a route that climbs ladders and doubles back, about twice as long to cross.
The simulation can be asked for it (`Labyrinth.Shape.WINDING`, `dev.py sim --winding`) and plays a whole
run on it, but the game still makes the flat shape, because nothing on screen can draw the new one yet
(spec 090) and the tests that count rooms in a row move with the switch (spec 091).

## Requirements

- **R1. Nothing the game does changes.** A `Labyrinth` or `Simulation` made without a shape is flat, as
  today. Every existing test passes with no file under `tests/` edited, and the five `sim` runs of spec 088
  are byte-identical to `dev`'s. Nothing under `game/` changes.
- **R2. A winding stage has rooms on three floors.** A level of a `WINDING` labyrinth lies in a band 32
  rows tall (`Labyrinth.band_height()`; a flat one's is `LEVEL_HEIGHT`) and `LEVEL_WIDTH` wide, with three
  floor rows 10 rows apart. Its main route is 7 to 10 chambers in route order (`chambers[0]` is where the
  party arrives, the last is where the way on leaves), on 2 or 3 of the floors. Chambers are 10 to 22 wide
  and 4 to 8 tall, each standing on its floor row. No two open rectangles overlap (but a ladder, whose
  last row is the floor row of the room it comes down into), and two that are not
  joined have at least one row or column of earth between them; every open tile is at least one tile inside
  the band. All the numbers are named constants.
- **R3. Rooms are joined by tunnels and ladders, and the route doubles back.** Chambers next to each other
  in the route are joined either by a tunnel on their shared floor row (4 to 10 long, 3 tall, as today) or
  by one ladder between neighbouring floors: `Labyrinth.SHAFT_WIDTH` wide, from the upper room's floor to
  the lower room's, at least 2 tiles inside both rooms' side walls (`LabyrinthLevel.ladders`). Every level
  has at least one ladder; the route's world direction turns round at each ladder, so every level has a
  stretch walked right to left; and over 200 levels the route goes up a ladder in some and down in others.
- **R4. The course follows the route, and it is about twice as long.** The level's `course` runs from the
  far wall of the first room, through every room, tunnel and ladder in order, to the far wall of the last.
  `entry` is in the first room and `exit` in the last, each at least 2 tiles from the room's side walls.
  Over the first 12 stages of 40 seeds the mean distance from `entry` to `exit` is between 1.8 and 2.6
  times the flat shape's mean for the same seeds and stages (the bounds are tunable constants of the test).
- **R5. A level depends only on the seed, the area and its stage.** The same three give the same level
  whatever was asked for before it, in any order; two areas' labyrinths differ; a level's kinds are rolled
  as today (plain, den, at most one vault; stage 1's first room is the START; the first and last rooms are
  never a den or a vault).
- **R6. Changing stage takes a fixed time and lands at a door.** In a winding labyrinth a party that leaves
  from `exit` is CLIMBING for as long as `Labyrinth.LEVEL_HEIGHT` rows take at the climbing speed (the
  travel-speed upgrade shortens it as today), then stands at the next stage's `entry` facing its `exit`;
  one that leaves from `entry` to go back lands at the stage before's `exit`, facing its `entry`.
  `ClimbProgress.share` runs from 0 to 1 over it. For the first half every hero's `hero_position` is the
  point it left from, for the second half the point it lands on. Hold still turns a party on its way back
  up before a living guardian.
- **R7. A whole run plays on winding stages.** A `Simulation` made `WINDING` and stepped for 30 minutes
  with upgrades bought and talents spent (three seeds): every chamber of the stages it crossed going on was
  entered in route order; every fight's fighters stood on their room's floor row; the guardian of an area
  stood in the last room of its stage and was met there; the party was wiped, revived at `entry` of its
  safe stage and went on; it reached at least stage 3; and the run twice from the same seed ends in the
  same state hash. Side quests are met in plain rooms as today.
- **R8. The tool can ask for it.** `python tools/dev.py sim --winding …` runs the same summary on a winding
  simulation. The summary has no state hash and gains no field: the tool's test tells the two
  shapes apart by the summaries themselves. The lane's report gives, for seeds 1 to 5 at 30 minutes with `--buy-upgrades
  --spend-talents`, flat beside winding: the stage reached, the safe stage, each hero's level, the gold
  and the wipes. (The numbers are for the lead and Zak: retuning is not this spec's.)

## Interfaces

```gdscript
# sim/labyrinth/labyrinth.gd
enum Shape { FLAT, WINDING }
var shape: Shape  # read-only outside the class
func _init(seed_in: int, area_label: String = "", shape_in: Shape = Shape.FLAT) -> void
## Rows of world each stage takes: LEVEL_HEIGHT for a flat labyrinth, 32 for a winding one.
func band_height() -> int

# sim/labyrinth/labyrinth_level.gd
## The world rows and columns the level lies in.
var band: Rect2i
## The ladders inside the stage, each from the row under the upper room's floor to the lower
## room's floor row. Empty on a flat level.
var ladders: Array[Rect2i] = []

# sim/simulation.gd
func _init(seed_value: int, shape: Labyrinth.Shape = Labyrinth.Shape.FLAT) -> void
```

Every area's labyrinth has the first one's shape (`AreaTravel.labyrinth`). A simulation loaded from a save
is flat (`Simulation.from_save` takes no shape yet; spec 091 makes winding the only shape).

On a winding level `floor_y` is the first room's floor row, `tunnels` holds the level tunnels in route
order (not one per pair of rooms), `shaft_down` is an empty rectangle and `open_rects()` gives chambers,
tunnels and ladders. `Labyrinth.shaft_column()` means nothing there; nothing in `sim/` asks it for a
winding labyrinth.

`Expedition.monster_id` keeps its formula in this spec, so the recorded hashes stand: ids stay unique
within a stage of up to 16 rooms but a winding stage's rooms 8 and up share ids with the next stage's.
Spec 091 widens the span when it moves the hashes.

How the rooms are laid out is the lane's, inside R2 to R5. A way that works: choose 2 or 3 neighbouring
floors and a number of rooms for each run, lay each run out along its floor as the flat generator lays
its row, alternate the runs' directions, and stand each ladder in the columns the end rooms of two runs
share.

## Acceptance

In `tests/acceptance/test_089_winding_stages.gd` (extends `ColonyTest`):

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_a_labyrinth_is_flat_unless_asked` | `Labyrinth.new(seed)` and `Simulation.new(seed)` give levels equal, rectangle for rectangle, to a flat one's, with no ladders |
| R2 | `test_r2_rooms_stand_on_three_floors_apart` | 40 seeds, stages 1 to 12: band, floor rows, counts, sizes, no overlap, earth between unjoined rectangles, the margin |
| R3 | `test_r3_tunnels_and_ladders_join_the_route` | each pair of neighbours is joined by exactly one tunnel or one ladder that meets both rooms as R3 says; each level has a ladder and a leftward stretch; both climbing up and down are seen over 200 levels |
| R4 | `test_r4_the_course_visits_every_room_in_order` | walking the course by half tiles: `chamber_at` gives 0, 1, 2… with tunnels and ladders between, every point is an open tile's floor or on a ladder, `entry` and `exit` are where R4 says |
| R4 | `test_r4_a_stage_is_about_twice_as_long` | the two means and their ratio |
| R5 | `test_r5_a_level_is_its_seed_area_and_stage` | order of asking, two labyrinths from one seed, two areas, the kinds' rules; over 200 levels each kind is seen |
| R6 | `test_r6_a_crossing_takes_a_fixed_time_and_lands_at_a_door` | ticks CLIMBING going on and going back, with and without the travel upgrade; where and how the party stands after; positions in each half; Hold on the way back |
| R6 | `test_r6_a_wiped_party_comes_back_to_the_entry` | revival on a winding stage |
| R7 | `test_r7_a_run_plays_on_winding_stages` | the 30 minute runs |
| R8 | (in `tools/tests/godot/`) `test_sim_winding.py` | `sim --winding` prints a summary whose stage is at least 2 after 10 minutes, and differs from the flat run's hash |

## Out of scope

- Anything under `game/`: a winding stage is not drawn by this spec, and the game does not make one.
- Side paths, gates, caches, orders, new room kinds, new content.
- Retuning timers, rewards, monster counts or speeds, whatever R8's table shows.
- Removing the flat shape, widening `monster_id`, loading a winding save: spec 091.
- Editing an existing test.

## Paths

- `sim/labyrinth/`, `sim/expedition/`, `sim/simulation.gd`
- `tools/dev.py` (the `sim` command's option), `tools/godot/run_sim.gd`, `tools/tests/godot/test_sim_winding.py` (new)
- `tests/acceptance/test_089_winding_stages.gd` (new), `tests/support/` (a helper the new test shares with 088's)
- `docs/architecture.md`, `docs/wiki/index.html` (the `sim` command's row), `CLAUDE.md` (the `sim` command's row)

## Open questions

None. (088 landed as #88; its `StageCourse`, `PartyPlaces.course`, `Arrival.facing(course, at)` and
`ChamberRules.way_on_room` are what this spec builds on.)
