# 112 — The roster: more heroes than the four who go down

- **Status:** in progress (approved 2026-11-27)
- **Milestone:** M9
- **Depends on:** 109, 110, 111 (it changes `sim/simulation.gd`, `sim/party/party.gd`, `sim/sim_event.gd`
  and `tests/colony_test.gd`, which their Paths hold; it starts only after 111 has landed)
- **Pull request:** —

## Intent

Zak decided on 2026-11-27 that Colony grows by more classes, and that heroes are got by recruiting
at camp. Today the party is fixed at the four heroes a new game makes. This spec lets the colony hold
more heroes than the four who go down. Every new class is a lucky find, as Zak chose: a cache
(spec 093) may hold a class's artifact, such as a Ranger's Whistle, and its hero then waits at camp
with a request, its price, which recruits it once paid. The player chooses which four go down. It is
the simulation and the save only. Spec 113 makes the screen follow a change of party, and spec 114 is the window to
recruit and choose in. No class can be recruited until the first new class's spec adds one, so
nothing the game does changes yet.

## Requirements

- **R1. Each new class has an artifact and a request, as data.**
  - A hero class not in `Party.STARTING_CLASSES` names its artifact (`artifact_name`, as
    `Ranger's Whistle`), the picture shown for it (`artifact_picture`, a picture id; empty for the
    shared placeholder spec 114 adds), its chance to be found in a cache (`artifact_chance`), and its
    request: gold, and optionally a count of one resource.
  - The data check refuses each of these by name, for such a class: an empty artifact name; a chance
    of 0 or less, or above 1; a gold price below 1; a resource that is not a resource; a resource
    count below 0; a count with no resource, or a resource with a count of 0. For any class: a
    `looks_like` that is not a class, or one that itself looks like another.
  - `looks_like` names the class whose pictures and sheet a class's heroes are drawn with until it
    has its own (spec 113 makes the views use it). Empty means its own.
  - The four classes in `data/heroes` keep their numbers and gain none of these values.
- **R2. Artifacts are found in caches.**
  - Each time a cache is opened, from the very first, the party may find one artifact. The
    candidates are the classes not in `Party.STARTING_CLASSES` whose artifact has not been found, in
    `Content.hero_class_ids()` order. One number from 0 to 1 is drawn; walking the candidates and
    adding up their chances, the first whose running total passes the number is found. If no total
    passes it, nothing is found.
  - The number comes from a stream forked for that cache alone
    (`fork("artifact/<area>/<stage>/<side path>/<tick>")` of the expedition's stream, as
    `ResourceDrops` forks one per kill). A fork draws nothing from its parent, and with no candidate
    nothing is forked at all. So every other roll, every state hash and every recorded baseline is
    unchanged while no class can be found, which is every run until a class spec adds one.
  - `ARTIFACT_FOUND` reports a find, after the cache's own events: its source is the hero who opened
    the gate, its target the class's place in `Content.hero_class_ids()`.
  - The roll is in a small class of its own, `ArtifactFinds`; `SidePathWalk._pay` calls it once.
    `expedition.gd` (882 of its 900 lines) does not change.
  - The chances are each class spec's to set (see "How the chances were chosen"): the first find
    within 30 minutes on most seeds, all four within a few hours, the Witch Doctor's the rarest.
- **R3. Recruiting: the request paid.**
  - A class whose artifact is found and that has no hero in the colony waits at camp
    (`Roster.is_waiting`). Its request is its price, which spec 114 words as the hero's quest:
    `Bring 300 gold and 40 Glowcaps`.
  - `roster.recruit(class_id)` pays the request. On the next step the hero joins the colony
    if the class exists and waits at camp, the colony has no hero of that class yet, and the party can
    pay both prices. The colony holds one hero of each class: every sentence in the game names a hero
    by its class ("The Knight learned Taunt"), and two Knights could not be told apart.
  - The recruit arrives at the level of the lowest-levelled hero going down, with exactly the XP that
    level takes, every talent point and paragon point it has earned unspent, every path at 0, and
    full health. It joins the bench, not the four.
  - The gold and the resource are paid. `HERO_RECRUITED` reports it: its source is the new hero's id,
    its target the class's place in `Content.hero_class_ids()`, its amount the gold paid.
  - A new hero's id is one more than the largest id in the colony.
  - A command for anything else does nothing and sends no event: an unknown class, one whose
    artifact is not found, a class already in the colony, or a price the party cannot pay.
