# 004 — Combat core: heroes, monsters and a fight

- **Status:** provisional
- **Milestone:** M2
- **Depends on:** 001
- **Pull request:** —

## Intent

Colony's heroes fight on their own, so the fight rules are the heart of the simulation. This spec adds heroes
and monsters as data, the combatants built from that data, and a `Battle` that plays one fight on a chamber
floor tick by tick and reports everything that happens as events. The expedition spec will start battles and
hand out rewards; the view specs will turn the events into animation and effects. Nothing is drawn here.
Read `docs/design/base-game.md`, "The party" and "A fight".

## Requirements

Positions are in tiles along the floor (`float`, x to the right). Time is in ticks; data files give durations
in seconds, converted with `Simulation.TICKS_PER_SECOND` and rounded to at least 1 tick.

- **R1. Heroes and monsters are data.** Four hero classes exist under `data/heroes/` and five monsters under
  `data/monsters/`, each a `.tres` file whose `validate()` reports nothing:

  | Hero | Role | Character |
  |---|---|---|
  | `knight` | TANK | Highest health and armour, melee, modest damage, stands in front |
  | `rogue` | MELEE | Fast melee attacks, highest damage per second, low health, some crit |
  | `mage` | RANGED | Long range, slow heavy hits, lowest health |
  | `cleric` | HEALER | Ranged heal, weak ranged attack, medium health |

  | Monster | From depth | Character |
  | --- | --- | --- |
  | `slime` | 1 | Slow, weak, soft: the first thing a new party kills |
  | `cave_bat` | 1 | Fast, fragile, quick weak bites |
  | `skeleton` | 2 | Even melee fighter with some armour |
  | `spider` | 3 | Ranged: spits from a distance, fragile |
  | `ogre` | 5 | Large, very high health, slow crushing hits |

  `validate()` reports a problem for: an empty id or name, health or damage below 1, a non-positive attack
  interval, range or speed, a crit chance outside 0 to 1, `gold_min > gold_max`, `min_depth < 1`, or a HEALER with heal power below 1.
- **R2. Combatants come from data.** A hero combatant is made from a class and a level (1 or more): its health
  and damage grow per level by the class's growth numbers. A monster combatant is made from a monster and a
  depth: its health and damage grow by 12% per depth below its `min_depth` (compounding). Whoever creates a
  combatant gives it its id; a battle given two combatants with the same id reports an error and is over at
  once as a monster win.
- **R3. Line-up.** A battle is given the floor span `left..right`, the heroes, the monsters, and which side the
  heroes enter from. Heroes start inside the span at their entry edge, in formation: TANK nearest the
  monsters, then MELEE, then RANGED, then HEALER, 1 tile apart. Monsters start spread over the far half of
  the span. Nobody ever leaves the span.
- **R4. Targets.** Each tick, a living combatant that is not mid-attack picks a target: the nearest living
  enemy. A HEALER instead picks the living ally (itself included) with the lowest health fraction if that
  fraction is below 0.8, and otherwise behaves like any other combatant.
- **R5. Movement.** A combatant farther from its target than its range walks toward it at its speed, and
  stops once in range. A combatant in range does not move.
- **R6. Attacks have rhythm.** A combatant in range whose cooldown is over starts an attack: a wind-up of
  `windup` seconds, then the strike, then a cooldown of `attack_interval` seconds before the next. If the
  target dies during the wind-up the strike is lost and the combatant may start again at once on a new target.
- **R7. Strikes.** A strike with range of 1.5 tiles or less lands at once. A longer-ranged strike (and every
  heal) launches a projectile that lands after `distance / PROJECTILE_SPEED` seconds (at least 1 tick) and
  still lands if the attacker dies meanwhile; if its target died first, it does nothing.
