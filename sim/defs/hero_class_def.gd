class_name HeroClassDef
extends Resource
## A hero class: the numbers a level-1 hero of this class fights with, and how
## they grow per level. One .tres file per class under res://data/heroes.

enum Role { TANK, MELEE, RANGED, HEALER }

@export var id: StringName
@export var display_name: String
@export var role: Role
@export var max_health: int
@export var damage: int
@export var armor: int
@export var attack_interval: float  # seconds between strikes
@export var windup: float  # seconds before a strike lands or launches
@export var attack_range: float  # tiles
@export var move_speed: float  # tiles per second
@export var crit_chance: float  # 0 to 1
@export var heal_power: int  # 0 for classes that do not heal
@export var health_per_level: int
@export var damage_per_level: int
## The microskills this class learns, and (same length) the hero level each is learned at.
@export var microskills: Array[StringName] = []
@export var microskill_levels: Array[int] = []


## One line per problem; empty when the class is usable.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = DefChecks.combat_problems(
		id, display_name, max_health, damage, attack_interval, attack_range, move_speed, crit_chance
	)
	if role == Role.HEALER and heal_power < 1:
		problems.append("heal_power %d is below 1 for a HEALER" % heal_power)
	if microskills.size() != microskill_levels.size():
		problems.append(
			(
				"microskills has %d entries but microskill_levels has %d"
				% [microskills.size(), microskill_levels.size()]
			)
		)
	for i: int in mini(microskills.size(), microskill_levels.size()):
		if Content.microskill(microskills[i]) == null:
			problems.append("microskill %s does not exist" % microskills[i])
		if microskill_levels[i] < 1:
			problems.append(
				"microskill %s level %d is below 1" % [microskills[i], microskill_levels[i]]
			)
	return problems
