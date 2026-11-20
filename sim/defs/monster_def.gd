class_name MonsterDef
extends ContentDef
## A monster: the numbers it fights with at [member base_level] and what it is worth. Where it
## lives is the areas' to say ([AreaDef]). One .tres file per monster under
## res://data/monsters.

enum Size { SMALL, LARGE, BOSS }

@export var id: StringName
@export var display_name: String
@export var size: Size
## The level its numbers are for: met at a higher level it is stronger by
## [constant Combatant.DEPTH_GROWTH] a level, and never weaker below it.
@export var base_level: int
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
## A guardian holds an area's way on at its guardian stages and never appears in an ordinary
## encounter.
@export var guardian: bool = false


## What Content finds this definition by: its id.
func key() -> StringName:
	return id


## One line per problem; empty when the monster is usable.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = DefChecks.combat_problems(
		id, display_name, max_health, damage, attack_interval, attack_range, move_speed, crit_chance
	)
	if gold_min > gold_max:
		problems.append("gold_min %d is above gold_max %d" % [gold_min, gold_max])
	if base_level < 1:
		problems.append("base_level %d is below 1" % base_level)
	return problems