- **R8. Damage and healing.** Damage is the attacker's damage, times a roll between 0.85 and 1.15, doubled on a
  crit (the attacker's crit chance), minus the target's armour, rounded, and never below 1. Healing is the
  healer's heal power times the same roll, and never raises health above the maximum. Health never goes below 0.
- **R9. Death and the end.** A combatant at 0 health is dead: it takes no further part and cannot be targeted.
  The battle is over when every hero or every monster is dead, and reports which side won. A battle that
  reaches `MAX_TICKS` (3000) ends as a monster win, so the simulation can never hang.
- **R10. Everything is reported.** The battle records an event, stamped with the battle tick, for: an attack
  starting (who, at whom, the wind-up in ticks), a projectile launch (who, at whom, how many ticks of flight, whether it is a heal),
  a hit (who, whom, amount, crit or not), a heal (who, whom, amount), and a death (who). Events come out in
  the order they happened, once.
- **R11. Deterministic.** The same heroes, monsters, span and seed give the same events, tick for tick.
- **R12. The numbers make sense.** With the shipped data, over 200 seeds each:
  - four level-1 heroes (one of each class) beat three depth-1 slimes at least 99% of the time, with no hero dead;
  - the same party beats two depth-2 skeletons and two depth-1 bats at least 90% of the time;
  - the same party loses to six depth-5 ogres at least 90% of the time;
  - against four depth-3 skeletons, the party with its cleric wins clearly more often (at least 20 points)
    than the same party with a second rogue in the cleric's place;
  - a won fight against three slimes lasts between 5 and 40 seconds of game time.

## Interfaces

```gdscript
# sim/defs/hero_class_def.gd
class_name HeroClassDef
extends Resource

enum Role { TANK, MELEE, RANGED, HEALER }

@export var id: StringName
@export var display_name: String
@export var role: Role
@export var max_health: int
@export var damage: int
@export var armor: int
@export var attack_interval: float  # seconds between strikes
@export var windup: float           # seconds before a strike lands or launches
@export var attack_range: float     # tiles
@export var move_speed: float       # tiles per second
@export var crit_chance: float      # 0 to 1
@export var heal_power: int         # 0 for classes that do not heal
@export var health_per_level: int
@export var damage_per_level: int

func validate() -> PackedStringArray
```

```gdscript
# sim/defs/monster_def.gd
class_name MonsterDef
extends Resource

enum Size { SMALL, LARGE, BOSS }

@export var id: StringName
@export var display_name: String
@export var size: Size
@export var min_depth: int
@export var max_health: int
@export var damage: int
@export var armor: int
@export var attack_interval: float
@export var windup: float
@export var attack_range: float
@export var move_speed: float
@export var crit_chance: float
@export var xp: int
@export var gold_min: int
@export var gold_max: int

func validate() -> PackedStringArray
```

```gdscript
# sim/defs/content.gd
class_name Content
extends RefCounted
## Loads and caches the definitions under res://data.
static func hero_class(id: StringName) -> HeroClassDef
static func monster(id: StringName) -> MonsterDef
static func hero_class_ids() -> Array[StringName]
static func monster_ids() -> Array[StringName]
```

```gdscript
# sim/combat/combatant.gd
class_name Combatant
extends RefCounted

enum Team { HEROES, MONSTERS }
enum State { IDLE, MOVING, WINDUP, DEAD }

var id: int
var team: Team
## The id of the HeroClassDef or MonsterDef this was made from.
var def_id: StringName
var role: HeroClassDef.Role  # MELEE or RANGED for monsters, by range
var level: int               # hero level, or monster depth
var x: float
var health: int
var max_health: int
var state: State
## Id of the current target, or -1.
var target_id: int

static func from_hero(def: HeroClassDef, hero_level: int, combatant_id: int) -> Combatant
static func from_monster(def: MonsterDef, depth: int, combatant_id: int) -> Combatant
func is_alive() -> bool
func health_fraction() -> float
```

```gdscript
# sim/combat/battle.gd
class_name Battle
extends RefCounted

enum Result { ONGOING, HEROES_WON, MONSTERS_WON }

const MAX_TICKS: int = 3000
const PROJECTILE_SPEED: float = 12.0  # tiles per second
const MELEE_REACH: float = 1.5        # strikes at or under this range land at once
const HEAL_THRESHOLD: float = 0.8

var tick: int
var heroes: Array[Combatant]
var monsters: Array[Combatant]

## heroes_from_left: true if the heroes enter at `left` and face right.
func _init(
	heroes_in: Array[Combatant], monsters_in: Array[Combatant],
	left: float, right: float, heroes_from_left: bool, rng: SimRng
) -> void
## Advances the fight by one tick. Does nothing once the battle is over.
func step() -> void
func result() -> Result
func combatant(id: int) -> Combatant
## The events recorded since the last call, oldest first.
func drain_events() -> Array[SimEvent]
```

```gdscript
# sim/sim_event.gd
class_name SimEvent
extends RefCounted
## One thing that happened in the simulation, for the view to show.

enum Kind { ATTACK_STARTED, PROJECTILE_LAUNCHED, HIT, HEALED, DIED }

var kind: Kind
var tick: int
var source_id: int = -1
var target_id: int = -1
## Damage or healing done; flight time in ticks for PROJECTILE_LAUNCHED; wind-up in ticks for ATTACK_STARTED.
var amount: int = 0
## Crit for HIT; "is a heal" for PROJECTILE_LAUNCHED.
var flag: bool = false
```

`Combatant` also exposes its battle stats as public fields (`damage`, `armor`, `crit_chance`, `heal_power`,
`attack_range`, `move_speed`, `windup_ticks`, `attack_interval_ticks`). When a battle ends, pending wind-ups
and projectiles in flight are dropped with no event; a wind-up is cancelled with no event when its target
dies. Heroes act before monsters within a tick.

Later specs add kinds to `SimEvent.Kind` (always at the end) and fields with defaults. Tuning numbers live in
the `.tres` files; the lane chooses them so R12 holds and each class and monster has the character R1 gives it.

## Acceptance

In `tests/acceptance/test_004_combat_core.gd`. Tests build small battles directly; where exact numbers matter
they use definitions created in the test, not the shipped data, so retuning the data cannot break them.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_shipped_content_is_valid` | The four classes and five monsters load through `Content` and validate clean, with the roles, sizes and depths above |
| R1 | `test_r1_validate_reports_each_problem` | Each invalid field listed gives a problem line |
| R2 | `test_r2_combatants_scale_with_level_and_depth` | A level-3 hero and a monster 2 depths below its minimum have the specified health and damage, and the ids they were given; a battle with a duplicated id is over as a monster win |
| R3 | `test_r3_line_up` | Formation order and spacing from both entry sides; monsters in the far half; all inside the span |
| R4 | `test_r4_targets_nearest_enemy_and_healer_prefers_hurt_ally` | Nearest-enemy choice; a healer targets an ally at 50% health, and an enemy when all allies are above 80% |
| R5 | `test_r5_walks_into_range_then_stops` | A melee combatant closes at its speed and stops within range; a ranged one already in range does not move |
| R6 | `test_r6_attack_rhythm` | Strikes land `windup` after starting and repeat every `windup + attack_interval`; a target dying mid wind-up cancels the strike |
| R7 | `test_r7_melee_lands_at_once_projectiles_fly` | Melee hit on the strike tick; ranged hit after the flight time; a projectile whose attacker died still lands; one whose target died does nothing |
| R8 | `test_r8_damage_and_healing_rules` | Over many seeds: damage within the roll range, crits doubled, armour subtracted, minimum 1; heals capped at maximum health |
| R9 | `test_r9_death_and_result` | The dead are never targeted and never act; result is right for each winner; a stalemate ends at `MAX_TICKS` as a monster win |
| R10 | `test_r10_events_tell_the_whole_story` | A scripted one-on-one fight emits exactly the expected sequence of kinds with the right ids, amounts and ticks, and `drain_events` returns each once |
| R11 | `test_r11_same_seed_same_fight` | Two battles with the same inputs and seed produce identical event lists; a different seed does not |
| R12 | `test_r12_balance_targets` | The five balance statements, on the shipped data |

## Out of scope

- XP, gold, loot and levelling up (the monster's `xp` and `gold` fields are data only here).
- Choosing which monsters appear, the labyrinth, travel, resting, reviving: the expedition spec.
- Talents, gear, abilities beyond the basic attack and heal, status effects, taunts.
- Collision between combatants on the same side (they may overlap).
- Anything drawn, and any change to `Simulation`.

## Paths

- `sim/defs/`, `sim/combat/`, `sim/sim_event.gd`
- `data/heroes/`, `data/monsters/`
- `tests/acceptance/test_004_combat_core.gd`
- `tests/unit/test_battle*.gd`, `tests/unit/test_combatant*.gd`, `tests/unit/test_content*.gd` (optional)
- `docs/wiki/index.html` (mark what is now built)

## Open questions

None.
