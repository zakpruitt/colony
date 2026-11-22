# 093 — Side paths and caches

- **Status:** landed (provisional)
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 092
- **Pull request:** [#93](https://github.com/zakpruitt/colony/pull/93)

## Intent

A winding stage still has one way through it. This spec adds ways off it: one to three **side paths** on
every winding stage, each closed by a **gate** that one microskill opens (a lock for the Lockpicker, rubble
for the Strongarm, a rune seal for the Runereader, a hidden crack for the Trapspotter) and ending in a small
room with a **cache**: gold, XP and a good haul of the area's resource, worth several fights. The party
takes every side path it can open. Who is in the party and what they have learned now changes where it goes
and what it brings home. This spec is the rules; specs 094 and 095 put the gates and caches on screen and into
words, and spec 096 adds the order to press on past them (it changes the save, so it is its own lane).

## Requirements

- **R1. Every winding stage has side paths.** A winding level has 1 to 3 side paths
  (`LabyrinthLevel.side_paths`), as many of three as fit; a flat level has none, so nothing changes for a
  flat simulation: its hashes, saves and tests stand. (A level where none fits has none; over the seeds
  tested none is such.) Each side path leaves the main course at a point in a room that is neither the
  first nor the last, and goes by its own ladder to a neighbouring floor, or along the room's floor to a
  free side wall and its own tunnel (4 to 10 long), to a cache room 8 to 12 wide and 4 to 5 tall that
  nothing else joins. The gate stands on the side path: at the head or foot of its ladder in the room it
  leaves, or at the mouth of its tunnel, at least 2 tiles from the columns of a main route ladder and from
  a doorway. No room has two gates. **The main route is untouched**: `chambers`, `tunnels`, `ladders`,
  `open_rects()` and the course of every level are what they were before this spec for the same seed
  (spec 089's and 091's tests pass unedited); a side path's room, tunnel and ladder live on the
  `SidePath`, rolled from their own stream and fitted round the route by spec 089's rules for rooms (no
  overlap, earth between, inside the band). A level's side paths depend only on the seed, the area and
  the stage.
- **R2. Gates are content.** A gate is a `GateDef` under `data/gates/` (id, name, description, the
  microskill that opens it, the seconds it takes: 3 to 6), listed by `Content.gate_ids()` and checked by
  the `data` step. This spec adds four: `locked_gate` (lockpicker), `rubble` (strongarm), `rune_seal`
  (runereader), `hidden_crack` (trapspotter). Each side path's gate is drawn evenly from them.
- **R3. The party opens what it can.** When a travelling party's anchor reaches the point where a side
  path leaves (`SidePath.at`) with a full cache behind it and a living hero has the gate's microskill (the
  lowest hero id first), the party turns onto the side path's course, stops at the gate, that hero works
  for the gate's seconds (`WORKING`, with `GATE_STARTED` and `GATE_OPENED`), and the party walks on to the
  cache room's far wall. On entering the cache room it opens
  the cache (R4), then walks back to where it left the main course and goes on the way it was going. It does this whichever
  way along the main route it is travelling, on its way to another stage or pacing its target stage.
- **R4. A cache pays what exists.** Opening a cache gives, at its stage: gold worth
  `SidePathRules.CACHE_GOLD_KILLS` (6) average kills there, XP worth `CACHE_XP_KILLS` (3) to every living
  hero, and `CACHE_DROPS` (3) times a large monster's drop of the area's resource, with `CACHE_OPENED` and
  the usual `GOLD_GAINED`, `XP_GAINED` (and what a level brings) and `RESOURCE_GAINED`. The gold is raised
  by the gold upgrade as a kill's is. The numbers are tunable constants.
- **R5. A cache refills slowly, and the gate closes with it.** An opened cache is empty for
  `SidePathRules.REFILL_SECONDS` (600); until then the party walks past its gate, which stands open. When
  it refills the gate is closed again. A wipe or a change of stage does not refill it sooner; arriving in
  an area by journey finds every cache full, as it finds every chamber fresh.
