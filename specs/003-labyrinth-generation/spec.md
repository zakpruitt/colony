# 003 — Labyrinth generation

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M1
- **Depends on:** none
- **Pull request:** [#3](https://github.com/zakpruitt/colony/pull/3)

## Intent

The labyrinth is where the whole game happens: an endless stack of levels, each a band of earth with chambers,
tunnels and one shaft down. This spec generates it in the simulation, from a seed, as rectangles in tile
coordinates. The expedition spec will walk a party through it and the view spec will draw it. Nothing is
drawn here. Read `docs/design/base-game.md`, "The world".

## Requirements

Coordinates are whole tiles: x to the right, y downward. Depth starts at 1.

- **R1. Endless and lazy.** `level(depth)` returns the level for any depth from 1 upward, generating it on
  first request. Asking for depth 500 does not generate the 499 above it.
- **R2. Determined by seed and depth alone.** Two labyrinths with the same seed return identical levels for
  the same depth, whatever order depths are asked for. Different seeds give different levels.
- **R3. Level band.** The level at depth `d` lies inside the band of columns `0..LEVEL_WIDTH-1` and rows
  `(d-1)*LEVEL_HEIGHT .. d*LEVEL_HEIGHT-1`. Its floor row (`floor_y`, the lowest open row of its chambers and
  tunnels) is the same for every chamber and tunnel on the level and is `(d-1)*LEVEL_HEIGHT + 11`.
- **R4. Chambers.** A level has 4 to 6 chambers, in order from left to right, not overlapping, each 12 to 24
  tiles wide and 4 to 8 tiles high, with its bottom row on the floor row. At least one tile of solid earth
  remains at the left and right edges of the band.
- **R5. Tunnels.** Each pair of neighbouring chambers is joined by exactly one tunnel: a rectangle 3 tiles
  high whose bottom row is the floor row, 4 to 10 tiles long, filling the gap between the two chambers exactly.
  So a walker on the floor row can go from the leftmost chamber to the rightmost without leaving open space.
- **R6. One shaft down, alternating sides.** Each level has one shaft down: a rectangle 2 tiles wide running
  from the row below its floor row to the floor row of the next level. Its columns lie inside a chamber of this
  level and inside a chamber of the next level, at least 2 tiles from either chamber's side walls. On odd
  depths the shaft is in the right third of the band; on even depths, the left third.
  `shaft_column(depth)` gives its left column without generating any level.
- **R7. Chamber kinds.** The first chamber of depth 1 is `START`. The chamber holding a level's shaft down is
  never a `DEN` or `VAULT`. Otherwise each chamber is `PLAIN`, `DEN` or `VAULT`, chosen by the level's random
  stream: about 60% plain, 30% den, 10% vault over many levels, and never more than one vault on a level.
- **R8. Lookup.** A level can say which chamber contains a column on the floor row (or none, inside a tunnel),
  and list every open rectangle it owns (chambers, tunnels, its shaft down).

## Interfaces

```gdscript
# sim/labyrinth/labyrinth.gd
class_name Labyrinth
extends RefCounted

const LEVEL_WIDTH: int = 120
const LEVEL_HEIGHT: int = 16
const FLOOR_ROW_IN_BAND: int = 11
const TUNNEL_HEIGHT: int = 3
const SHAFT_WIDTH: int = 2

func _init(seed_value: int) -> void
## The level at this depth (1 or more). Generated once, then cached.
func level(depth: int) -> LabyrinthLevel
## Left column of the shaft from this depth to the next. Generates nothing.
func shaft_column(depth: int) -> int
```

```gdscript
# sim/labyrinth/labyrinth_level.gd
class_name LabyrinthLevel
extends RefCounted

var depth: int
## World row of the floor: the lowest open row of every chamber and tunnel.
var floor_y: int
## Left to right.
var chambers: Array[LabyrinthChamber]
## Left to right; tunnels[i] joins chambers[i] and chambers[i + 1].
var tunnels: Array[Rect2i]
var shaft_down: Rect2i

## The chamber whose columns include this one, or null inside a tunnel or solid earth.
func chamber_at(column: int) -> LabyrinthChamber
## The chamber the shaft down leaves from.
func shaft_chamber() -> LabyrinthChamber
## Every open rectangle of this level: chambers, tunnels, then the shaft down.
func open_rects() -> Array[Rect2i]
```

```gdscript
# sim/labyrinth/labyrinth_chamber.gd
class_name LabyrinthChamber
extends RefCounted

enum Kind { START, PLAIN, DEN, VAULT }

## Position in the level, 0 at the left.
var index: int
var kind: Kind
## Open space in world tiles. rect.end.y - 1 is the floor row.
var rect: Rect2i
```

All randomness comes from `SimRng` streams forked from the labyrinth's seed by depth (for example
`fork("level/%d" % depth)`), which is what makes R2 hold. No global random functions (the `boundary` step
enforces this).

## Acceptance

In `tests/acceptance/test_003_labyrinth_generation.gd`. "Many" means at least 50 seeds times depths 1 to 40;
assertion messages include the seed and depth.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_deep_level_generates_alone` | Depth 500 is returned, with `depth == 500` and rows in its band, on a fresh labyrinth |
| R2 | `test_r2_same_seed_same_levels_in_any_order` | Depths 1..20 asked in order on one labyrinth and in reverse on another are identical, rectangle by rectangle and kind by kind |
| R2 | `test_r2_different_seeds_differ` | Two seeds do not give the same depth-1 layout |
| R3 | `test_r3_level_stays_in_its_band` | For many levels, every rectangle except the shaft lies in the band and `floor_y` is as specified |
| R4 | `test_r4_chambers_are_well_formed` | For many levels: 4 to 6 chambers, sizes in range, ordered, not overlapping, bottoms on the floor, edge margin kept |
| R5 | `test_r5_floor_is_walkable_end_to_end` | For many levels: every floor-row column from the first chamber's left to the last chamber's right is inside a chamber or tunnel; tunnel sizes in range and exactly filling the gaps |
| R6 | `test_r6_shaft_connects_to_next_level` | For many levels: the shaft is 2 wide, inside a chamber here and a chamber below with 2 tiles of margin, spans the right rows, alternates thirds, and matches `shaft_column` |
| R7 | `test_r7_chamber_kinds_follow_the_rules` | START only at depth 1 chamber 0; shaft chamber never DEN or VAULT; at most one VAULT; over many levels the mix is within 10 points of 60/30/10 |
| R8 | `test_r8_lookup` | `chamber_at` returns the right chamber for columns in chambers and null in tunnels; `open_rects` has chambers, tunnels and shaft |

## Out of scope

- Drawing anything, tiles, or decoration.
- Monsters, encounters, loot, difficulty: this spec knows nothing about what lives in a chamber.
- Movement or pathfinding of the party.
- Saving the labyrinth (it is regenerated from the seed).
- Shafts up as separate objects: the shaft into a level is the previous level's shaft down.

## Paths

- `sim/labyrinth/`
- `tests/acceptance/test_003_labyrinth_generation.gd`
- `tests/unit/test_labyrinth*.gd` (optional)
- `docs/wiki/index.html` (mark the labyrinth generation as built)

## Open questions

None.
