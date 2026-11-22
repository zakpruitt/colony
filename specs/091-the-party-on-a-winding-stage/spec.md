# 091 — The party on a winding stage

- **Status:** landed (provisional)
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 090
- **Pull request:** [#91](https://github.com/zakpruitt/colony/pull/91)

## Intent

Spec 090 draws a winding stage, but the world still stands everything on "the level's floor" and reads the
party's place as a column: on a winding stage the monsters of a lower room hang in the earth, the quest
props float, and the heroes face the wrong way in a room walked from right to left. This spec makes
everything that stands in the world stand in its own room, and makes the heroes, the camera, the target
arrow and the crossing follow the course. After it the preview scene (`res://game/dev/winding.tscn`) plays
a winding stage that reads right from start to finish; the game still plays flat stages, unchanged.

## Requirements

- **R1. A flat stage plays as it does today.** Every existing test passes with no file under `tests/`
  edited (new files, and additions to `tests/colony_test.gd` and `tests/support/` that change nothing
  existing, only).
- **R2. Monsters stand in their room.** A waiting monster's feet, a fighter's feet and a monster walking
  back to its place are on the floor line of the chamber they are in, on every floor of a winding stage.
- **R3. The heroes follow the course.** A hero's sprite goes where `Expedition.hero_position` says. On a
  ladder inside the stage it moves straight up or down the ladder's column (never across the earth
  between two floors) and is drawn climbing as on a ladder between stages today; in a room the course
  walks from right to left it faces left and walks left. A sprite that must catch up round a corner goes
  along the floor to the ladder and then along the ladder, not through the wall.
- **R4. Facing is the world's.** Wherever the world reads the party's facing for the screen (a new
  sprite, a hero with no one to face, the side a hero steps to off a guardian, the side the worker
  stands by a quest prop, the camera's look ahead), it is `PartyPlaces.world_facing`; wherever it reads
  the party's place as a point, it is `PartyPlaces.anchor`. Nothing under `game/world/` reads
  `Expedition.x` as a column or `Expedition.facing` as a screen direction. (The last sentence is for the
  reviewer.)
- **R5. Quest props and the fallen stand in their room.** A side quest's prop stands on the floor of its
  chamber, at its middle, with its bar and name over it. A wiped party lies where the simulation says it
  fell, on that room's floor, and the revival's camera goes to the `entry` of the safe stage on its room's
  floor.
- **R6. The crossing happens at the doorways.** On a winding stage the heroes fade into the doorway at
  `exit` as they reach it (by their distance from the doorway, on its floor) and stand at the doorway at
  the next stage's `entry` when the screen opens; going back, the same from `entry` to the stage before's
  `exit`. No hero is drawn anywhere else while the party changes stage.
- **R7. The arrow points the way on.** While the party is sent on (or back), the target arrow over it
  points the way it must next travel along the course to reach the doorway: left, right, up or down.
- **R8. The camera follows the party up and down.** As the leader goes down a ladder the camera eases
  after it, inside the limits spec 090 set; it looks ahead the way the party faces in the world; in a
  fight on any floor the whole fight is on screen at zoom 1.
- **R9. The preview plays through.** The lane watches the preview for five game minutes in shots (a fight
  on each floor, a ladder, a side quest, a crossing in sequence with `--count`, a wipe and revival), at
  1280x720 and `--ui-room=960x540`, and says what it saw. Anything that still reads wrong and is not this
  spec's is named in the report.

## Interfaces

No signature another spec relies on changes. `World.camera_target(feet, facing)` keeps its form; what
`World` passes as `facing` is the world's. `TargetMarker` may gain the two new directions as it likes.

## Acceptance

In `tests/acceptance/test_091_the_party_on_a_winding_stage.gd` (extends `ColonyTest`), on a world made from
a winding simulation:

| Requirement | Test | What it shows |
|---|---|---|
| R2 | `test_r2_monsters_stand_on_their_rooms_floor` | waiting monsters of every populated room of 5 stages, and the fighters of a fight in a room not on the first room's floor: feet on that room's floor line |
| R3 | `test_r3_a_hero_climbs_the_ladder_in_its_column` | stepping the party down a ladder frame by frame: every hero sprite is in an open tile at every frame, in the ladder's columns while between the floors |
| R3 | `test_r3_heroes_face_left_in_a_room_walked_leftward` | sprites' facing in such a room, walking and with no one to face |
| R4 | `test_r4_the_worker_and_the_guardians_side_follow_the_world` | in a room walked leftward the worker stands right of the prop; a hero on the guardian steps back to the right |
| R5 | `test_r5_props_and_the_fallen_are_in_their_room` | a quest prop in a lower room stands on its floor line; a party wiped there lies on it; the revival camera's end is at the safe stage's entry |
| R6 | `test_r6_the_crossing_is_at_the_doorways` | through a whole crossing on and one back: heroes fade at the leaving doorway, none is visible in the dark, all stand at the arrival doorway after |
| R7 | `test_r7_the_arrow_points_along_the_course` | the arrow's direction in a room walked right, one walked left, and at the head and foot of a ladder |
| R8 | `test_r8_the_camera_follows_down_a_ladder` | the camera's y moves from one floor's rest to the next as the party climbs, and a fight on the lowest floor is inside the view |

R1 is the unedited suite. R9 is the lane's report and Zak's playtest.

## Out of scope

- Making the game play winding stages, the showcase on winding stages, the un-zoned view: spec 092.
- Anything in `sim/`. If a place the world needs is missing from the simulation, stop and report.
- New art, new effects, the dark over unexplored rooms.

## Paths

- `game/world/` (not `labyrinth_view.gd`, `labyrinth_tiles.gd`, `labyrinth_demo.gd`)
- `tests/acceptance/test_091_the_party_on_a_winding_stage.gd` (new), `tests/colony_test.gd`, `tests/support/`
- `docs/architecture.md`

## Open questions

None. (090 landed as #90: `ColonyTest.winding_simulation`, `winding_labyrinth` and `zoned_view` make the
test's world; `WorldCamera.rows` and `rows_of` are the camera's limits, which the revival's camera must be
let out of while it travels to another stage.)
