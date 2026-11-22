# 093 — Side paths and caches

- **Status:** in-progress (provisional)
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 092
- **Pull request:** —

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
  (`LabyrinthLevel.side_paths`); a flat level has none, so nothing changes for a flat simulation: its
  hashes, saves and tests stand. Each side path leaves a room of the main route that is neither the first
  nor the last, through a gate in that room, along its own tunnel (4 to 10 long) or its own ladder to a
  neighbouring floor, to a cache room 8 to 12 wide and 4 to 5 tall that nothing else joins. Cache rooms
  come after the main route's rooms in `chambers`, with kind `CACHE`, and follow spec 089's rules for rooms
  (no overlap, earth between, inside the band). No room has two gates, and a gate stands at least 2 tiles
  from a ladder's columns and from a doorway. A level's side paths depend only on the seed, the area and
  the stage. The main route of every level is what it was before this spec for the same seed (the side
  paths are rolled from their own stream and fitted round it).
- **R2. Gates are content.** A gate is a `GateDef` under `data/gates/` (id, name, description, the
  microskill that opens it, the seconds it takes: 3 to 6), listed by `Content.gate_ids()` and checked by
  the `data` step. This spec adds four: `locked_gate` (lockpicker), `rubble` (strongarm), `rune_seal`
  (runereader), `hidden_crack` (trapspotter). Each side path's gate is drawn evenly from them.
- **R3. The party opens what it can.** When a travelling party's anchor reaches a side path's gate with a
  full cache behind it and a living hero has the gate's microskill (the lowest hero id first), the party
  stops, that hero works for the gate's seconds (`WORKING`, with `GATE_STARTED` and `GATE_OPENED`), and the
  party walks the side path's course to the cache room's far wall. On entering the cache room it opens
  the cache (R4), then walks back to the gate and goes on the way it was going. It does this whichever
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
  asked for while it is there applies when it is back at the gate; a journey to another area leaves from
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
var gate: StringName        # a GateDef id
var at: float               # the distance along the level's main course where the gate stands
var course: StageCourse     # from the gate to the cache room's far wall; its start is the gate
var chamber_index: int      # the cache room, in LabyrinthLevel.chambers

# sim/labyrinth/labyrinth_level.gd
var side_paths: Array[SidePath] = []
## How many of `chambers` are the main route's, in route order; the cache rooms follow them.
func route_size() -> int

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

`Expedition` stays at 20 public methods and `expedition.gd` within 900 lines: the side path's travel and
work live in a script of their own under `sim/expedition/`, as `QuestWork` does. The level's
`open_rects()` gives the side paths' tunnels, ladders and cache rooms too, so the view cuts them out of
the earth with no change of its own.

## Acceptance

In `tests/acceptance/test_093_side_paths_and_caches.gd` (extends `ColonyTest`):

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_every_winding_stage_has_side_paths_that_fit` | 40 seeds, stages 1 to 12: counts, where each leaves, sizes, spec 089's room rules with the cache rooms in, one gate a room, clear of ladders and doorways, each cache room joined only by its path; a flat level has none |
| R1 | `test_r1_the_main_route_is_unchanged` | the main route's rectangles and course for 20 seeds equal a list recorded on the code before this spec (the lane records it first) |
| R2 | `test_r2_gates_are_data` | the four gates load, name real microskills, and a broken one reports its problem; over 400 side paths each gate is seen |
| R3 | `test_r3_the_party_opens_a_gate_and_comes_back` | a party with the skill: stops at the gate, the right hero works the right time, walks in, opens the cache, returns to the gate and goes on the way it was going; from both directions |
| R4 | `test_r4_a_cache_pays_gold_xp_and_the_areas_resource` | the three amounts on stages 1 and 6 in two areas, with and without the gold upgrade, and the events in their order |
| R5 | `test_r5_an_open_cache_is_passed_until_it_refills` | passes with no stop before 600 s, opens again after; a wipe and a stage change in between change nothing; a journey away and back finds it full |
| R6 | `test_r6_a_gate_nobody_can_open_is_said_once` | no hero with the skill, and the one hero with it dead: walked past, one `GATE_SEALED`; a second after leaving the stage and coming back |
| R7 | `test_r7_no_gate_opened_keeps_the_hash_and_the_save` | a winding run of heroes with no microskill has the hash recorded before this spec; `to_save()` has the keys it had; a game saved with a cache empty loads with it full |
| R8 | `test_r8_a_side_path_is_quiet` | no monsters or quest in any cache room over 200 levels; a target asked on a side path applies at the gate; the stage's timer runs on through a side path |
| R9 | `test_r9_exploring_opens_caches` | the five seeds each open at least one (the comparison with `dev` is the lane's report) |

## Out of scope

- Anything under `game/`: gates, caches and the news are specs 094 and 095. The game plays on with the side paths'
  rooms cut out of the earth and nothing drawn for a gate or a cache (the party is seen to stop, walk into
  a small room and come back). The lane shoots that once and says how it reads.
- An order to pass side paths by, and any change to the save: spec 096.
- New microskills, a gate for the Mender, guarded caches, rare materials, traps on side paths.
- Retuning anything else, whatever R9's table shows.

## Paths

- `sim/`, `data/gates/` (new)
- `tools/godot/run_sim.gd` (the summary's `caches_opened`, printed only with `--winding`, so the flat
  baselines stand), `tools/godot/validate_data.gd` if the new kind needs it
- `tests/acceptance/test_093_side_paths_and_caches.gd` (new), `tests/support/`
- Existing tests that list every kind of content, every `LabyrinthChamber.Kind` or every `SimEvent.Kind`,
  to add the new ones only: `tests/acceptance/test_072_content_table.gd`, `test_078_sim_base_types.gd`,
  and whatever else the lane's first full run shows failing for that reason alone (named in its report)
- `docs/architecture.md`, `docs/standards.md` (the content row), `docs/wiki/index.html`

## Open questions

None.
