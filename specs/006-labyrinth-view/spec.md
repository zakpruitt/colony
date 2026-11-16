# 006 — Labyrinth view: drawing the cross-section

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M1
- **Depends on:** 002, 003
- **Pull request:** [#6](https://github.com/zakpruitt/colony/pull/6)

## Intent

The player should see an ant farm: dark earth, cut through by chambers, tunnels and shafts, scrolling
smoothly as the party moves. This spec draws the labyrinth the simulation generates, with tiles made in the
art pipeline, and adds the camera that follows a point through it. It draws no characters and is not yet in
the main scene: a demo scene shows it, and the world-integration spec will place it. Read
`docs/design/base-game.md` ("The picture", "The world") and `docs/style-bible.md`.

## Requirements

One tile is 16 pixels. World pixel position = tile position x 16.

- **R1. Earth and open space.** For any level it is showing, the view draws solid earth everywhere in the
  level's band except the level's open rectangles (chambers, tunnels, the shaft down, and the part of the
  shaft from the level above that lies in this band), which show a darker back wall instead. A helper answers
  whether a world tile is open, and agrees with the labyrinth's rectangles exactly.
- **R2. Edges read clearly.** Earth tiles that border open space are drawn differently from buried earth, so
  floors, ceilings and walls are visible as edges: the floor has a distinct walkable top, and the outline of
  every chamber and tunnel can be traced by eye. Buried earth has at least three tile variants so it does not
  look like a grid, chosen deterministically from the tile's position (the same tile always looks the same).
- **R3. Shafts are climbable-looking.** Each shaft shows a ladder or rope running its full height.
- **R4. Depth changes the look.** The earth's look shifts with depth in bands of five levels (1-5, 6-10,
  11-15, then repeating or continuing), using different tile art or palette-legal tinting, so going deeper
  feels like going somewhere. All colours stay on the palette.
- **R5. Only what is near is built.** Given a focus position, the view has built the level containing the
  focus and the levels directly above and below it (where they exist), and has freed levels more than two
  away. Moving the focus down 30 levels, one level at a time, leaves no more than five levels built and no
  orphan nodes.
- **R6. Above the first level is the surface.** Rows above depth 1 show a simple surface: sky colour and a
  ground line, so the top of the world is not a void.
- **R7. Camera.** `WorldCamera` follows a target position smoothly (it eases toward it; it does not snap, except
  through `snap_to`), keeps the view inside the band horizontally (never shows beyond column 0 or
  `LEVEL_WIDTH`), renders on whole pixels, and can be shaken: `shake(strength)` offsets it randomly for a short
  time, decaying to nothing, without moving its followed position.
- **R8. A demo shows it.** `game/world/labyrinth_demo.tscn` builds a labyrinth from a fixed seed and moves the
  focus and camera along the floor of depth 1 to the shaft, down it, and on through depth 2 and 3, looping.

## Interfaces

```gdscript
# game/world/labyrinth_view.gd
class_name LabyrinthView
extends Node2D

const TILE: int = 16

## Set before entering the tree.
var labyrinth: Labyrinth

## Tells the view where the action is, in world tiles; it builds and frees levels to suit.
func set_focus(world_tiles: Vector2) -> void
## Depths currently built, ascending.
func built_depths() -> Array[int]
## True if this world tile is open space (walkable or climbable air).
func is_open(tile: Vector2i) -> bool
## World pixel position of a world tile position (for placing things on the floor).
static func to_pixels(world_tiles: Vector2) -> Vector2
```

```gdscript
# game/world/world_camera.gd
class_name WorldCamera
extends Camera2D

## World pixel position to follow.
var target: Vector2
func snap_to(world_pixels: Vector2) -> void
func shake(strength: float) -> void
```

Tiles are `.px` sources of category `tile` under `assets/sprites/tiles/`, baked and linted. How tiles are
put on screen (a `TileMapLayer` with a `TileSet` built in code, or drawn another way) is the lane's choice;
a `TileMapLayer` per level is the expected approach.

## Acceptance

In `tests/acceptance/test_006_labyrinth_view.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_open_matches_the_labyrinth` | For 3 seeds and depths 1-4, `is_open` equals "inside some open rectangle" for every tile of the band, including the incoming shaft |
| R1, R2 | `test_r2_edges_and_variants` | A buried tile and a floor-edge tile use different tiles; at least three distinct buried variants appear in one level; rebuilding gives the same tile at the same place |
| R3 | `test_r3_shaft_has_a_ladder` | Every tile of a shaft's column range carries the ladder/rope visual |
| R4 | `test_r4_depth_bands_differ` | The earth visual at depth 3 differs from depth 8 |
| R5 | `test_r5_builds_near_frees_far` | Built depths around a focus are as specified; after walking the focus down 30 levels, at most five are built and GUT reports no orphans |
| R6 | `test_r6_surface_above_depth_one` | Tiles above row 0 are not earth and the surface node exists |
| R7 | `test_r7_camera_follows_clamps_and_shakes` | After stepping, the camera moves toward but not onto a far target; `snap_to` lands exactly; the view never leaves the band; `shake` changes the offset and it decays to zero while the followed position is unchanged |
| R8 | `test_r8_demo_runs` | The demo scene runs 120 frames without errors and the focus moves |

**To look at, and for Zak:** `python tools/dev.py shot --scene=res://game/world/labyrinth_demo.tscn --name=lab
--seconds=3 --count=6`. A chamber, a tunnel and a shaft must each be recognisable at a glance; the floor must
read as a floor; nothing may look like a debug grid. Iterate on the tile art until that is true, and describe
the shots in your report.

## Out of scope

- Characters, monsters, effects, particles, torches, lights, props and other decoration (later specs).
- Changing the main scene, labyrinth generation or the art tools (if the art tools cannot do something you
  need, report it).
- Minimap, zoom controls, input.

## Paths

- `game/world/`
- `assets/sprites/tiles/`
- `tests/acceptance/test_006_labyrinth_view.gd`, `tests/unit/test_labyrinth_view*.gd`, `tests/unit/test_world_camera*.gd`
- `docs/style-bible.md` (a tiles section), `docs/wiki/index.html`

## Open questions

None.