- **R6. A gate nobody can open is passed, and said once.** With no living hero able, the party walks on
  and `GATE_SEALED` is reported once for that gate until the party next arrives on the stage (the gate's
  position in `Content.gate_ids()` and the microskill's). No harm comes of it.
- **R7. A run with no gate opened is what it was, and nothing is saved.** A party that opens no gate (a
  flat simulation; a winding one whose heroes have no microskill yet) adds nothing to the state hash
  beyond what it had before this spec. The save is unchanged (`SAVE_VERSION` stays 8, `to_save()` has the
  keys it had): a loaded game finds every cache full and every gate closed.
- **R8. A side path is a quiet place.** A cache room and a side path's tunnel hold no monsters and no side
  quest. A party on a side path does not count as having left the stage for its timers, and a target
  asked for while it is there applies when it is back on the main course; a journey to another area leaves from
  where it stands, as today.
- **R9. A run is better for exploring.** Over seeds 1 to 5, 30 minutes of `sim --winding` with upgrades
  bought and talents spent, every seed opens at least one cache, and its gold plus its resource count is
  higher than the same run on `dev` before this spec in at least four of the five. The lane's report gives
  both columns (stage reached, gold, resources, caches opened, wipes) for the lead and Zak.

## Interfaces

```gdscript
# sim/labyrinth/side_path.gd
class_name SidePath
extends RefCounted
var gate: StringName          # a GateDef id
var at: float                 # the distance along the level's main course where the side path leaves
var course: StageCourse       # from that point to the cache room's far wall
var gate_at: float            # the distance along `course` where the gate stands
var room: LabyrinthChamber    # the cache room (kind CACHE); not in LabyrinthLevel.chambers
var tunnel: Rect2i            # its tunnel, or an empty rectangle
var ladder: Rect2i            # its ladder (as LabyrinthLevel.ladders holds one), or an empty rectangle

# sim/labyrinth/labyrinth_level.gd
var side_paths: Array[SidePath] = []
## The open rectangles of the side paths: every cache room, side tunnel and side ladder.
func side_rects() -> Array[Rect2i]
## The side paths' ladders.
func side_ladders() -> Array[Rect2i]

# sim/labyrinth/labyrinth_chamber.gd
enum Kind { START, PLAIN, DEN, VAULT, CACHE }

# sim/defs/gate_def.gd
class_name GateDef
extends ContentDef
@export var id: StringName
@export var display_name: String
@export var description: String
@export var microskill: StringName
@export var work_seconds: float

# sim/expedition/expedition.gd
## The side path the party is on (its place in the level's side_paths), or -1 on the main route.
var side_path: int = -1

# sim/expedition/side_path_rules.gd  (read-only questions, and the cache's numbers)
class_name SidePathRules
## True if the cache of side path [param index] on [param stage] is full at the run's tick.
static func is_full(run: Expedition, stage: int, index: int) -> bool
## The hero who would open side path [param index]'s gate now, or null.
static func opener(run: Expedition, stage: int, index: int) -> Hero

# sim/sim_event.gd: GATE_STARTED, GATE_OPENED, GATE_SEALED, CACHE_OPENED
```

While the party is on a side path, `Expedition.x` is its distance along that path's course and
`PartyPlaces.course(run)` gives that course, so everything that asks the course (the heroes' places, the
world's facing, `Expedition.chamber()`) answers for the side path. The heroes behind the anchor wait at the
gate until the line has room for them. `Expedition.working_quest()` stays `&""` while a gate is worked;
`worker_id()` and `work_progress()` answer for it.

`GATE_STARTED`: source the worker, target the gate's position in `Content.gate_ids()`, amount the work in
ticks. `GATE_OPENED`: source the worker, target the gate's position, amount the side path's index.
`GATE_SEALED`: target the gate's position, amount the microskill's position. `CACHE_OPENED`: amount the
side path's index; the gains follow it on the same tick.

On a side path `Expedition.chamber()` is the cache room while the anchor is inside it, and
`Expedition.chamber_index` is -1 (the lane says in its report what else reads the index and how it
answers).

`Expedition` stays at 20 public methods and `expedition.gd` within 900 lines: the side path's travel and
work live in a script of their own under `sim/expedition/`, as `QuestWork` does.

The game's part is only this: the zoned view cuts `side_rects()` out of the earth with the stage and
draws `side_ladders()` as it draws a ladder; the heroes climb a side ladder as they climb any (the
`LadderRoute` is given the side ladders too); the ambience keeps its props clear of a side ladder's
columns and of a side tunnel's mouth. A cache room is bare and unlit but for the party's light, and
nothing is drawn for a gate or a cache: spec 094.

## Acceptance

In `tests/acceptance/test_093_side_paths_and_caches.gd` (extends `ColonyTest`):

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_every_winding_stage_has_side_paths_that_fit` | 40 seeds, stages 1 to 12: counts, where each leaves, sizes, spec 089's room rules with the cache rooms in, one gate a room, gates clear of the route's ladders and of doorways, each cache room joined only by its path; a flat level has none |
| R1 | `test_r1_the_main_route_is_unchanged` | a hash of `chambers`, `tunnels`, `ladders`, `open_rects()` and the course for 20 seeds and 6 stages equals the one recorded on the code before this spec (the lane records it first) |
| R1 | `test_r1_the_view_cuts_the_side_paths` | on a zoned view of 5 stages every tile of `side_rects()` is open, a ladder is drawn on every tile of `side_ladders()`, and a hero sent down a side path is in an open tile at every frame |
| R2 | `test_r2_gates_are_data` | the four gates load, name real microskills, and a broken one reports its problem; over 400 side paths each gate is seen |
| R3 | `test_r3_the_party_opens_a_gate_and_comes_back` | a party with the skill: stops at the gate, the right hero works the right time, walks in, opens the cache, returns to the gate and goes on the way it was going; from both directions |
| R4 | `test_r4_a_cache_pays_gold_xp_and_the_areas_resource` | the three amounts on stages 1 and 6 in two areas, with and without the gold upgrade, and the events in their order |
| R5 | `test_r5_an_open_cache_is_passed_until_it_refills` | passes with no stop before 600 s, opens again after; a wipe and a stage change in between change nothing; a journey away and back finds it full |
| R6 | `test_r6_a_gate_nobody_can_open_is_said_once` | no hero with the skill, and the one hero with it dead: walked past, one `GATE_SEALED`; a second after leaving the stage and coming back |
| R7 | `test_r7_no_gate_opened_keeps_the_hash_and_the_save` | a winding run of heroes with no microskill has the hash recorded before this spec; `to_save()` has the keys it had; a game saved with a cache empty loads with it full |
| R8 | `test_r8_a_side_path_is_quiet` | no monsters or quest in any cache room over 200 levels; a target asked on a side path applies back on the main course; the stage's timer runs on through a side path |
| R9 | `test_r9_exploring_opens_caches` | the five seeds each open at least one (the comparison with `dev` is the lane's report) |

## Out of scope

- Anything under `game/` beyond what Interfaces names: gates, caches and the news are specs 094 and 095. The game plays on with the side paths'
  rooms cut out of the earth and nothing drawn for a gate or a cache (the party is seen to stop, walk into
  a small room and come back). The lane shoots that once and says how it reads.
- An order to pass side paths by, and any change to the save: spec 096.
- New microskills, a gate for the Mender, guarded caches, rare materials, traps on side paths.
- Retuning anything else, whatever R9's table shows.

## Paths

- `sim/`, `data/gates/` (new)
- `game/world/labyrinth_view.gd`, `game/world/world.gd`, `game/world/ladder_route.gd`, `game/ambience/`:
  only what Interfaces names
- `tools/godot/run_sim.gd` (the summary's `caches_opened`, printed only with `--winding`, so the flat
  baselines stand), `tools/godot/validate_data.gd` if the new kind needs it
- `tests/acceptance/test_093_side_paths_and_caches.gd` (new), `tests/support/`
- Existing tests that list every kind of content, every `LabyrinthChamber.Kind` or every `SimEvent.Kind`,
  to add the new ones only: `tests/acceptance/test_072_content_table.gd`, `test_078_sim_base_types.gd`,
  and whatever else the lane's first full run shows failing for that reason alone (named in its report)
- Existing tests that fail only because a winding stage now has side paths, each repaired to prove what it
  proved in a situation at least as hard (none removed; one line each in the report):
  - `tools/tests/godot/test_sim_winding.py` `test_r8_winding_run`: the winding summary's keys are the flat
    one's and `caches_opened`
  - `tests/acceptance/test_089_winding_stages.gd`: `test_r5_a_level_is_its_seed_area_and_stage` (every kind
    but `CACHE` is seen in `chambers`, and `CACHE` on a side path's room), `test_r7_a_run_plays_on_winding_stages`
    (the rooms of the route in order, the -1 of a side path apart)
  - `tests/acceptance/test_090_a_winding_stage_drawn.gd`: `test_r2_every_room_tunnel_and_ladder_is_open`,
    `test_r3_a_ladder_stands_between_its_rooms`, `test_r5_the_lowest_room_is_lit_as_the_highest` (the open
    tiles and ladders expected are the route's and the side paths'; nothing else is open)
  - `tests/acceptance/test_091_the_party_on_a_winding_stage.gd`: `test_r3_a_hero_climbs_the_ladder_in_its_column`,
    `test_r8_the_camera_follows_down_a_ladder` (the party is stood where no side path lies between it and
    the ladder, or the stage's caches are emptied first; the ladder is still a main route ladder)
  - `tests/acceptance/test_059_shop_map_and_tally_windows.gd` `test_r7_true_in_a_crowded_frame` (its setup
    plays on until fights were seen on more than two stages)
- `docs/architecture.md`, `docs/standards.md` (the content row), `docs/wiki/index.html`

## Open questions

None.
