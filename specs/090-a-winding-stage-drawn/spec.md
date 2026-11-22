# 090 — A winding stage, drawn

- **Status:** landed (provisional)
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 089
- **Pull request:** [#90](https://github.com/zakpruitt/colony/pull/90)

## Intent

Spec 089 makes stages three floors tall with ladders between their rooms, but the view still cuts a
16-row band with one floor out of the earth. This spec makes the zoned view, the ambience and the camera's
limits draw a winding stage whole: its rooms on their floors, its ladders, a doorway where the party
arrives and where it leaves, light and dark to its full height. It also adds a preview scene that plays a
winding game, so the lanes after this one and Zak can look. The game itself still plays flat stages, which
look exactly as they do now; where the party and the monsters stand on a winding stage is spec 091.

## Requirements

- **R1. A flat stage is drawn as it is today.** Every existing test passes with no file under `tests/`
  edited (new files, and additions to `tests/colony_test.gd` and `tests/support/` that change nothing
  existing, only). The un-zoned view, its demos and their tests are untouched and still flat.
- **R2. The zoned view cuts the whole stage out of the earth.** For a winding labyrinth the view builds
  the stage the focus is in by the labyrinth's `band_height()`: every tile of every chamber, tunnel and
  ladder of the level is open and nothing else is, earth fills the rest of the band and `SURROUND_ROWS`
  above and below it, and edges, corners and shade are drawn by the same rules as today on every floor.
  `is_open`, `visuals_at`, `open_rects_near` and `built_depths` answer for it.
- **R3. Ladders stand in the stage.** Each of the level's `ladders` is drawn with the ladder tiles from
  the upper room's floor down to the lower room's floor, with the ladder's top piece standing on the upper
  floor, as an un-zoned shaft's ladder is drawn today.
- **R4. A doorway where the party comes and goes.** `doorways(depth)` gives one doorway standing on the
  floor of the room the course's `exit` is in, centred on it, and from stage 2 on one at `entry` the same
  way; each is drawn there.
- **R5. The ambience fills the taller stage.** Torches, props, webs, drips, critters, the hoard and the
  details are placed in every room on that room's own floor and ceiling, clear of the columns of a ladder
  that meets that room (not of ladders on other floors) and of the doorways. The exposure map, the darkness
  and the light cover the stage's full band, so a room on the lowest floor is lit and shaded as one on the
  highest. A level's ambience is the same every time it is built.
- **R6. The camera stays in the stage.** The view never shows past the band's columns (as today) nor,
  for a winding stage, more than 4 rows of the earth above the band or below it; inside that it follows
  its target up and down, eased as it is sideways. A flat stage's camera moves as it does today.
- **R7. A preview that plays winding stages.** `res://game/dev/winding.tscn` is the game on a winding
  simulation with no save: `python tools/dev.py shot --scene=res://game/dev/winding.tscn` shows it and
  `godot --path . res://game/dev/winding.tscn` plays it. It is not on any menu and the game never opens it.
- **R8. It looks like a place.** The lane looks at shots of at least three stages of two areas in the
  preview, at 1280x720 and with `--ui-room=960x540`, and at 3x crops of a ladder, a doorway and a lit room
  on each floor, and says in its report what it saw. (The heroes follow the course already; monsters and
  props that stand on the wrong floor are spec 091's and are named in the report, not fixed.)

## Interfaces

Signatures that stay: `LabyrinthView.set_focus(world_tiles)`, `doorways(depth)`, `open_rects_near(depth)`,
`is_open(tile)`, `visuals_at(tile)`, `zone_look()`, `band_of(depth)`; `WorldCamera.target`, `snap_to`,
`travel`. What `set_focus` takes the stage from (the focus row over the labyrinth's `band_height()`) is the
view's own business; `World` keeps passing a point on the stage shown.

```gdscript
# game/world/world_camera.gd
## The world rows the view must stay inside, in pixels (x: top, y: bottom); Vector2.ZERO for no limit.
var rows: Vector2

# game/dev/winding_preview.gd  (the script of res://game/dev/winding.tscn)
class_name WindingPreview
extends Main
```

`World` sets `camera.rows` when the stage shown changes (the one line this spec changes in `world.gd`
besides what R2 needs); a flat stage sets no limit.

`ambience_level.gd` is 959 lines and gdlint stops a file at 1000: move a part of it into a script of its
own before adding to it.

## Acceptance

In `tests/acceptance/test_090_a_winding_stage_drawn.gd` (extends `ColonyTest`), on views and worlds made
from a winding simulation (a helper on `ColonyTest` or a fixture makes one):

| Requirement | Test | What it shows |
|---|---|---|
| R2 | `test_r2_every_room_tunnel_and_ladder_is_open` | 10 seeds, stages 1 to 4: `is_open` is true on exactly the level's open tiles across the band and the surround; `visuals_at` shows a floor edge under every room's floor and earth between floors |
| R3 | `test_r3_a_ladder_stands_between_its_rooms` | ladder parts at every tile of each ladder, the top piece on the upper floor, none elsewhere |
| R4 | `test_r4_doorways_stand_at_the_entry_and_the_exit` | rectangles and sprites for stage 1 (one) and stage 3 (two), each bottom on its room's floor line |
| R5 | `test_r5_every_room_is_dressed_on_its_own_floor` | every floor prop's bottom is its room's floor line, every torch is inside its room, nothing stands in a ladder's columns of that room or over a doorway; two builds of a level place the same things |
| R5 | `test_r5_the_lowest_room_is_lit_as_the_highest` | `exposure_at` is open inside a room of each floor and buried in the earth between |
| R6 | `test_r6_the_camera_stays_in_the_stage` | targets above, below and beside the band: the view's edges stay inside the limits at zoom 1 and 2; a target moved one floor down is followed there |
| R7 | `test_r7_the_preview_plays_a_winding_game` | the scene loads, its simulation is winding, has no save store, and steps for 30 game seconds with heroes on screen |

R1 is the unedited suite. R8 is the lane's report and Zak's playtest.

## Out of scope

- Where monsters, fighters, quest props, the fallen party, the target arrow and the revival camera stand,
  and the crossing's fade at a doorway on a winding stage: spec 091.
- The un-zoned view, `labyrinth_demo`, `ambience_demo` and their tests (spec 092 removes them).
- New tiles, new props, fog over unexplored rooms, new room shapes: spec 095.
- Making the game play winding stages.

## Paths

- `game/world/labyrinth_view.gd`, `game/world/labyrinth_tiles.gd`, `game/world/world_camera.gd`,
  `game/world/world.gd` (only what R2 and the camera's limit need)
- `game/ambience/` (not `ambience_demo.gd`)
- `game/dev/winding_preview.gd`, `game/dev/winding.tscn` (new)
- `tests/acceptance/test_090_a_winding_stage_drawn.gd` (new), `tests/colony_test.gd`, `tests/support/`
- `docs/architecture.md`, `docs/wiki/index.html`, `CLAUDE.md` (the preview's row in Commands)

## Open questions

None. (089 landed as #89: `Labyrinth.Shape.WINDING`, `band_height()`, `LabyrinthLevel.band` and `ladders`,
`Simulation.new(seed, shape)`. A ladder's last row is the floor row of the room it comes down into.)