- **R4. Choosing the four.**
  - `roster.swap(bench_id, field_id)` asks for a benched hero to go down in place of a hero going
    down. It is made on the first step on which the expedition is travelling or resting, which may be
    the next. A swap asked for while the party fights, climbs, works a quest, journeys or waits to be
    revived waits until then. `roster.waiting()` lists the swaps waiting, in the order asked.
  - When a swap is made, each hero is checked again; a swap whose heroes are no longer where it
    asked (one was swapped already) is dropped with no event.
  - The four going down always stand by role (tank, melee, ranged, healer, as `HeroClassDef.Role`
    orders them), and heroes of one role by id. The starting party already stands this way, so a new
    game is unchanged.
  - The hero who comes in stands at full health; the expedition places it by its place in the line,
    as it places every hero. The hero who leaves keeps its level, XP, talents, paragon and path XP.
  - `HERO_FIELDED` reports a swap made: its source is the hero who came in, its target the hero who
    left.
  - Waiting swaps are not saved: a swap still waiting when the game is saved is lost.
  - A command for anything else does nothing and sends no event: an id that is not benched, an id not
    going down.
- **R5. A benched hero.**
  - A benched hero earns no XP and no path XP, does no quest and opens no gate, and keeps everything
    it has. Zak's rule; the recruit's arrival level (R3) is what keeps a new hero useful.
  - Talent and paragon commands work on a benched hero exactly as on one going down (`take_talent`,
    `spend_paragon`, `reset_talents`, with the same refusals), so its tree can be planned while it
    waits.
  - `Party.hero(id)` finds a hero going down or benched. `Party.heroes` is still exactly the heroes
    going down, in formation order, and every system that reads it is unchanged.
- **R6. Saves (version 12).**
  - The save adds `bench`: the benched heroes, in id order, each saved as a hero going down is saved
    (class, level, XP, talents, paragon, paths). A round trip keeps the bench and the four.
  - The save adds `artifacts`: the class ids whose artifact has been found, in
    `Content.hero_class_ids()` order. A class keeps its artifact found once its hero has joined.
  - Ids are not saved. On loading, the heroes going down take ids 1, 2 … in their saved order, then
    the benched heroes the next ids in theirs.
  - A save of version 11 or earlier loads with an empty bench and no artifact found
    (`RosterSave.upgrade_11_to_12`).
  - The check refuses each of these by name (`bench`, `bench[1].class`, `heroes`):
    - `bench` missing or not a list;
    - a benched hero with any problem a hero going down would have, named as `bench[i]`;
    - more than four heroes going down;
    - a second hero of one class anywhere in the colony;
    - `artifacts` missing or not a list; an id in it that is not a class, is a starting class, or
      comes twice; a hero of a new class whose artifact is not in it.
- **R7. Nothing changes for a colony of four.** A new game is the four it is today. The state hash
  includes the bench and the artifacts found only while either holds something, so every recorded hash passes unchanged. A
  simulation that never recruits plays tick for tick as before.

## Interfaces

