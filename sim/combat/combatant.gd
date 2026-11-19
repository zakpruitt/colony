class_name Combatant
extends RefCounted
## One fighter in a battle, made from a hero class or a monster definition.
##
## Durations from the data are turned into ticks once, here, so the battle
## only ever counts ticks.

enum Team { HEROES, MONSTERS }
enum State { IDLE, MOVING, WINDUP, DEAD }

## How much a monster's health and damage grow per level above its base_level (compounding).
const DEPTH_GROWTH: float = 1.12

var id: int
var team: Team
## The id of the HeroClassDef or MonsterDef this was made from.
var def_id: StringName
var role: HeroClassDef.Role  # MELEE or RANGED for monsters, by range
var level: int  # hero level, or monster depth
var x: float
var health: int
var max_health: int
var state: State = State.IDLE
## Id of the current target, or -1.
var target_id: int = -1

## Damage before the roll, crit and the target's armour.
var damage: int
var armor: int
var crit_chance: float
## Healing before the roll; 0 for those who do not heal.
var heal_power: int
## Tiles.
var attack_range: float
## Tiles per second.
var move_speed: float
var windup_ticks: int
var attack_interval_ticks: int

## Set by the battle: the tick the current wind-up strikes on.
var strike_tick: int = -1
## Set by the battle: the first tick a new attack may start on.
var ready_tick: int = 0

## Spec 050: what this fighter does beyond its strike, in the order it considers them.
var abilities: Array[AbilityDef] = []  # empty for everyone today
## Set by the battle: the action being wound up, or null for an ordinary strike.
var pending_action: AbilityDef = null
## Set by the battle: the id of the action this fighter is walking or waiting to use, whose
## target it keeps until then; empty if none.
var chasing: StringName = &""
## Set by the battle: the statuses on this fighter, by [enum AbilityEffect.Status].
var statuses: Dictionary[int, CombatStatus] = {}
## Set by the battle: the tick each action is next ready on, by ability id.
var action_ready_tick: Dictionary[StringName, int] = {}
## Set by the battle: the once-a-fight passives that have fired.
var spent: Dictionary[StringName, bool] = {}
## Set by the battle: ordinary strikes made this fight.
var strikes: int = 0


## A hero of class [param def] at [param hero_level] (1 or more).
static func from_hero(def: HeroClassDef, hero_level: int, combatant_id: int) -> Combatant:
	var c := Combatant.new()
	var growth: int = maxi(hero_level, 1) - 1
	c.id = combatant_id
	c.team = Team.HEROES
	c.def_id = def.id
	c.role = def.role
	c.level = hero_level
	c.max_health = def.max_health + def.health_per_level * growth
	c.damage = def.damage + def.damage_per_level * growth
	c.heal_power = def.heal_power
	c._set_common(
		def.armor,
		def.crit_chance,
		def.attack_range,
		def.move_speed,
		def.windup,
		def.attack_interval
	)
	return c


## A monster [param def] met at [param depth].
static func from_monster(def: MonsterDef, depth: int, combatant_id: int) -> Combatant:
	var c := Combatant.new()
	var scale: float = pow(DEPTH_GROWTH, maxi(depth - def.base_level, 0))
	c.id = combatant_id
	c.team = Team.MONSTERS
	c.def_id = def.id
	c.role = HeroClassDef.Role.MELEE
	if def.attack_range > Battle.MELEE_REACH:
		c.role = HeroClassDef.Role.RANGED
	c.level = depth
	c.max_health = roundi(def.max_health * scale)
	c.damage = roundi(def.damage * scale)
	c.heal_power = 0
	c._set_common(
		def.armor,
		def.crit_chance,
		def.attack_range,
		def.move_speed,
		def.windup,
		def.attack_interval
	)
	return c


## Seconds of game time as the nearest whole number of ticks, at least [param least].
static func seconds_to_ticks(seconds: float, least: int = 1) -> int:
	return maxi(least, roundi(seconds * Simulation.TICKS_PER_SECOND))


## True until health reaches 0.
func is_alive() -> bool:
	return state != State.DEAD and health > 0


## Health as a fraction of the maximum, 0 to 1.
func health_fraction() -> float:
	if max_health <= 0:
		return 0.0
	return float(health) / max_health


## True if this fighter has the status [param kind] (an [enum AbilityEffect.Status]).
func has_status(kind: AbilityEffect.Status) -> bool:
	return statuses.has(kind)


## The status [param kind] on this fighter, or null.
func status(kind: AbilityEffect.Status) -> CombatStatus:
	return statuses.get(kind, null)


## Ticks from one strike to the next, after haste and slow.
func strike_interval_ticks() -> int:
	if statuses.is_empty():
		return attack_interval_ticks
	var times: float = _status_amount(AbilityEffect.Status.HASTED, 1.0)
	times *= _status_amount(AbilityEffect.Status.SLOWED, 1.0)
	return maxi(1, roundi(attack_interval_ticks * times))


## What the damage this fighter deals is multiplied by (mighty, weakened).
func dealt_multiplier() -> float:
	if statuses.is_empty():
		return 1.0
	var times: float = _status_amount(AbilityEffect.Status.MIGHTY, 1.0)
	return times * _status_amount(AbilityEffect.Status.WEAKENED, 1.0)


## What the damage this fighter takes is multiplied by (marked).
func taken_multiplier() -> float:
	return _status_amount(AbilityEffect.Status.MARKED, 1.0)


## Clears what one fight leaves on the fighter: statuses, the action in hand, cooldowns
## (each action ready at the start, or one cooldown in), once-a-fight passives and the strike count.
func reset_abilities() -> void:
	pending_action = null
	chasing = &""
	statuses.clear()
	spent.clear()
	strikes = 0
	action_ready_tick.clear()
	for ability: AbilityDef in abilities:
		if ability.is_action():
			var wait: int = seconds_to_ticks(ability.cooldown, 0)
			action_ready_tick[ability.id] = 0 if ability.ready_at_start else wait


func _status_amount(kind: AbilityEffect.Status, otherwise: float) -> float:
	var found: CombatStatus = statuses.get(kind, null)
	return otherwise if found == null else found.amount


func _set_common(
	armor_in: int,
	crit_in: float,
	range_in: float,
	speed_in: float,
	windup_seconds: float,
	interval_seconds: float
) -> void:
	health = max_health
	armor = armor_in
	crit_chance = crit_in
	attack_range = range_in
	move_speed = speed_in
	windup_ticks = seconds_to_ticks(windup_seconds)
	attack_interval_ticks = seconds_to_ticks(interval_seconds)
