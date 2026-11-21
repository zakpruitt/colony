# 088 — The party walks a course

- **Status:** landed (provisional)
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 078
- **Pull request:** [#88](https://github.com/zakpruitt/colony/pull/88)

## Intent

Zak asked for stages that wind: two or three floors tall, with ladders, a route that doubles back and side
paths (see "The dungeon overhaul" in `specs/README.md`). Today the party's place is a column on the one floor
row of its level, and the expedition's rules read that row, the shafts and "the leftmost chamber" directly,
so no other shape of stage can be walked. This spec gives every level a **course**, the line the party
walks, and makes the expedition ask the course for everything about place. Today's levels get a course that
is their floor row, so nothing the game does changes; spec 089 then adds stages whose course bends.

## Requirements

- **R1. Nothing the game does changes.** Every existing test passes with no file under `tests/` edited
  (new files only). The JSON of `python tools/dev.py sim --seed=N --minutes=30 --buy-upgrades
  --spend-talents` for N = 1 to 5 is byte-identical to the same runs on `dev`. Hashes and saves do not move.
  Nothing under `game/` changes.
- **R2. Every level has a course.** `LabyrinthLevel.course` is a `StageCourse`: a line of feet positions
  from one end of the level's walkable floor to the other, measured by a **distance**. It knows its two
  ends, where a party from the stage before arrives (`entry`), where the way on leaves (`exit`), which
  chamber any distance is in, and the world position and the world direction of travel at any distance. For
  the levels `Labyrinth` makes today the distance *is* the world column: the course runs from the first
  chamber's first floor column to the last chamber's last, `exit` is the middle of the shaft down, `entry`
  the middle of the shaft from above (at depth 1, the middle of the START chamber), `point_at(d)` is
  `(d, floor_y)` and `chamber_at(d)` is what `level.chamber_at(floori(d))` gives.
- **R3. The party's place is a distance along the course.** `Expedition.x` is that distance and
  `Expedition.facing` the way the party travels along it (1 toward the course's `end`, -1 toward its
  `start`). On a course that bends (a room, a ladder down, a second room below walked from right to left),
  a party sent across walks it in order: its anchor's world position (`PartyPlaces.anchor`) is always
  `course.point_at(x)`, it goes down the ladder's column, it travels left through the second room, and each
  hero behind the anchor stands `PartyPlaces.HERO_SPACING` further back along the same line, on the
  ladder if that is where the line is, never off the course. The party covers course distance at the same
  speed whether the line runs level or up a ladder.
- **R4. A fight is on its room's own floor, entered the way the party came.** In a room the course walks
  from right to left the heroes enter from the right (the battle's heroes start right of the monsters and
  face left), every fighter's position (`Expedition.hero_position`) is on that room's floor row, not the
  level's, and after the win the party gathers at its front hero's place and travels on along the course.
- **R5. Arriving, turning and holding go by the course.** A party revived, loaded or arriving from another
  area stands at `entry` (on stage 1 of an area as today) facing toward `exit`. At its target stage it
  walks to an end of the course, turns and walks to the other. Sent on, it leaves from `exit`; sent back, from
  `entry`. Under Hold it turns one tile of course short of the guardian's room, from whichever side the
  course brings it. The chambers that are always empty are the START chamber and the ones `entry` and
  `exit` are in.
- **R6. Nothing in the expedition reads the old floor.** The expedition's scripts (`sim/expedition/`) take
  every place from the course and the chamber's own rectangle. `LabyrinthLevel.floor_y`, `tunnels`,
  `shaft_down`, `shaft_chamber()` and `Labyrinth.shaft_column()` stay for `game/` (spec 090 moves it), but
  nothing under `sim/expedition/` names them, nor `Labyrinth.LEVEL_WIDTH`. (For the reviewer: a rule about
  source text is not a GUT test.)
- **R7. The files keep their room.** `expedition.gd` stays within its 900 lines and `Expedition` within
  20 public methods, with no public method added to `Expedition` (the world-facing reads are on
  `PartyPlaces`).

## Interfaces

```gdscript
# sim/labyrinth/stage_course.gd
class_name StageCourse
extends RefCounted
## The line a party walks through one stage: feet positions in world tiles joined by straight
## runs (level along a floor, or straight up a ladder), each point at a distance from the first.

## Distances of the two ends of the line, of where a party from the stage before arrives, and of
## where the way on to the next stage leaves.
var start: float
var end: float
var entry: float
var exit: float

## Starts the line at [param at], which is at [param distance] (a flat level starts at its column).
func begin(at: Vector2, distance: float) -> void
## Runs the line on to [param at], level or straight up or down. The run is inside chamber
## [param chamber_index], or in a tunnel or on a ladder (-1).
func line_to(at: Vector2, chamber_index: int = -1) -> void

## Feet position in world tiles at [param distance] (clamped to the line).
func point_at(distance: float) -> Vector2
## The world direction a party moving toward [member end] travels at [param distance]: 1 right,
## -1 left, 0 on a ladder.
func heading_at(distance: float) -> int
## True where the line runs up or down.
func on_ladder(distance: float) -> bool
## Index of the chamber the feet are in at [param distance], or -1.
func chamber_at(distance: float) -> int
## The first (x) and last (y) distance at which the feet are in chamber [param chamber_index].
func stretch_of(chamber_index: int) -> Vector2
## The distance at which the line crosses world column [param column] on the floor of chamber
## [param chamber_index] (clamped to its stretch).
func distance_in(chamber_index: int, column: float) -> float
```

```gdscript
# sim/labyrinth/labyrinth_level.gd
var course: StageCourse

# sim/labyrinth/labyrinth_chamber.gd
## The chamber's floor row: the lowest open row of its rectangle.
func floor_row() -> int

# sim/expedition/party_places.gd
## Feet position, in world tiles, of the party's anchor (the point the heroes line up behind).
static func anchor(run: Expedition) -> Vector2
## The way the party faces in the world: 1 right, -1 left (the way it last faced while on a ladder).
static func world_facing(run: Expedition) -> int
```

`Labyrinth.level(depth)` stays the one way to get a level, and a subclass may override it (the test's
hand-made labyrinth does); nothing in `sim/expedition/` reaches a level's geometry any other way.

A chamber's half-open rule holds as today: at a distance whose feet column is `rect.end.x` the party is in
the tunnel, not the chamber.

On today's levels a party that changes stage keeps its `x` as it does now (the shaft is one column through
both levels); what a bent stage does there is spec 089's.