```gdscript
# sim/defs/hero_class_def.gd: new fields (appended), and one method
@export var artifact_name: String = ""
@export var artifact_picture: StringName = &""  # a picture id; &"" for the shared placeholder
@export var artifact_chance: float = 0.0        # per cache opened, above 0 and at most 1
@export var recruit_gold: int = 0
@export var recruit_resource: StringName = &""  # a ResourceDef id, or &"" for none
@export var recruit_resource_count: int = 0
@export var looks_like: StringName = &""        # a HeroClassDef id, or &"" for its own pictures
func look() -> StringName                        # looks_like, or id when it is empty

# sim/party/roster.gd: the colony's commands about who is in it. A field of Simulation, made in its
# _init: Simulation is at gdlint's 20 public methods and gains none.
class_name Roster
extends RefCounted
const FIELD_SIZE: int = 4
func _init(party: Party, expedition: Expedition) -> void
func recruit(class_id: StringName) -> void
func swap(bench_id: int, field_id: int) -> void
## The swaps asked for and not yet made, in order: (bench id, field id).
func waiting() -> Array[Vector2i]
## Its artifact found and no hero of it in the colony.
func is_waiting(class_id: StringName) -> bool
## Waiting at camp, and both prices payable now.
func can_recruit(class_id: StringName) -> bool
## The level a recruit would arrive at now.
func recruit_level() -> int
## Every class waiting at camp, in Content.hero_class_ids() order.
func waiting_at_camp() -> Array[StringName]
## How many classes not in Party.STARTING_CLASSES have no artifact found yet.
func still_hidden() -> int
## Called by Simulation.step after the talent commands: applies what may be applied, returns events.
func apply(tick: int) -> Array[SimEvent]

# sim/simulation.gd
var roster: Roster
const SAVE_VERSION: int = 12

# sim/party/party.gd
## The heroes not going down, in id order.
var bench: Array[Hero] = []
## The classes whose artifact has been found, in Content.hero_class_ids() order.
var artifacts: Array[StringName] = []
## Every hero in the colony: the heroes going down, then the bench.
func roster() -> Array[Hero]
func has_class(class_id: StringName) -> bool
# hero(id) also finds a benched hero.

# sim/expedition/artifact_finds.gd: the roll, kept out of Expedition and SidePathWalk
class_name ArtifactFinds
extends RefCounted
## Called once by SidePathWalk._pay, after the cache's own events; emits ARTIFACT_FOUND on a find.
static func on_cache(run: Expedition, opener: int) -> void

# sim/roster_save.gd: as AreaSave and ResourceSave are, so simulation.gd does not grow by much
class_name RosterSave
extends RefCounted
static func write(party: Party, data: Dictionary) -> void
static func read(sim: Simulation, data: Dictionary) -> void
static func check(problems: PackedStringArray, data: Dictionary) -> void
static func upgrade_11_to_12(data: Dictionary) -> Dictionary

# sim/sim_event.gd: two kinds among the rarer ones, before ENCOUNTER_STARTED
ARTIFACT_FOUND
HERO_RECRUITED
HERO_FIELDED
```

## How the chances were chosen

Caches opened, measured on `dev` before this spec with
`python tools/dev.py sim --seed=N --minutes=M --buy-upgrades --winding`:

| Minutes | 15 | 30 | 60 | 90 | 240 |
|---|---|---|---|---|---|
| Seed 1 | 3 | 10 | 18 | 27 | 75 |
| Seed 2 | 7 | 16 | 25 | | 85 |
| Seed 3 | 9 | 16 | 27 | | 86 |

About 20 caches an hour after the first quarter hour. A total chance near 0.2 across the four new
classes finds the first artifact by 30 minutes on about nine seeds in ten (1 - 0.8^10). Suggested
starting chances for the class specs: Ranger 0.08, Bard 0.06, Tinker 0.05, Witch Doctor 0.02. With
those, the Witch Doctor alone waits about 50 caches, two and a half hours, once the others are found,
so all four come in about three to four hours.

`Hero` gains no method (it is at 19 after spec 109). Hero ids stay far below
`Expedition.FIRST_MONSTER_ID`: one hero a class.

## Acceptance

In `tests/acceptance/test_112_the_roster.gd`, one test per requirement named `test_rN_…`, each written
before its code and seen to fail.

