# 093 — Side paths and caches

- **Status:** draft
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 092
- **Pull request:** —

## Intent

A winding stage still has one way through it. This spec adds ways off it: one to three **side paths** on
every stage, each closed by a **gate** that one microskill opens (a lock for the Lockpicker, rubble for the
Strongarm, a rune seal for the Runereader, a hidden crack for the Trapspotter) and ending in a small room
with a **cache**: gold, XP and a good haul of the area's resource, worth several fights. The party takes
every side path it can open; a new order, Explore or Press on, tells it to walk past them instead. Who is
in the party and what they have learned now changes where it goes and what it brings home. This spec is the
rules; spec 094 puts the gates, caches and the order on screen.

## Requirements

- **R1. Every stage has side paths.** A level has 1 to 3 side paths (`LabyrinthLevel.side_paths`). Each
  leaves a room of the main route that is neither the first nor the last, through a gate in that room,
  along its own tunnel (4 to 10 long) or its own ladder to a neighbouring floor, to a cache room 8 to 12
  wide and 4 to 5 tall that nothing else joins. Cache rooms come after the main route's rooms in
  `chambers`, with kind `CACHE`, and follow spec 089's rules for rooms (no overlap, earth between, inside
  the band). No room has two gates. A level's side paths depend only on the seed, the area and the stage.
  The main route of every level is what it was before this spec for the same seed (the side paths are
  rolled from their own stream and fitted round it).
- **R2. Gates are content.** A gate is a `GateDef` under `data/gates/` (id, name, description, the
  microskill that opens it, the seconds it takes: 3 to 6), listed by `Content.gate_ids()` and checked by
  the `data` step. This spec adds four: `locked_gate` (lockpicker), `rubble` (strongarm), `rune_seal`
  (runereader), `hidden_crack` (trapspotter). Each side path's gate is drawn evenly from them.
- **R3. The party opens what it can.** Travelling under Explore, when the party's anchor reaches a side
  path's gate with a full cache behind it and a living hero has the gate's microskill (the lowest hero id
  first), the party stops, that hero works for the gate's seconds (`WORKING`, with `GATE_STARTED` and
  `GATE_OPENED`), and the party walks the side path's course to the cache room's far wall. On entering the
  cache room it opens the cache (R4), then walks back to the gate and goes on the way it was going. It does
  this whichever way along the main route it is travelling, on its way to another stage or pacing its
  target stage.
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
- **R7. Press on.** `Simulation.set_side_paths(Expedition.SidePaths.PRESS_ON)` applies on the next step
  with `ORDER_CHANGED` (order `PartyOrders.SIDE_PATHS`, 2); under it the party passes every gate without
  stopping and without `GATE_SEALED`. A party already on a side path finishes it. The order is saved
  (`side_paths`: `explore` or `press_on`; save version 9, older saves load as `explore`; any other value
  is refused by name). At Explore with no side path met the order adds nothing to the state hash.
- **R8. A side path is a quiet place.** A cache room and a side path's tunnel hold no monsters and no side
  quest. A party on a side path does not count as having left the main route for the stage's timers, and a
  destination, target or order asked for while it is there waits until it is back at the gate, except a
  journey to another area, which leaves from where it stands as today.
- **R9. A run is better for exploring.** Over seeds 1 to 5, 30 minutes with upgrades bought and talents
  spent, the run under Explore opens at least one cache on every seed, and its gold plus its resource count
  is higher than the same seed's under Press on in at least four of the five. The lane's report gives both
  columns (stage reached, gold, resources, caches opened, wipes) for the lead and Zak.

## Interfaces

```gdscript
# sim/labyrinth/side_path.gd
class_name SidePath
extends RefCounted
var gate: StringName        # a GateDef id
var at: float               # the distance along the level's main course where the gate stands
var course: StageCourse     # from the gate to the cache room's far wall; start is the gate
var chamber_index: int      # the cache room, in LabyrinthLevel.chambers

# sim/labyrinth/labyrinth_level.gd
var side_paths: Array[SidePath] = []
## Chambers of the main route, in route order: `chambers` without the cache rooms.
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
enum SidePaths { EXPLORE, PRESS_ON }
var side_paths: SidePaths = SidePaths.EXPLORE
## The side path the party is on (its place in the level's side_paths), or -1 on the main route.
var side_path: int = -1
## Asks for a new value of one order (PartyOrders.PACE, GUARDIANS or SIDE_PATHS); it applies from
## the next tick, and an unknown value is ignored. Replaces command_pace and command_guardian_order.
func command_order(which: int, value: int) -> void

# sim/expedition/side_path_rules.gd  (read-only questions, and the cache's numbers)
class_name SidePathRules
## True if the cache of side path [param index] on [param stage] is full at the run's tick.
static func is_full(run: Expedition, stage: int, index: int) -> bool
## The hero who would open side path [param index]'s gate now, or null.
static func opener(run: Expedition, stage: int, index: int) -> Hero

# sim/simulation.gd
func set_side_paths(order: Expedition.SidePaths) -> void

# sim/sim_event.gd: GATE_STARTED, GATE_OPENED, GATE_SEALED, CACHE_OPENED
```