## Acceptance

In `tests/acceptance/test_088_the_party_walks_a_course.gd` (extends `ColonyTest`), using a hand-made
labyrinth in `tests/support/bent_labyrinth.gd`: a `Labyrinth` subclass whose `level()` returns, at every
depth, a level built in the test's own code with two rooms on different floor rows joined by a ladder, the
second room walked from right to left, and a course built with `begin` and `line_to`. It takes which
room is which (plain, guardian's) from its caller.

| Requirement | Test | What it shows |
|---|---|---|
| R2 | `test_r2_todays_course_is_the_floor_row` | for 40 seeds and depths 1 to 12, the course's ends, `entry`, `exit`, `point_at`, `heading_at` (1) and `chamber_at` at every half column equal what R2 says |
| R2 | `test_r2_a_bent_course_knows_its_places` | on the hand-made level: `point_at` down the ladder keeps the column and changes the row, `heading_at` is 1, 0 then -1, `chamber_at` and `stretch_of` agree, `distance_in` of a column in the second room grows as the column falls |
| R3 | `test_r3_the_party_walks_the_bend` | stepping an expedition across the bent level: the anchor is at `point_at(x)` every tick, it is seen on the ladder, then moving left; every hero is on the course, each `HERO_SPACING` behind the last once the line is straight for that long; the course distance covered each second equals the party's speed on the floor and on the ladder |
| R4 | `test_r4_a_fight_is_entered_the_way_the_party_came` | monsters in the second room: at the first tick of the fight every hero is right of every monster, all on that room's floor row; after the win `x` is in that room's stretch and the party goes on left |
| R4 | `test_r4_a_lost_fight_falls_where_it_stood` | the party wiped there: `hero_position` of each fallen hero is on that room's floor row at the column it fell |
| R5 | `test_r5_arrival_is_the_entry_facing_the_exit` | revived and loaded parties stand at `entry` facing `exit` on the bent level; a party at its target turns at both ends; the entry's and exit's rooms hold no monsters |
| R5 | `test_r5_hold_turns_short_of_the_guardian_from_either_side` | the guardian's room placed second: under Hold the party turns one tile of course before its stretch, coming along the bend |

R1 is shown by the unedited suite and the five `sim` runs, which the lane reports with the same runs on
`dev`. R6 and R7 are for the reviewer and the `harness` step.

## Out of scope

- Any new stage shape, generator change, room count or band height: spec 089.
- Anything under `game/`, and any existing test. `game/` keeps reading `Expedition.x` as a column, which it
  still is on every level the game makes.
- Side paths, gates, caches, orders: later specs.
- Changing what a climb between stages takes or where it lands.
- Removing `floor_y`, `tunnels`, `shaft_down`, `shaft_chamber()` or `shaft_column()`.

## Paths

- `sim/labyrinth/`, `sim/expedition/`
- `tests/acceptance/test_088_the_party_walks_a_course.gd` (new), `tests/support/bent_labyrinth.gd` (new)
- `docs/architecture.md` (a "The course" section; the lines on `PartyPlaces`), `docs/standards.md` (a row:
  a question about place on a stage is asked of its `StageCourse`)

## Open questions

None.