No class in `data/heroes` can be recruited yet, so the tests add one for their length and take it
out after, as `test_095` adds a gate to `Content`. The helper goes in `ColonyTest`, since specs 113
and 114 need it too: `add_recruit_class() -> StringName` adds a copy of the Knight under the id
`test_recruit`, its artifact `Test Whistle` at chance 0.12, priced 300 gold and 40 glowcaps,
looking like the Knight,
with a copy of the Knight's talent tree under its id. `ColonyTest.after_each` and `after_all` take
both out again when a test added them.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_artifact_and_request_as_data` | Each bad field refused by name; the four classes pass |
| R2 | `test_r2_found_in_caches` | At chance 1 the first cache opened finds it, its event after the cache's; at 0.12 a seeded run finds it on the cache its fork says; a found class is never drawn again; with no candidate, a run's events and hashes equal those of one where `ArtifactFinds` is never called |
| R3 | `test_r3_recruiting` | No recruit before the find; waiting after it; a recruit with the request paid, its level the lowest going down, its points unspent, on the bench, its id, the event. Each refusal (unknown, not found, already in, short of gold, short of glowcaps) sends nothing and takes nothing |
| R4 | `test_r4_choosing_the_four` | A swap while travelling is made on the next step, by role, at full health, with the event. One asked during a fight waits, is listed, and is made when the fight is won. A stale swap is dropped. Bad ids do nothing |
| R5 | `test_r5_a_benched_hero` | Ten won fights give the bench no XP, no path XP and no quest; a benched hero takes a node, spends paragon and resets by command |
| R6 | `test_r6_saves` | A round trip with a bench and an artifact found; ids on loading; a version 11 save loads with an empty bench and no artifact; each bad value refused by name |
| R7 | `test_r7_nothing_changes` | A new game's party; the recorded hashes; a run that never recruits equal to one before, tick for tick |

**To report for Zak:** nothing to look at. With the test class at chance 0.12, the cache and the
minute that found it on seeds 1 to 3.

## Tests that change

These name the save's version or compare a whole save. After spec 110 they hold version 11. Each may
change only for version 12, the `bench` field, or the ids a load gives. The lane lists each change
in the pull request.

- `tests/acceptance/test_014_save_progress.gd` (the version, the whole save, the pass-through)
- `tests/acceptance/test_051_talent_trees_and_paragon.gd`
- `tests/acceptance/test_092_the_game_plays_winding_stages.gd`
- `tests/acceptance/test_093_side_paths_and_caches.gd`
- `tests/acceptance/test_096_the_order_to_press_on.gd`
- `tests/unit/test_save_progress.gd` (the whole save)

Any other test that fails only for one of those reasons may change the same way, and is listed in
the pull request. A test that fails for any other reason is a bug in the lane's code.

## Out of scope

- Anything on screen (specs 113 and 114).
- A new class (each comes in its own spec, with its artifact, chance and request as data).
- Unlocks by area, guardian or depth; artifacts found anywhere but caches; a quest beyond paying
  the request.
- Two heroes of one class, hero names, dismissing a hero, a bench bigger than the classes.
- XP or path XP for a benched hero, training on the bench, a price that grows with the colony.
- Fewer than four going down while the colony has four or more, or a fifth going down.
- The headless run recruiting (`tools/godot/run_sim.gd`).

## Paths

- `sim/party/roster.gd` (new), `sim/roster_save.gd` (new), `sim/expedition/artifact_finds.gd` (new),
  each with its `.uid`
- `sim/expedition/side_path_walk.gd` (the one call in `_pay`)
- `sim/party/party.gd`, `sim/simulation.gd`, `sim/defs/hero_class_def.gd`, `sim/sim_event.gd`
- `tests/acceptance/test_112_the_roster.gd` and its `.uid`, `tests/colony_test.gd` (the helper and
  its clean-up), and the files in "Tests that change"
- `docs/architecture.md` (the roster, the save version), `docs/wiki/index.html` (only lines this
  makes false)
- `tests/acceptance/test_004_combat_core.gd` (its `_hero_def` gains an artifact name, a chance and a gold price, so a made-up class passes R1's check), and `test_109_three_paths_of_five.gd`, `test_110_ranks_by_use.gd` (their save version only)

## Open questions

None.
