# 049 — Areas: several places to go instead of one descent

- **Status:** provisional (direction and the four choices below agreed with Zak 2026-11-17; text not yet read by him)
- **Milestone:** M6
- **Depends on:** 005, 013, 014, 020, 035
- **Pull request:** —

## Intent

Zak played the demo and does not want a game that only ever goes down. The labyrinth becomes a set of
**areas**, each with its own monsters and guardian, and the player chooses which one the party works in.
Inside an area the party moves through **stages** that get harder, exactly as depths did. This spec makes
that true in the simulation and keeps the screen truthful; the map to choose from (spec 053), resources
(spec 052) and how a change of stage looks (spec 054) follow it. See `docs/design/world.md`, "Areas and
skill trees".

## Requirements

- **R1. Areas are content.** Each area is a resource under `data/areas` with a name, an order, a base
  level, the monsters that live there (and the stage each first appears at), its guardian and the stage
  the guardian stands at, and the area whose guardian must be beaten to open it (none for the first).
  Four areas exist:

  | Area | Base level | Monsters (first stage) | Guardian | Opened by |
  |---|---|---|---|---|
  | Mossy Hollow | 1 | slime 1, cave bat 1, spider 2, goblin 3 | Slime King | — |
  | The Claypits | 6 | mud golem 1, clay hound 1, ogre 3 | Clay Colossus | Mossy Hollow |
  | The Old Crypt | 11 | skeleton 1, ghoul 1, wraith 3 | Bone Lord | The Claypits |
  | Ember Deep | 16 | fire imp 1, crystal beetle 1, deep horror 3 | Deep Maw | The Old Crypt |

  Every guardian stands at stage 5.
- **R2. A stage is what a depth was.** The party is in one area at one stage. Everything a depth did, a
  stage does within its area: the timer to become safe, pushing on by itself, the target, falling back to
  the safe stage after a wipe, orders. A monster at stage `s` of an area is as strong as one at depth
  `base level + s - 1` was, and timers use that level too.
- **R3. Only the area's monsters.** Chambers hold only monsters from the area's list that have appeared by
  that stage. The guardian stands at its stage and, stronger, every 5 stages after it. Stages have no end.
- **R4. The party can be sent elsewhere.** A command names an area and a stage. If the area is open, the
  party finishes any fight it is in, leaves, spends 10 seconds on the way, and arrives alive (health as it
  was) at the start of that stage, or of the area's safe stage if the stage asked for is beyond it, with
  the stage asked for as its target. A command for an area that is not open does nothing.
- **R5. Each area remembers.** Each area keeps its own safe stage and furthest stage. Coming back to an
  area starts from them, not from stage 1.
- **R6. Guardians open areas.** The first time an area's stage-5 guardian is beaten, the area it opens
  becomes open for good, and an event says so.
- **R7. Each area is its own place.** Each area has its own layout of chambers, different from the others
  for one seed and the same every time for that seed.
- **R8. Saves carry it.** The save (version 6) holds the area the party is in, each area's safe and
  furthest stage, and which areas are open. A version 5 save loads into Mossy Hollow with its safe and
  furthest depth as that area's stages, and with the Claypits, Old Crypt and Ember Deep open if its
  furthest depth was beyond 5, 10 and 15.
- **R9. The screen stays true.** Everywhere the game showed a depth it now names the area and the stage
  (`Mossy Hollow 3`): the depth panel, the ladder's heading, goals, the journal, the defeat note, the away
  report. The world shows the area the party is in and redraws on arrival. While the party is on its way
  the status line says where it is going. No new control for choosing an area is added here (spec 053).
- **R10. Same fights, checked.** A party that stays in Mossy Hollow meets monsters of the same strength,
  stage for stage, as depths 1 onward gave before. The same seed and commands still give the same run. The
  recorded-hash tests are re-recorded, and the pull request says why each changed.
- **R11. The headless run knows areas.** `python tools/dev.py sim` prints the area and stage, each area's
  progress and the open areas, and takes `--area=<id>` to send the party there at the start (an area that
  is not open is opened for that run).

