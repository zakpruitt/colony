# 100 — Rooms shaped like caves

- **Status:** landed (provisional)
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 094
- **Pull request:** [#98](https://github.com/zakpruitt/colony/pull/98)

## Intent

Every room of a winding stage is a box: a flat ceiling, straight walls, square corners. Zak asked
(2026-11-22) for rooms with "more shape than just a box", "shaped like a cavern or thematic to each zone".
This spec gives each room a shape of its own, drawn from the seed: an uneven ceiling, walls that lean and
step, rounded corners, each area in its own manner. It is drawing only: the floor the party walks and
fights on stays flat and the simulation's rooms are the rectangles they are. What stands in the rooms
(stalagmites, columns, each area's decoration) is spec 101.

## Requirements

- **R1. The simulation is untouched.** Nothing under `sim/` changes; state hashes and saves are as they
  are. A room's rectangle (`LabyrinthChamber.rect`) still says where the party and the monsters may be.
- **R2. A room is cut to a shape.** On a winding, zoned stage each room of the route and each cache room
  is drawn with some tiles of its rectangle left as earth, and may be opened upward past its rectangle:
  its ceiling rises and dips from column to column, its side walls lean or step inward toward the
  ceiling, and its upper corners are cut. Edges, corners and shade follow the shape by the rules the tiles
  have today. A flat or un-zoned view draws its boxes as today.
- **R3. Room to stand and to pass.** In every room: every tile of the lowest 4 rows of its rectangle is
  open (or all of it, if it is lower); every column of a ladder that meets the room is open for the
  room's whole height; every tile of the rectangle beside a tunnel's mouth, for the mouth's height and one
  row over it, is open; the two columns over a doorway are open to the doorway's top and a row over it.
  No sprite of a hero or a monster standing anywhere on the floor reaches into earth (the lane checks the
  tallest sheet and says which it is).
- **R4. The earth between places holds.** A shape opens no tile outside its room's rectangle except above
  it, in the rectangle's own columns, and never higher than the tallest a room can be (8 rows over the
  floor). No tile a shape opens is beside or diagonal to an open tile of another room, tunnel, ladder or
  side path that the rectangle does not already touch. Tunnels and ladders are as they are.
- **R5. Each area in its own manner.** The four areas differ in how they are cut, by a table of numbers
  beside `ZoneLook` (how far the ceiling may move from column to column, how wide its runs are, how far
  walls lean, whether corners are round or square): Mossy Hollow soft and rounded; the Claypits in broad
  flat steps; the Old Crypt built, with square walls, a ceiling in level runs and a raised middle; the
  Ember Deep jagged, its ceiling moving most. Across 20 rooms of each area the measures the table sets
  differ between areas as the table says.
- **R6. A room's shape is its own and stays.** The shape comes from the labyrinth's seed, the stage and
  the room alone, by no global random number: the same room is the same shape every time it is built, in
  every session, and two rooms of the same size on a stage are (nearly always) different.
- **R7. Everything else follows the shape.** `LabyrinthView.is_open` and `visuals_at` answer for the tiles
  as drawn. The ambience places what it places today by the shape: a torch on an open tile of the back
  wall with open tiles all round its flame; a web, a stalactite and a drip from the ceiling of their own
  column; nothing inside earth. The exposure map, and so the light and the shade, follow the open tiles.
  Monsters, quest and side props, gates, the fallen and the doorway stand where they stand today.
- **R8. Small rooms are still rooms.** A room 4 rows high or 10 columns wide still has a shape (by opening
  upward, R4) wherever R3 and R4 leave room for one; where they leave none it is drawn as its rectangle,
  and on 10 seeds of 4 stages at most 1 room in 10 is.
- **R9. It looks like a cave, or like its area.** The lane looks, at 1280x720 and `--ui-room=960x540`, at
  three stages of each of the four areas, and at 3x crops of a ceiling, a leaning wall, a tunnel's mouth, a
  ladder coming through a ceiling and a torch under a dip; and says what it saw, which area reads least
  like itself, and anything that floats, is buried, or is cut by an edge.

## Interfaces

```gdscript
# game/world/room_shape.gd (new)
class_name RoomShape
extends RefCounted
## The tiles of one room as drawn: its rectangle with some left as earth, and what is opened above it.

## The shape of [param room] of [param level] in [param labyrinth], cut in the manner of [param look].
static func of(labyrinth: Labyrinth, level: LabyrinthLevel, room: LabyrinthChamber, look: ZoneLook) -> RoomShape
## True if this world tile is open in the room as drawn.
func is_open(tile: Vector2i) -> bool
## The world row of the highest open tile of [param column], or the floor row + 1 outside the room.
func ceiling_row(column: int) -> int
## The world tiles the shape reaches: the room's rectangle and whatever is opened above it.
func bounds() -> Rect2i
```

`LabyrinthView.open_rects_near(depth)` keeps answering with rectangles (the rooms' are their `bounds()`);
whoever needs the truth of a tile asks `LabyrinthView.is_open`. Spec 099 (built at the same time) decides
what is seen from the level's rectangles and does not read shapes.

`ambience_level.gd` is 962 lines and gdlint stops a file at 1000: move a part of it into a script of its
own before adding to it.

## Acceptance

In `tests/acceptance/test_100_rooms_shaped_like_caves.gd` (extends `ColonyTest`), on views made from a
winding simulation, 10 seeds, stages 1 to 4 unless said:

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_the_simulation_is_as_it_was` | the state hash after 5 game minutes on 3 seeds equals the value recorded on `dev` before this spec |
| R2 | `test_r2_rooms_are_not_boxes` | in each area, most rooms have a ceiling of more than one height and at least one tile of their rectangle as earth; `visuals_at` shows an edge on every earth tile beside an open one |
| R3 | `test_r3_there_is_room_to_stand_and_to_pass` | the lowest 4 rows, every ladder's columns, every tunnel's mouth and the doorways' columns are open in every room |
| R4 | `test_r4_shapes_join_nothing` | flood-filling the open tiles from each room reaches exactly the rooms, tunnels and ladders the level joins it to; nothing is opened outside a room's columns, below its floor or more than 8 rows over it |
| R5 | `test_r5_each_area_is_cut_its_own_way` | over 20 rooms an area: the mean step of the ceiling between columns is greatest in the Ember Deep and least in the Old Crypt; the Claypits' runs are the widest; Mossy Hollow's corners are cut and the Crypt's are square |
| R6 | `test_r6_a_shape_is_the_same_every_time` | a level built twice, and by a second view, has the same open tiles; two rooms of one size on a stage differ on at least 8 of 10 seeds |
| R7 | `test_r7_the_ambience_follows_the_shape` | every torch's flame tile and its 8 neighbours are open; every ceiling prop's top is the ceiling of its column; no prop's rectangle lies in earth; `exposure_at` is open in a room's open tile and buried in a tile of its rectangle left as earth |
| R8 | `test_r8_small_rooms_have_shapes` | at most 1 room in 10 is drawn as its whole rectangle and nothing more |

R9 is the lane's report and Zak's playtest.

## Out of scope

- Anything in `sim/`: uneven floors, slopes, ledges, rooms of other sizes, tunnels that bend.
- New sprites, new props and new tiles: spec 101 (stalagmites, columns, each area's decoration). This
  spec moves what exists.
- What is seen and what is black: spec 099.
- The un-zoned view, the flat generator, `labyrinth_demo`, `ambience_demo` and their tests.

## Paths

- `game/world/room_shape.gd` (new), `game/world/labyrinth_view.gd`, `game/world/labyrinth_tiles.gd`,
  `game/world/zone_look.gd`, new scripts in `game/world/`
- `game/ambience/ambience_level.gd`, `ambience_open_map.gd`, `ambience_clearings.gd`, `ambience_prop.gd`,
  and new scripts in `game/ambience/` (not `ambience.gd`, `ambience_rooms.gd`, `ambience_darkness.gd`,
  `ambience_mood.gd` or the shaders: they are spec 099's)
- `tests/acceptance/test_100_rooms_shaped_like_caves.gd` (new), `tests/colony_test.gd`, `tests/support/`
- `tests/acceptance/test_090_a_winding_stage_drawn.gd` (its R2 says exactly the rectangles are open and
  its R5 places props by them: they follow this spec), and existing tests that fail only because a room
  is no longer its whole rectangle, each repaired to prove what it proved, none removed, one line each in
  the report
- `docs/architecture.md`, `docs/wiki/index.html`

## Open questions

None.
