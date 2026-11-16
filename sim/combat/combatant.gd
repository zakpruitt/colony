class_name Combatant
extends RefCounted
## One fighter in a battle, made from a hero class or a monster definition.
##
## Durations from the data are turned into ticks once, here, so the battle
## only ever counts ticks.

enum Team { HEROES, MONSTERS }
enum State { IDLE, MOVING, WINDUP, DEAD }

## How much a monster's health and damage grow per depth below its min_depth (compounding).
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
	var scale: float = pow(DEPTH_GROWTH, maxi(depth - def.min_depth, 0))
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


## Seconds of game time as a whole number of ticks, at least 1.
static func seconds_to_ticks(seconds: float) -> int:
	return maxi(1, roundi(seconds * Simulation.TICKS_PER_SECOND))


## True until health reaches 0.
func is_alive() -> bool:
	return state != State.DEAD and health > 0


## Health as a fraction of the maximum, 0 to 1.
func health_fraction() -> float:
	if max_health <= 0:
		return 0.0
	return float(health) / max_health


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