While the party is on a side path, `Expedition.x` is its distance along that path's course and
`PartyPlaces.course(run)` gives that course, so everything that asks the course (the heroes' places, the
world's facing, `Expedition.chamber()`) answers for the side path. The heroes behind the anchor wait at the
gate until the line has room for them.

`GATE_STARTED`: source the worker, target the gate's position in `Content.gate_ids()`, amount the work in
ticks. `GATE_OPENED`: source the worker, target the gate's position, amount the side path's index.
`GATE_SEALED`: target the gate's position, amount the microskill's position. `CACHE_OPENED`: amount the
side path's index; the gains follow it on the same tick.

`Expedition` stays at 20 public methods (the two order commands become one) and `expedition.gd` within
900 lines: the side path's travel and work live in a script of their own under `sim/expedition/`, as
`QuestWork` does.

## Acceptance

In `tests/acceptance/test_093_side_paths_and_caches.gd` (extends `ColonyTest`):

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_every_stage_has_side_paths_that_fit` | 40 seeds, stages 1 to 12: counts, where each leaves, sizes, spec 089's room rules with the cache rooms in, one gate a room, each cache room joined only by its path |
| R1 | `test_r1_the_main_route_is_unchanged` | the main route's rectangles and course for 20 seeds equal a list recorded on the code before this spec (the lane records it first) |
| R2 | `test_r2_gates_are_data` | the four gates load, name real microskills, and a broken one reports its problem; over 400 side paths each gate is seen |
| R3 | `test_r3_the_party_opens_a_gate_and_comes_back` | a party with the skill: stops at the gate, the right hero works the right time, walks in, opens the cache, returns to the gate and goes on the way it was going; from both directions |
| R4 | `test_r4_a_cache_pays_gold_xp_and_the_areas_resource` | the three amounts on stages 1 and 6 in two areas, with and without the gold upgrade, and the events in order |
| R5 | `test_r5_an_open_cache_is_passed_until_it_refills` | passes with no stop before 600 s, opens again after; a wipe and a stage change in between change nothing; a journey away and back finds it full |
| R6 | `test_r6_a_gate_nobody_can_open_is_said_once` | no hero with the skill, and the one hero with it dead: walked past, one `GATE_SEALED`; a second after leaving the stage and coming back |
| R7 | `test_r7_press_on_passes_every_gate` | the order's event, no stop, no `GATE_SEALED`; set while on a side path the party still finishes it; the save round trip, a version 8 save, a bad value |
| R7 | `test_r7_explore_alone_keeps_the_hash` | a labyrinth stubbed to have no side paths: the hash of a run equals the one recorded before this spec |
| R8 | `test_r8_a_side_path_is_quiet` | no monsters or quest in any cache room over 200 levels; a target asked on a side path applies at the gate |
| R9 | `test_r9_exploring_pays` | the five seeds, both orders |

## Out of scope

- Anything under `game/`: gates, caches, the order's row and the news are spec 094. The game plays on with
  nothing drawn for them (the party is seen to stop, walk into a room and come back).
- New microskills, a gate for the Mender, guarded caches, rare materials, traps on side paths.
- Retuning anything else, whatever R9's table shows.

## Paths

- `sim/`, `data/gates/` (new)
- `tools/godot/run_sim.gd` (the summary's `caches_opened`), `tools/godot/validate_data.gd` if the new kind needs it
- `tests/acceptance/test_093_side_paths_and_caches.gd` (new), `tests/support/`
- `tests/acceptance/test_072_content_table.gd` and any test that lists every content kind or every
  `LabyrinthChamber.Kind` or every `SimEvent.Kind` (the lane greps `Content.KINDS`, `Kind.size()` and
  `Kind.keys()` under `tests/` and lists what it touched)
- `docs/architecture.md`, `docs/standards.md` (the content row), `docs/wiki/index.html`

## Open questions

- The exact list of existing tests the new content kind, chamber kind, events and save version touch is
  to be grepped when 092 has landed (it moves many of them).