## Interfaces

```gdscript
# sim/defs/area_def.gd, one .tres per area under res://data/areas
class_name AreaDef extends Resource
@export var id: StringName
@export var display_name: String
@export var order: int
@export var base_level: int
@export var monsters: Array[StringName]
@export var monster_stages: Array[int]      # same length: the first stage each appears at
@export var guardian: StringName
@export var guardian_stage: int
@export var opened_by: StringName           # &"" for an area open from the start
func validate() -> PackedStringArray

# sim/defs/content.gd
static func area(id: StringName) -> AreaDef
static func area_ids() -> Array[StringName]   # by order

# sim/expedition/expedition.gd
var area: StringName                          # the area the party is in (or heading to)
func level_at(stage: int) -> int              # base level + stage - 1, for the current area
# State gains JOURNEYING. `depth`, `target_depth`, `last_stable_depth` and `deepest_depth` keep their
# names and now mean stages of the current area.

# sim/simulation.gd
func set_destination(area_id: StringName, stage: int) -> void
func is_area_open(area_id: StringName) -> bool
func area_progress(area_id: StringName) -> Vector2i   # x safe stage, y furthest stage

# sim/sim_event.gd, both placed before ENCOUNTER_STARTED
AREA_CHANGED    # the party arrived in an area
AREA_OPENED     # an area became open
```

`MonsterDef.min_depth` goes: the area lists replace it. Shapes may change where the code suggests better;
say so in the pull request. `sim/expedition/expedition.gd` is 996 lines against a limit of 1000 and
`Simulation` is large: put the new rules in new files beside them.

## Acceptance

In `tests/acceptance/test_049_areas.gd`, plus older tests amended where they assert a depth rule that is
now a stage rule (say which).

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_areas_are_content` | The four areas load, validate, and hold the table above; a broken area (unknown monster, lists of different length, a guardian that is not a boss) fails validation |
| R2 | `test_r2_a_stage_is_a_depth` | Monster strength and the safe timer at stages of each area equal those of the matching level; a wipe returns to the area's safe stage |
| R3 | `test_r3_only_the_areas_monsters` | Over many chambers and stages of each area, no monster from outside its list or before its stage; the guardian at 5 and 10 |
| R4 | `test_r4_sent_elsewhere` | The command during travel and during a fight; the 10 seconds; arrival place, health and target; a closed area ignored |
| R5 | `test_r5_each_area_remembers` | Progress in one area, a visit to another, and the return |
| R6 | `test_r6_guardians_open_areas` | Closed before, open after, the event once, still open after a later loss |
| R7 | `test_r7_its_own_place` | Layouts differ between areas and repeat for a seed |
| R8 | `test_r8_saves` | A round trip; a version 5 save at furthest depths 3, 7 and 16; bad values refused by name |
| R9 | `test_r9_screen_names_the_area` | The texts listed, in two areas and on the way |
| R10 | `test_r10_same_fights` | Mossy Hollow stage for stage against the old depths; two runs of one seed with a journey agree |
| R11 | (`tools/tests`) | The printed fields and `--area` |

**To look at:** a shot in Mossy Hollow and one after `set_destination` to the Claypits (a throwaway
scene), with the depth panel cropped and enlarged. Describe them.

**To report for Zak:** from `dev.py sim` with `--buy-upgrades`, minutes to the first Slime King win and
the level then; and 20 minutes started in each later area at the level a party would reach it with.

## Out of scope

- A map or any control to choose an area (spec 053); resources (spec 052); how changing stage looks, and
  different tiles or colours for areas (spec 054).
- New monsters or sprites. Rebalancing beyond what R10 needs.
- Renaming `depth` in code.

## Paths

- `sim/`, `data/areas/`, `data/monsters/`
- `game/` (only what R9 needs, and to keep everything compiling)
- `tools/dev.py`, `tools/godot/`, `tools/tests/`
- `tests/`
- `docs/architecture.md`, `docs/wiki/index.html`, `CLAUDE.md` (the `sim` command's line)

## Open questions

None.
