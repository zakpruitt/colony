class_name MonsterDef
extends Resource
## A monster: the numbers it fights with at [member min_depth], the shallowest
## depth it appears on, and what it is worth. One .tres file per monster under
## res://data/monsters.

enum Size { SMALL, LARGE, BOSS }

@export var id: StringName
@export var display_name: String
@export var size: Size
@export var min_depth: int
@export var max_health: int
@export var damage: int
@export var armor: int
@export var attack_interval: float  # seconds between strikes
@export var windup: float  # seconds before a strike lands or launches
@export var attack_range: float  # tiles
@export var move_speed: float  # tiles per second
@export var crit_chance: float  # 0 to 1
@export var xp: int
@export var gold_min: int
@export var gold_max: int
## A guardian holds the way down on the levels it guards (from [member min_depth]
## on) and never appears in an ordinary encounter.
@export var guardian: bool = false


## One line per problem; empty when the monster is usable.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = DefChecks.combat_problems(
		id, display_name, max_health, damage, attack_interval, attack_range, move_speed, crit_chance
	)
	if gold_min > gold_max:
		problems.append("gold_min %d is above gold_max %d" % [gold_min, gold_max])
	if min_depth < 1:
		problems.append("min_depth %d is below 1" % min_depth)
	return problems
